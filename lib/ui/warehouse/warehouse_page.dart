import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/layout/app_breakpoints.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';
export 'warehouse_read_page.dart' show WarehousePage;

class WarehouseItem {
  const WarehouseItem({
    required this.code,
    required this.description,
    required this.quantity,
    required this.stock,
  });

  final String code;
  final String description;
  final String quantity;
  final String stock;
}

class WarehouseRequest {
  const WarehouseRequest({
    required this.number,
    required this.operation,
    required this.product,
    required this.requestedBy,
    required this.priority,
    required this.createdAt,
    required this.status,
    required this.items,
  });

  final String number;
  final String operation;
  final String product;
  final String requestedBy;
  final String priority;
  final String createdAt;
  final String status;
  final List<WarehouseItem> items;
}

class WarehousePickingPage extends StatefulWidget {
  const WarehousePickingPage({super.key});

  @override
  State<WarehousePickingPage> createState() => _WarehousePageState();
}

class _WarehousePageState extends State<WarehousePickingPage> {
  var _selectedIndex = 0;
  static const _showCreate = false;

  WarehouseRequest _requestFromOrder(ProductionOrderFlow order) {
    final catalog = context.read<ProductionFlowStore>().catalogItem(
      order.productCode,
    );
    return WarehouseRequest(
      number: 'REQ-${order.number.substring(order.number.length - 5)}',
      operation: order.number,
      product: order.productLabel,
      requestedBy: order.operatorName ?? 'Almoxarifado',
      priority: order.priority,
      createdAt: _timeLabel(order.createdAt),
      status: _statusLabel(order),
      items: [
        for (final component in catalog.components)
          WarehouseItem(
            code: component.code,
            description: component.description,
            quantity: '${component.quantity * order.quantity} un',
            stock: component.stockLabel,
          ),
      ],
    );
  }

  Future<void> _startPicking() async {
    final order = _selectedOrder();
    if (order == null) return;
    final operator = _warehouseOperator();
    await context.read<ProductionFlowStore>().startStage(
      order.number,
      operatorName: operator.name,
      operatorPin: operator.pin,
    );
  }

  Future<void> _pausePicking() async {
    final order = _selectedOrder();
    if (order == null) return;
    final operator = _warehouseOperator();
    await context.read<ProductionFlowStore>().pauseStage(
      order.number,
      operatorName: operator.name,
      operatorPin: operator.pin,
    );
  }

  Future<void> _deliverItems() async {
    final order = _selectedOrder();
    if (order == null) return;
    final confirmation = await showWarehouseDeliveryDialog(
      context,
      request: _requestFromOrder(order),
    );
    if (!mounted || confirmation == null) return;
    final operator = context.read<OperatorAssignmentStore>().findByPin(
      confirmation.operatorPin,
    );
    if (operator == null || operator.stage != WorkStage.warehouse) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN do almoxarifado inválido.')),
      );
      return;
    }
    await context.read<ProductionFlowStore>().completeStage(
      order.number,
      observation: confirmation.observation,
      operatorName: operator.name,
      operatorPin: operator.pin,
    );
    if (!mounted) return;
    setState(() {
      _selectedIndex = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${order.number} liberada para SMD.')),
    );
  }

  Future<void> _createOrder({
    required String productCode,
    required int quantity,
    required String priority,
  }) async {
    final store = context.read<ProductionFlowStore>();
    final order = await store.createOrder(
      productCode: productCode,
      quantity: quantity,
      priority: priority,
      operatorName: _warehouseOperator().name,
    );
    if (!mounted) return;
    setState(() {
      _selectedIndex = 0;
    });

    final envio = store.protheusOutcome(order.number);
    if (envio != null && !envio.gravouNoProtheus) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 12),
            content: Text(
              '${order.number} criada no Almoxarifado, mas ${envio.aviso}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${order.number} criada no Almoxarifado.')),
    );
  }

  ProductionOrderFlow? _selectedOrder() {
    final orders = context.read<ProductionFlowStore>().ordersAtStage(
      ProductionStage.warehouse,
    );
    if (orders.isEmpty) return null;
    final index = _selectedIndex.clamp(0, orders.length - 1).toInt();
    return orders[index];
  }

  Operator _warehouseOperator() {
    final current = context.read<OperatorAssignmentStore>().currentOperator;
    if (current != null && current.stage == WorkStage.warehouse) {
      return current;
    }
    return Operator.findByPin('4003')!;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProductionFlowStore>();
    final stageOrders = store.ordersAtStage(ProductionStage.warehouse);
    final requests = stageOrders.map(_requestFromOrder).toList();
    if (_selectedIndex >= requests.length && requests.isNotEmpty) {
      _selectedIndex = requests.length - 1;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = constraints.maxWidth >= 1180
            ? AppFormFactor.expanded
            : AppBreakpoints.fromWidth(constraints.maxWidth);
        final isMobile = formFactor != AppFormFactor.expanded;

        if (isMobile) {
          return _MobileWarehouseLayout(
            requests: requests,
            showCreate: _showCreate,
            selectedIndex: _selectedIndex,
            status: requests.isEmpty
                ? 'Sem OPs'
                : requests[_selectedIndex].status,
            onShowQueue: () {},
            onShowCreate: () {},
            onCreate: _createOrder,
            onSelect: (index) => setState(() => _selectedIndex = index),
            onStart: _startPicking,
            onPause: _pausePicking,
            onDeliver: _deliverItems,
          );
        }

        return _DesktopWarehouseLayout(
          requests: requests,
          showCreate: _showCreate,
          selectedIndex: _selectedIndex,
          status: requests.isEmpty
              ? 'Sem OPs'
              : requests[_selectedIndex].status,
          onShowQueue: () {},
          onShowCreate: () {},
          onCreate: _createOrder,
          onSelect: (index) => setState(() => _selectedIndex = index),
          onStart: _startPicking,
          onPause: _pausePicking,
          onDeliver: _deliverItems,
        );
      },
    );
  }
}

String _statusLabel(ProductionOrderFlow order) {
  final base = switch (order.status) {
    ProductionRunStatus.waiting => 'Aguardando separacao',
    ProductionRunStatus.active => 'Em separacao',
    ProductionRunStatus.paused => 'Pausada',
    ProductionRunStatus.completed => 'Entregue',
  };
  final timing = order.timings[ProductionStage.warehouse];
  if (timing?.startedAt == null) return base;
  final elapsed = formatProductionDuration(order.activeElapsed(DateTime.now()));
  return '$base · $elapsed';
}

String _timeLabel(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _DesktopWarehouseLayout extends StatelessWidget {
  const _DesktopWarehouseLayout({
    required this.requests,
    required this.showCreate,
    required this.selectedIndex,
    required this.status,
    required this.onShowQueue,
    required this.onShowCreate,
    required this.onCreate,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onDeliver,
  });

  final List<WarehouseRequest> requests;
  final bool showCreate;
  final int selectedIndex;
  final String status;
  final VoidCallback onShowQueue;
  final VoidCallback onShowCreate;
  final void Function({
    required String productCode,
    required int quantity,
    required String priority,
  })
  onCreate;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onDeliver;

  WarehouseRequest? get selectedRequest =>
      requests.isEmpty ? null : requests[selectedIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          const VettiTopBar(
            title: 'Almoxarifado',
            operatorName: 'Vera',
            operatorRole: 'Almoxarifado',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 46, 40, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.maxContentWidth,
                    minWidth: 1040,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 390,
                        child: _WarehouseQueue(
                          requests: requests,
                          showCreate: showCreate,
                          selectedIndex: selectedIndex,
                          onShowQueue: onShowQueue,
                          onShowCreate: onShowCreate,
                          onSelect: onSelect,
                        ),
                      ),
                      const SizedBox(width: 72),
                      Expanded(
                        child: showCreate
                            ? _WarehouseCreateForm(onCreate: onCreate)
                            : selectedRequest == null
                            ? const _EmptyWarehouseState()
                            : _WarehouseDetails(
                                request: selectedRequest!,
                                status: status,
                                onStart: onStart,
                                onPause: onPause,
                                onDeliver: onDeliver,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileWarehouseLayout extends StatelessWidget {
  const _MobileWarehouseLayout({
    required this.requests,
    required this.showCreate,
    required this.selectedIndex,
    required this.status,
    required this.onShowQueue,
    required this.onShowCreate,
    required this.onCreate,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onDeliver,
  });

  final List<WarehouseRequest> requests;
  final bool showCreate;
  final int selectedIndex;
  final String status;
  final VoidCallback onShowQueue;
  final VoidCallback onShowCreate;
  final void Function({
    required String productCode,
    required int quantity,
    required String priority,
  })
  onCreate;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onDeliver;

  WarehouseRequest? get selectedRequest =>
      requests.isEmpty ? null : requests[selectedIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      body: SafeArea(
        child: Center(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 430),
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.pageBackground,
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const VettiTopBar(
                  title: 'Almoxarifado',
                  operatorName: 'Vera',
                  compact: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: _WarehouseHeader(compact: true),
                        ),
                        const SizedBox(height: 14),
                        _WarehouseTabs(
                          showCreate: showCreate,
                          onShowQueue: onShowQueue,
                          onShowCreate: onShowCreate,
                          compact: true,
                        ),
                        const SizedBox(height: 18),
                        if (showCreate)
                          _WarehouseCreateForm(
                            onCreate: onCreate,
                            compact: true,
                          )
                        else if (selectedRequest == null)
                          const _EmptyWarehouseState(compact: true)
                        else ...[
                          for (var i = 0; i < requests.length; i++) ...[
                            _WarehouseRequestCard(
                              request: requests[i],
                              selected: i == selectedIndex,
                              compact: true,
                              onTap: () => onSelect(i),
                            ),
                            if (i < requests.length - 1)
                              const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 24),
                          _MobileWarehouseSummary(
                            request: selectedRequest!,
                            status: status,
                          ),
                          const SizedBox(height: 16),
                          _WarehouseItemsPanel(request: selectedRequest!),
                          const SizedBox(height: 18),
                          _WarehouseActions(
                            compact: true,
                            onStart: onStart,
                            onPause: onPause,
                            onDeliver: onDeliver,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WarehouseQueue extends StatelessWidget {
  const _WarehouseQueue({
    required this.requests,
    required this.showCreate,
    required this.selectedIndex,
    required this.onShowQueue,
    required this.onShowCreate,
    required this.onSelect,
  });

  final List<WarehouseRequest> requests;
  final bool showCreate;
  final int selectedIndex;
  final VoidCallback onShowQueue;
  final VoidCallback onShowCreate;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WarehouseHeader(),
        const SizedBox(height: 18),
        _WarehouseTabs(
          showCreate: showCreate,
          onShowQueue: onShowQueue,
          onShowCreate: onShowCreate,
        ),
        const SizedBox(height: 38),
        if (requests.isEmpty)
          const _EmptyWarehouseState(compact: true)
        else
          for (var i = 0; i < requests.length; i++) ...[
            _WarehouseRequestCard(
              request: requests[i],
              selected: !showCreate && i == selectedIndex,
              onTap: () => onSelect(i),
            ),
            if (i < requests.length - 1) const SizedBox(height: 23),
          ],
      ],
    );
  }
}

class _WarehouseTabs extends StatelessWidget {
  const _WarehouseTabs({
    required this.showCreate,
    required this.onShowQueue,
    required this.onShowCreate,
    this.compact = false,
  });

  final bool showCreate;
  final VoidCallback onShowQueue;
  final VoidCallback onShowCreate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _WarehouseTabButton(
              label: 'Separacao',
              active: !showCreate,
              onTap: onShowQueue,
              compact: compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarehouseTabButton extends StatelessWidget {
  const _WarehouseTabButton({
    required this.label,
    required this.active,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 9 : 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? AppColors.primary : AppColors.textMuted,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _WarehouseHeader extends StatelessWidget {
  const _WarehouseHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Requisicoes do suporte',
          style: TextStyle(
            color: AppColors.text,
            fontSize: compact ? 24 : 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        Text(
          compact
              ? 'Pedidos para separar.'
              : 'Pedidos de componentes para conserto das OPs no suporte tecnico.',
          style: TextStyle(color: AppColors.muted, fontSize: compact ? 13 : 16),
        ),
      ],
    );
  }
}

class _WarehouseDetails extends StatelessWidget {
  const _WarehouseDetails({
    required this.request,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onDeliver,
  });

  final WarehouseRequest request;
  final String status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onDeliver;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.number,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${request.operation} · ${request.product}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 38),
          _WarehouseMetrics(request: request, status: status),
          const SizedBox(height: 32),
          _WarehouseItemsPanel(request: request),
          const SizedBox(height: 54),
          const Text(
            'Acoes da requisicao',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'O almoxarifado separa, pausa ou entrega os itens solicitados ao suporte.',
            style: TextStyle(color: AppColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 36),
          _WarehouseActions(
            onStart: onStart,
            onPause: onPause,
            onDeliver: onDeliver,
          ),
        ],
      ),
    );
  }
}

class _WarehouseRequestCard extends StatelessWidget {
  const _WarehouseRequestCard({
    required this.request,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final WarehouseRequest request;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 10 : 8);

    return Material(
      color: selected ? const Color(0xFFEAF7FF) : Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: compact ? 118 : 126),
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 20,
            compact ? 14 : 16,
            compact ? 16 : 20,
            compact ? 13 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.number,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: compact ? 17 : 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _PriorityBadge(priority: request.priority),
                ],
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                request.operation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: compact ? 13 : 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: compact ? 10 : 12),
              Text(
                '${request.items.length} item(s) · ${request.createdAt}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.smallText,
                  fontSize: compact ? 11 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = priority == 'Alta'
        ? AppColors.orangeText
        : priority == 'Media'
        ? AppColors.primary
        : AppColors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WarehouseMetrics extends StatelessWidget {
  const _WarehouseMetrics({required this.request, required this.status});

  final WarehouseRequest request;
  final String status;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Prioridade', request.priority),
      ('Solicitante', request.requestedBy),
      ('Horario', request.createdAt),
      ('Status atual', status),
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 18,
      children: [
        for (final metric in metrics)
          _MetricCard(
            label: metric.$1,
            value: metric.$2,
            wide: metric.$1 == 'Solicitante' || metric.$1 == 'Status atual',
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.wide,
  });

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 220 : 155,
      constraints: const BoxConstraints(minHeight: 98),
      padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE4EDF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.label,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarehouseItemsPanel extends StatelessWidget {
  const _WarehouseItemsPanel({required this.request});

  final WarehouseRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Itens solicitados',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < request.items.length; i++) ...[
            _WarehouseItemRow(item: request.items[i]),
            if (i < request.items.length - 1)
              const Divider(height: 24, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _WarehouseItemRow extends StatelessWidget {
  const _WarehouseItemRow({required this.item});

  final WarehouseItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 78,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7FF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            item.code,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.description,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Solicitado: ${item.quantity} · Estoque: ${item.stock}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WarehouseActions extends StatelessWidget {
  const _WarehouseActions({
    required this.onStart,
    required this.onPause,
    required this.onDeliver,
    this.compact = false,
  });

  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onDeliver;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acoes',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          _ActionButton(
            label: 'Iniciar separacao',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
            fillColor: AppColors.primary,
            foregroundColor: Colors.white,
            width: double.infinity,
            height: 54,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Pausar',
                  icon: Icons.pause_rounded,
                  onPressed: onPause,
                  foregroundColor: AppColors.orangeText,
                  borderColor: AppColors.orange,
                  height: 54,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ActionButton(
                  label: 'Entregar',
                  icon: Icons.inventory_2_rounded,
                  onPressed: onDeliver,
                  foregroundColor: AppColors.green,
                  borderColor: AppColors.green,
                  height: 54,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _ActionButton(
          label: 'Iniciar separacao',
          icon: Icons.play_arrow_rounded,
          onPressed: onStart,
          fillColor: AppColors.primary,
          foregroundColor: Colors.white,
          width: 270,
        ),
        _ActionButton(
          label: 'Pausar separacao',
          icon: Icons.pause_rounded,
          onPressed: onPause,
          foregroundColor: AppColors.orangeText,
          borderColor: AppColors.orange,
          width: 270,
        ),
        _ActionButton(
          label: 'Entregar ao suporte',
          icon: Icons.inventory_2_rounded,
          onPressed: onDeliver,
          foregroundColor: AppColors.green,
          borderColor: AppColors.green,
          width: 300,
        ),
      ],
    );
  }
}

class _WarehouseCreateForm extends StatefulWidget {
  const _WarehouseCreateForm({required this.onCreate, this.compact = false});

  final void Function({
    required String productCode,
    required int quantity,
    required String priority,
  })
  onCreate;
  final bool compact;

  @override
  State<_WarehouseCreateForm> createState() => _WarehouseCreateFormState();
}

class _WarehouseCreateFormState extends State<_WarehouseCreateForm> {
  late String _productCode;
  var _priority = 'Media';
  late final TextEditingController _quantityController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _productCode = '';
    _quantityController = TextEditingController(text: '1');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final catalog = context.watch<ProductionFlowStore>().catalogItems;
    if (_productCode.isEmpty && catalog.isNotEmpty) {
      _productCode = catalog.first.code;
      _quantityController.text = '${catalog.first.defaultQuantity}';
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<ProductionFlowStore>().catalogItems;
    if (catalog.isEmpty) {
      return _WarehouseCreateUnavailable(compact: widget.compact);
    }
    final selected = catalog.firstWhere(
      (item) => item.code == _productCode,
      orElse: () => catalog.first,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Criar OP',
            style: TextStyle(
              color: AppColors.text,
              fontSize: widget.compact ? 22 : 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crie uma OP local para testar o fluxo completo antes da integracao com o Protheus.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: widget.compact ? 13 : 16,
            ),
          ),
          SizedBox(height: widget.compact ? 18 : 28),
          DropdownButtonFormField<String>(
            initialValue: _productCode,
            decoration: const InputDecoration(labelText: 'Produto'),
            items: [
              for (final item in catalog)
                DropdownMenuItem(value: item.code, child: Text(item.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              final item = catalog.firstWhere(
                (product) => product.code == value,
              );
              setState(() {
                _productCode = value;
                _quantityController.text = '${item.defaultQuantity}';
              });
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantidade',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Prioridade'),
            items: const [
              DropdownMenuItem(value: 'Baixa', child: Text('Baixa')),
              DropdownMenuItem(value: 'Media', child: Text('Media')),
              DropdownMenuItem(value: 'Alta', child: Text('Alta')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _priority = value);
            },
          ),
          const SizedBox(height: 22),
          _WarehouseItemsPreview(item: selected),
          SizedBox(height: widget.compact ? 22 : 32),
          _ActionButton(
            label: 'Criar OP no almoxarifado',
            icon: Icons.add_rounded,
            onPressed: _submit,
            fillColor: AppColors.primary,
            foregroundColor: Colors.white,
            width: widget.compact ? double.infinity : 320,
            height: widget.compact ? 54 : 64,
          ),
        ],
      ),
    );
  }

  void _submit() {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Informe uma quantidade valida.');
      return;
    }
    widget.onCreate(
      productCode: _productCode,
      quantity: quantity,
      priority: _priority,
    );
  }
}

class _WarehouseCreateUnavailable extends StatelessWidget {
  const _WarehouseCreateUnavailable({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Crie a OP pelo dashboard usando um código real do Protheus.',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: compact ? 13 : 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WarehouseItemsPreview extends StatelessWidget {
  const _WarehouseItemsPreview({required this.item});

  final ProductionCatalogItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4EDF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Componentes previstos',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < item.components.length; i++) ...[
            _WarehouseItemRow(
              item: WarehouseItem(
                code: item.components[i].code,
                description: item.components[i].description,
                quantity: item.components[i].quantityLabel,
                stock: item.components[i].stockLabel,
              ),
            ),
            if (i < item.components.length - 1)
              const Divider(height: 22, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _EmptyWarehouseState extends StatelessWidget {
  const _EmptyWarehouseState({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: AppColors.iconMuted,
            size: compact ? 34 : 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhuma OP no almoxarifado.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 14 : 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use a aba Criar OP para iniciar um fluxo local.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.foregroundColor,
    this.fillColor,
    this.borderColor,
    this.width,
    this.height = 74,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color? fillColor;
  final Color? borderColor;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          backgroundColor: fillColor ?? Colors.white,
          foregroundColor: foregroundColor,
          side: BorderSide(
            color: borderColor ?? fillColor ?? Colors.white,
            width: 2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _MobileWarehouseSummary extends StatelessWidget {
  const _MobileWarehouseSummary({required this.request, required this.status});

  final WarehouseRequest request;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(label: 'OP', value: request.operation),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: _SummaryValue(label: 'Status', value: status),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.label,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class WarehouseDeliveryConfirmation {
  const WarehouseDeliveryConfirmation({
    required this.operatorPin,
    this.observation,
  });

  final String operatorPin;
  final String? observation;
}

Future<WarehouseDeliveryConfirmation?> showWarehouseDeliveryDialog(
  BuildContext context, {
  required WarehouseRequest request,
}) {
  return showDialog<WarehouseDeliveryConfirmation>(
    context: context,
    builder: (context) => _WarehouseDeliveryDialog(request: request),
  );
}

class _WarehouseDeliveryDialog extends StatefulWidget {
  const _WarehouseDeliveryDialog({required this.request});

  final WarehouseRequest request;

  @override
  State<_WarehouseDeliveryDialog> createState() =>
      _WarehouseDeliveryDialogState();
}

class _WarehouseDeliveryDialogState extends State<_WarehouseDeliveryDialog> {
  final _observationController = TextEditingController();
  final _pinController = TextEditingController();
  String? _pinError;

  @override
  void dispose() {
    _observationController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Entregar ao suporte'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.request.number} · ${widget.request.operation}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('warehouse-delivery-observation'),
              controller: _observationController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Observacao opcional',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('warehouse-delivery-pin'),
              controller: _pinController,
              decoration: InputDecoration(
                labelText: 'PIN',
                hintText: '4003',
                errorText: _pinError,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final pin = _pinController.text.trim();
            if (pin.isEmpty) {
              setState(() => _pinError = 'Informe o PIN.');
              return;
            }
            final observation = _observationController.text.trim();
            Navigator.of(context).pop(
              WarehouseDeliveryConfirmation(
                operatorPin: pin,
                observation: observation.isEmpty ? null : observation,
              ),
            );
          },
          child: const Text('Confirmar entrega'),
        ),
      ],
    );
  }
}
