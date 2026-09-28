import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/layout/app_breakpoints.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/pause_reason_dialog.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

class ExpeditionOrder {
  const ExpeditionOrder({
    required this.number,
    required this.product,
    required this.quantity,
    required this.origin,
    required this.readyAt,
    required this.readyAgo,
    required this.orderCode,
    required this.customer,
    required this.channel,
    required this.carrier,
    required this.packaging,
  });

  final String number;
  final String product;
  final String quantity;
  final String origin;
  final String readyAt;
  final String readyAgo;
  final String orderCode;
  final String customer;
  final String channel;
  final String carrier;
  final List<String> packaging;

  int get quantityValue {
    final digits = quantity.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }
}

class ExpeditionStoredOrder {
  const ExpeditionStoredOrder({
    required this.number,
    required this.product,
    required this.quantity,
    required this.originalQuantity,
    required this.orderCode,
    required this.storedAt,
  });

  final String number;
  final String product;
  final int quantity;
  final int originalQuantity;
  final String orderCode;
  final String storedAt;

  String get quantityLabel => '$quantity un';

  String get typeLabel =>
      quantity >= originalQuantity ? 'Armazenada total' : 'Armazenada parcial';

  ExpeditionStoredOrder copyWith({int? quantity}) {
    return ExpeditionStoredOrder(
      number: number,
      product: product,
      quantity: quantity ?? this.quantity,
      originalQuantity: originalQuantity,
      orderCode: orderCode,
      storedAt: storedAt,
    );
  }
}

class ExpeditionDispatchedOrder {
  const ExpeditionDispatchedOrder({
    required this.number,
    required this.product,
    required this.quantity,
    required this.orderCode,
    required this.dispatchedAt,
    required this.origin,
  });

  final String number;
  final String product;
  final int quantity;
  final String orderCode;
  final String dispatchedAt;
  final String origin;

  String get quantityLabel => '$quantity un';
}

class ExpeditionDispatchSummary {
  const ExpeditionDispatchSummary({
    required this.dispatchedQuantity,
    required this.storedQuantity,
  });

  final int dispatchedQuantity;
  final int storedQuantity;

  String get dispatchedLabel => '$dispatchedQuantity un';
  String get storedLabel => '$storedQuantity un';
}

enum ExpeditionStatus {
  waiting(
    'Aguardando',
    AppColors.muted,
    Color(0xFFEFF3F7),
    Icons.schedule_rounded,
  ),
  active(
    'Em conferencia',
    AppColors.primary,
    Color(0xFFE7F4FB),
    Icons.inventory_2_rounded,
  ),
  paused(
    'Pausada',
    AppColors.orangeText,
    Color(0xFFFBF1E2),
    Icons.pause_rounded,
  ),
  completed(
    'Despachada',
    AppColors.green,
    Color(0xFFE7F6EC),
    Icons.check_circle_rounded,
  );

  const ExpeditionStatus(this.label, this.color, this.surface, this.icon);

  final String label;
  final Color color;
  final Color surface;
  final IconData icon;
}

class ExpeditionPage extends StatefulWidget {
  const ExpeditionPage({super.key});

  @override
  State<ExpeditionPage> createState() => _ExpeditionPageState();
}

class _ExpeditionPageState extends State<ExpeditionPage> {
  var _selectedIndex = 0;
  var _showStored = false;
  final _dispatchSummaries = <String, ExpeditionDispatchSummary>{};
  final _dispatchedOrders = <ExpeditionDispatchedOrder>[];

  List<ProductionOrderFlow> _readyFlowOrders() => context
      .read<ProductionFlowStore>()
      .ordersAtStage(ProductionStage.expedition);

  ProductionOrderFlow? _selectedFlowOrder() {
    final orders = _readyFlowOrders();
    if (orders.isEmpty) return null;
    final index = _selectedIndex.clamp(0, orders.length - 1).toInt();
    return orders[index];
  }

  ExpeditionOrder _orderFromFlow(ProductionOrderFlow order) {
    final elapsed = order.activeElapsed(DateTime.now());
    return ExpeditionOrder(
      number: order.number,
      product: order.productLabel,
      quantity: order.quantityLabel,
      origin: order.previousStageLabel,
      readyAt: _clockLabel(order.updatedAt),
      readyAgo: order.timings[ProductionStage.expedition]?.startedAt == null
          ? 'Aguardando conferencia'
          : 'Tempo na etapa: ${formatProductionDuration(elapsed)}',
      orderCode: 'Sem pedido vinculado',
      customer: 'Não vinculado',
      channel: 'Fluxo local',
      carrier: 'Não vinculada',
      packaging: [
        'Conferir etiqueta da OP e quantidade final.',
        'Separar volumes de ${order.productCode}.',
        'Registrar quantidade expedida ou armazenada.',
      ],
    );
  }

  ExpeditionStoredOrder _storedFromFlow(ProductionOrderFlow order) {
    return ExpeditionStoredOrder(
      number: order.number,
      product: order.productLabel,
      quantity: order.storedQuantity,
      originalQuantity: order.quantity,
      orderCode: 'Sem pedido vinculado',
      storedAt: _clockLabel(order.updatedAt),
    );
  }

  ExpeditionStatus _statusFromFlow(ProductionOrderFlow order) {
    return switch (order.status) {
      ProductionRunStatus.waiting => ExpeditionStatus.waiting,
      ProductionRunStatus.active => ExpeditionStatus.active,
      ProductionRunStatus.paused => ExpeditionStatus.paused,
      ProductionRunStatus.completed => ExpeditionStatus.completed,
    };
  }

  void _select(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _startExpedition() async {
    final order = _selectedFlowOrder();
    if (order == null) return;
    final operator = context.read<OperatorAssignmentStore>().currentOperator;
    await context.read<ProductionFlowStore>().startStage(
      order.number,
      operatorName: operator?.name ?? 'Expedicao',
      operatorPin: operator?.pin,
    );
  }

  Future<void> _pauseExpedition() async {
    final order = _selectedFlowOrder();
    if (order == null) return;
    final request = await showPauseReasonDialog(
      context,
      stage: ProductionStage.expedition,
      maxQuantity: order.quantity,
    );
    if (!mounted || request == null) return;
    await context.read<ProductionFlowStore>().pauseStage(
      order.number,
      operatorName: request.operatorName,
      operatorPin: request.operatorPin,
      reason: request.reason,
      customReason: request.customReason,
      producedQuantity: request.producedQuantity,
    );
  }

  Future<void> _finishExpedition() async {
    final flowOrder = _selectedFlowOrder();
    if (flowOrder == null) return;
    final order = _orderFromFlow(flowOrder);
    final storedQuantity = await showExpeditionPinDialog(context, order);
    if (!mounted || storedQuantity == null) return;

    final dispatchedQuantity = order.quantityValue - storedQuantity;
    try {
      await context.read<ProductionFlowStore>().completeExpedition(
        flowOrder.number,
        storedQuantity: storedQuantity,
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    setState(() {
      _dispatchSummaries[order.number] = ExpeditionDispatchSummary(
        dispatchedQuantity: dispatchedQuantity,
        storedQuantity: storedQuantity,
      );
      if (dispatchedQuantity > 0) {
        _recordDispatched(
          number: order.number,
          product: order.product,
          quantity: dispatchedQuantity,
          orderCode: order.orderCode,
          dispatchedAt: order.readyAt,
          origin: storedQuantity > 0 ? 'Parcial da OP' : 'Despacho direto',
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          storedQuantity > 0
              ? '${order.number} finalizada com $storedQuantity un armazenadas.'
              : '${order.number} despachada.',
        ),
      ),
    );
  }

  void _setTab(bool stored) {
    setState(() => _showStored = stored);
  }

  void _recordDispatched({
    required String number,
    required String product,
    required int quantity,
    required String orderCode,
    required String dispatchedAt,
    required String origin,
  }) {
    _dispatchedOrders.insert(
      0,
      ExpeditionDispatchedOrder(
        number: number,
        product: product,
        quantity: quantity,
        orderCode: orderCode,
        dispatchedAt: dispatchedAt,
        origin: origin,
      ),
    );
  }

  Future<void> _dispatchStoredOrder(ExpeditionStoredOrder storedOrder) async {
    final quantityToDispatch = await showStoredDispatchDialog(
      context,
      storedOrder,
    );
    if (!mounted || quantityToDispatch == null) return;

    await context.read<ProductionFlowStore>().dispatchStored(
      storedOrder.number,
      quantity: quantityToDispatch,
    );
    if (!mounted) return;
    setState(() {
      _recordDispatched(
        number: storedOrder.number,
        product: storedOrder.product,
        quantity: quantityToDispatch,
        orderCode: storedOrder.orderCode,
        dispatchedAt: 'Agora',
        origin: 'Armazenamento',
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$quantityToDispatch un de ${storedOrder.number} expedidas do armazenamento.',
        ),
      ),
    );
  }

  void _showMobileActions(BuildContext context) {
    final flowOrder = _selectedFlowOrder();
    if (flowOrder == null) return;
    final status = _statusFromFlow(flowOrder);
    final order = _orderFromFlow(flowOrder);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MobileExpeditionActionSheet(
        order: order,
        status: status,
        onStart: () {
          Navigator.pop(ctx);
          _startExpedition();
        },
        onPause: () {
          Navigator.pop(ctx);
          _pauseExpedition();
        },
        onFinish: () {
          Navigator.pop(ctx);
          _finishExpedition();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProductionFlowStore>();
    final flowOrders = store.ordersAtStage(ProductionStage.expedition);
    final storageOrders = store.ordersAtStage(ProductionStage.storage);
    if (_selectedIndex >= flowOrders.length) {
      _selectedIndex = flowOrders.isEmpty ? 0 : flowOrders.length - 1;
    }
    final orders = flowOrders.map(_orderFromFlow).toList();
    final storedOrders = storageOrders
        .where((order) => order.storedQuantity > 0)
        .map(_storedFromFlow)
        .toList();
    final statuses = {
      for (var i = 0; i < flowOrders.length; i++)
        i: _statusFromFlow(flowOrders[i]),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = AppBreakpoints.fromWidth(constraints.maxWidth);
        final isMobile = formFactor != AppFormFactor.expanded;

        if (isMobile) {
          return _MobileExpeditionLayout(
            orders: orders,
            storedOrders: storedOrders,
            dispatchedOrders: _dispatchedOrders,
            dispatchSummaries: _dispatchSummaries,
            showStored: _showStored,
            selectedIndex: _selectedIndex,
            statuses: statuses,
            onTabChanged: _setTab,
            onDispatchStored: _dispatchStoredOrder,
            onSelect: (index) {
              _select(index);
              _showMobileActions(context);
            },
          );
        }

        return _DesktopExpeditionLayout(
          orders: orders,
          storedOrders: storedOrders,
          dispatchedOrders: _dispatchedOrders,
          dispatchSummaries: _dispatchSummaries,
          showStored: _showStored,
          selectedIndex: _selectedIndex,
          statuses: statuses,
          onTabChanged: _setTab,
          onDispatchStored: _dispatchStoredOrder,
          onSelect: _select,
          onStart: _startExpedition,
          onPause: _pauseExpedition,
          onFinish: _finishExpedition,
        );
      },
    );
  }

  String _clockLabel(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _MobileExpeditionActionSheet extends StatelessWidget {
  const _MobileExpeditionActionSheet({
    required this.order,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onFinish,
  });

  final ExpeditionOrder order;
  final ExpeditionStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD7E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.number,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.product,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _ExpeditionStatusChip(status: status, compact: true),
              ],
            ),
            const SizedBox(height: 16),
            _ExpeditionMetrics(order: order, compact: true),
            const SizedBox(height: 16),
            _DestinationPanel(order: order, compact: true),
            const SizedBox(height: 16),
            _PackagingPanel(order: order, compact: true),
            const SizedBox(height: 20),
            _ExpeditionActions(
              status: status,
              compact: true,
              onStart: onStart,
              onPause: onPause,
              onFinish: onFinish,
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileExpeditionLayout extends StatelessWidget {
  const _MobileExpeditionLayout({
    required this.orders,
    required this.storedOrders,
    required this.dispatchedOrders,
    required this.dispatchSummaries,
    required this.showStored,
    required this.selectedIndex,
    required this.statuses,
    required this.onTabChanged,
    required this.onDispatchStored,
    required this.onSelect,
  });

  final List<ExpeditionOrder> orders;
  final List<ExpeditionStoredOrder> storedOrders;
  final List<ExpeditionDispatchedOrder> dispatchedOrders;
  final Map<String, ExpeditionDispatchSummary> dispatchSummaries;
  final bool showStored;
  final int selectedIndex;
  final Map<int, ExpeditionStatus> statuses;
  final ValueChanged<bool> onTabChanged;
  final ValueChanged<ExpeditionStoredOrder> onDispatchStored;
  final ValueChanged<int> onSelect;

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
                VettiTopBar(
                  title: 'Expedição · local',
                  operatorName:
                      context
                          .watch<OperatorAssignmentStore?>()
                          ?.currentOperator
                          ?.name ??
                      'Consulta',
                  compact: true,
                ),
                const _LocalExpeditionNotice(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ExpeditionTabs(
                          showStored: showStored,
                          onChanged: onTabChanged,
                          compact: true,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          showStored ? 'OPs armazenadas' : 'OPs prontas',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          showStored
                              ? 'Quantidades separadas para armazenamento.'
                              : 'Toque na OP para conferir destino e embalagem.',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (showStored)
                          _StoredOverview(
                            storedOrders: storedOrders,
                            dispatchedOrders: dispatchedOrders,
                            onDispatch: onDispatchStored,
                            compact: true,
                          )
                        else
                          for (var i = 0; i < orders.length; i++) ...[
                            _ExpeditionCard(
                              order: orders[i],
                              selected: i == selectedIndex,
                              status: statuses[i] ?? ExpeditionStatus.waiting,
                              dispatchSummary:
                                  dispatchSummaries[orders[i].number],
                              compact: true,
                              onTap: () => onSelect(i),
                            ),
                            if (i < orders.length - 1)
                              const SizedBox(height: 10),
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

class _DesktopExpeditionLayout extends StatelessWidget {
  const _DesktopExpeditionLayout({
    required this.orders,
    required this.storedOrders,
    required this.dispatchedOrders,
    required this.dispatchSummaries,
    required this.showStored,
    required this.selectedIndex,
    required this.statuses,
    required this.onTabChanged,
    required this.onDispatchStored,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onFinish,
  });

  final List<ExpeditionOrder> orders;
  final List<ExpeditionStoredOrder> storedOrders;
  final List<ExpeditionDispatchedOrder> dispatchedOrders;
  final Map<String, ExpeditionDispatchSummary> dispatchSummaries;
  final bool showStored;
  final int selectedIndex;
  final Map<int, ExpeditionStatus> statuses;
  final ValueChanged<bool> onTabChanged;
  final ValueChanged<ExpeditionStoredOrder> onDispatchStored;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  ExpeditionOrder? get selectedOrder =>
      orders.isEmpty ? null : orders[selectedIndex];
  ExpeditionStatus get status =>
      statuses[selectedIndex] ?? ExpeditionStatus.waiting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          VettiTopBar(
            title: 'Expedição · local',
            operatorName:
                context
                    .watch<OperatorAssignmentStore?>()
                    ?.currentOperator
                    ?.name ??
                'Consulta',
            operatorRole: 'Fluxo local',
          ),
          const _LocalExpeditionNotice(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 32, 40, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 340,
                        child: _DesktopExpeditionQueue(
                          orders: orders,
                          storedOrders: storedOrders,
                          dispatchSummaries: dispatchSummaries,
                          showStored: showStored,
                          selectedIndex: selectedIndex,
                          statuses: statuses,
                          onTabChanged: onTabChanged,
                          onDispatchStored: onDispatchStored,
                          onSelect: onSelect,
                        ),
                      ),
                      const SizedBox(width: 36),
                      Expanded(
                        child: showStored
                            ? _StoredOrdersPanel(
                                storedOrders: storedOrders,
                                dispatchedOrders: dispatchedOrders,
                                onDispatch: onDispatchStored,
                              )
                            : selectedOrder == null
                            ? const _EmptyExpeditionDetail()
                            : _DesktopExpeditionDetail(
                                order: selectedOrder!,
                                status: status,
                                dispatchSummary:
                                    dispatchSummaries[selectedOrder!.number],
                                onStart: onStart,
                                onPause: onPause,
                                onFinish: onFinish,
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

class _EmptyExpeditionDetail extends StatelessWidget {
  const _EmptyExpeditionDetail();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(28),
      child: const SizedBox(
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_shipping_rounded,
                size: 44,
                color: AppColors.primary,
              ),
              SizedBox(height: 14),
              Text(
                'Nenhuma OP pronta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'As OPs aparecem aqui quando o teste for concluido.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopExpeditionQueue extends StatelessWidget {
  const _DesktopExpeditionQueue({
    required this.orders,
    required this.storedOrders,
    required this.dispatchSummaries,
    required this.showStored,
    required this.selectedIndex,
    required this.statuses,
    required this.onTabChanged,
    required this.onDispatchStored,
    required this.onSelect,
  });

  final List<ExpeditionOrder> orders;
  final List<ExpeditionStoredOrder> storedOrders;
  final Map<String, ExpeditionDispatchSummary> dispatchSummaries;
  final bool showStored;
  final int selectedIndex;
  final Map<int, ExpeditionStatus> statuses;
  final ValueChanged<bool> onTabChanged;
  final ValueChanged<ExpeditionStoredOrder> onDispatchStored;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExpeditionTabs(showStored: showStored, onChanged: onTabChanged),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.local_shipping_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  showStored ? 'Armazenadas' : 'OPs prontas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _CountBadge(
                value: '${showStored ? storedOrders.length : orders.length}',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            showStored
                ? 'Separadas para armazenamento pela expedicao.'
                : 'Aprovadas no teste para conferencia e despacho.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          if (showStored)
            _StoredOrdersList(
              storedOrders: storedOrders,
              onDispatch: onDispatchStored,
              showDispatchAction: false,
            )
          else
            for (var i = 0; i < orders.length; i++) ...[
              _ExpeditionCard(
                order: orders[i],
                selected: i == selectedIndex,
                status: statuses[i] ?? ExpeditionStatus.waiting,
                dispatchSummary: dispatchSummaries[orders[i].number],
                onTap: () => onSelect(i),
              ),
              if (i < orders.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _DesktopExpeditionDetail extends StatelessWidget {
  const _DesktopExpeditionDetail({
    required this.order,
    required this.status,
    required this.dispatchSummary,
    required this.onStart,
    required this.onPause,
    required this.onFinish,
  });

  final ExpeditionOrder order;
  final ExpeditionStatus status;
  final ExpeditionDispatchSummary? dispatchSummary;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.number,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order.product,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.readyAgo,
                      style: const TextStyle(
                        color: AppColors.smallText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _ExpeditionStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 24),
          _ExpeditionMetrics(order: order),
          if (status == ExpeditionStatus.completed &&
              dispatchSummary != null) ...[
            const SizedBox(height: 14),
            _DispatchSummaryPanel(summary: dispatchSummary!),
          ],
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _DestinationPanel(order: order)),
              const SizedBox(width: 16),
              Expanded(child: _PackagingPanel(order: order)),
            ],
          ),
          const SizedBox(height: 28),
          _DividerLine(),
          const SizedBox(height: 28),
          const Text(
            'Acoes da expedicao',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _actionHint(status),
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          _ExpeditionActions(
            status: status,
            onStart: onStart,
            onPause: onPause,
            onFinish: onFinish,
          ),
        ],
      ),
    );
  }

  String _actionHint(ExpeditionStatus status) {
    return switch (status) {
      ExpeditionStatus.waiting =>
        'Inicie a conferencia para liberar pausa e despacho.',
      ExpeditionStatus.active =>
        'Conferencia em andamento. Pause ou finalize o despacho.',
      ExpeditionStatus.paused =>
        'OP pausada. Retome ou finalize com assinatura.',
      ExpeditionStatus.completed => 'OP finalizada na expedicao.',
    };
  }
}

class _ExpeditionTabs extends StatelessWidget {
  const _ExpeditionTabs({
    required this.showStored,
    required this.onChanged,
    this.compact = false,
  });

  final bool showStored;
  final ValueChanged<bool> onChanged;
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
            child: _ExpeditionTabButton(
              label: 'Prontas',
              active: !showStored,
              onTap: () => onChanged(false),
              compact: compact,
            ),
          ),
          Expanded(
            child: _ExpeditionTabButton(
              label: 'Armazenadas',
              active: showStored,
              onTap: () => onChanged(true),
              compact: compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpeditionTabButton extends StatelessWidget {
  const _ExpeditionTabButton({
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
          padding: EdgeInsets.symmetric(vertical: compact ? 9 : 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? AppColors.primary : AppColors.textMuted,
              fontSize: compact ? 13 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _StoredOverview extends StatelessWidget {
  const _StoredOverview({
    required this.storedOrders,
    required this.dispatchedOrders,
    required this.onDispatch,
    this.compact = false,
  });

  final List<ExpeditionStoredOrder> storedOrders;
  final List<ExpeditionDispatchedOrder> dispatchedOrders;
  final ValueChanged<ExpeditionStoredOrder> onDispatch;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Ainda armazenadas',
          subtitle: 'Saldo que continua separado para armazenamento.',
          compact: compact,
        ),
        const SizedBox(height: 12),
        _StoredOrdersList(
          storedOrders: storedOrders,
          onDispatch: onDispatch,
          compact: compact,
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Expedidas',
          subtitle: 'Quantidades que ja sairam da expedicao.',
          compact: compact,
        ),
        const SizedBox(height: 12),
        _DispatchedOrdersList(
          dispatchedOrders: dispatchedOrders,
          compact: compact,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.compact,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.text,
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(color: AppColors.muted, fontSize: compact ? 11 : 12),
        ),
      ],
    );
  }
}

class _StoredOrdersList extends StatelessWidget {
  const _StoredOrdersList({
    required this.storedOrders,
    required this.onDispatch,
    this.showDispatchAction = true,
    this.compact = false,
  });

  final List<ExpeditionStoredOrder> storedOrders;
  final ValueChanged<ExpeditionStoredOrder> onDispatch;
  final bool showDispatchAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (storedOrders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 16 : 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Nenhuma OP armazenada.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < storedOrders.length; i++) ...[
          _StoredOrderCard(
            order: storedOrders[i],
            onDispatch: () => onDispatch(storedOrders[i]),
            showDispatchAction: showDispatchAction,
            compact: compact,
          ),
          if (i < storedOrders.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DispatchedOrdersList extends StatelessWidget {
  const _DispatchedOrdersList({
    required this.dispatchedOrders,
    this.compact = false,
  });

  final List<ExpeditionDispatchedOrder> dispatchedOrders;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (dispatchedOrders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 16 : 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Nenhuma OP expedida.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < dispatchedOrders.length; i++) ...[
          _DispatchedOrderCard(order: dispatchedOrders[i], compact: compact),
          if (i < dispatchedOrders.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DispatchedOrderCard extends StatelessWidget {
  const _DispatchedOrderCard({required this.order, this.compact = false});

  final ExpeditionDispatchedOrder order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: compact ? 14 : 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      order.quantityLabel,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  order.product,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${order.origin} · ${order.orderCode} · ${order.dispatchedAt}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.smallText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoredOrderCard extends StatelessWidget {
  const _StoredOrderCard({
    required this.order,
    required this.onDispatch,
    required this.showDispatchAction,
    this.compact = false,
  });

  final ExpeditionStoredOrder order;
  final VoidCallback onDispatch;
  final bool showDispatchAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.number,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F6EC),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.typeLabel,
                  style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            order.product,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${order.quantityLabel} · ${order.orderCode} · ${order.storedAt}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.smallText, fontSize: 11),
          ),
          if (showDispatchAction) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: compact ? 42 : 44,
              child: OutlinedButton.icon(
                onPressed: onDispatch,
                icon: const Icon(Icons.local_shipping_rounded, size: 18),
                label: const Text(
                  'Expedir',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StoredOrdersPanel extends StatelessWidget {
  const _StoredOrdersPanel({
    required this.storedOrders,
    required this.dispatchedOrders,
    required this.onDispatch,
  });

  final List<ExpeditionStoredOrder> storedOrders;
  final List<ExpeditionDispatchedOrder> dispatchedOrders;
  final ValueChanged<ExpeditionStoredOrder> onDispatch;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OPs armazenadas',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Quantidades que foram separadas para armazenamento pela expedicao.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 22),
          _StoredOverview(
            storedOrders: storedOrders,
            dispatchedOrders: dispatchedOrders,
            onDispatch: onDispatch,
          ),
        ],
      ),
    );
  }
}

class _ExpeditionCard extends StatelessWidget {
  const _ExpeditionCard({
    required this.order,
    required this.selected,
    required this.status,
    required this.dispatchSummary,
    required this.onTap,
    this.compact = false,
  });

  final ExpeditionOrder order;
  final bool selected;
  final ExpeditionStatus status;
  final ExpeditionDispatchSummary? dispatchSummary;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = status != ExpeditionStatus.waiting;
    final radius = BorderRadius.circular(14);

    return Material(
      color: selected
          ? const Color(0xFFEAF7FF)
          : active
          ? status.surface
          : Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 16,
            compact ? 13 : 15,
            compact ? 14 : 16,
            compact ? 13 : 15,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : active
                  ? status.color.withValues(alpha: 0.35)
                  : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                if (active) ...[
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: status.color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.number,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: compact ? 15 : 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (active)
                            _ExpeditionStatusChip(
                              status: status,
                              compact: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        order.product,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        '${order.quantity} · ${order.orderCode}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.smallText,
                          fontSize: 11,
                        ),
                      ),
                      if (status == ExpeditionStatus.completed &&
                          dispatchSummary != null) ...[
                        const SizedBox(height: 8),
                        _DispatchSummaryLine(
                          summary: dispatchSummary!,
                          compact: compact,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.chevron_right_rounded,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.iconMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpeditionStatusChip extends StatelessWidget {
  const _ExpeditionStatusChip({required this.status, this.compact = false});

  final ExpeditionStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: status.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: compact ? 12 : 14, color: status.color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DispatchSummaryLine extends StatelessWidget {
  const _DispatchSummaryLine({required this.summary, required this.compact});

  final ExpeditionDispatchSummary summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 6,
      children: [
        _MiniQuantityPill(
          label: 'Expedida',
          value: summary.dispatchedLabel,
          color: AppColors.primary,
          compact: compact,
        ),
        if (summary.storedQuantity > 0)
          _MiniQuantityPill(
            label: 'Armazenada',
            value: summary.storedLabel,
            color: AppColors.green,
            compact: compact,
          ),
      ],
    );
  }
}

class _MiniQuantityPill extends StatelessWidget {
  const _MiniQuantityPill({
    required this.label,
    required this.value,
    required this.color,
    required this.compact,
  });

  final String label;
  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DispatchSummaryPanel extends StatelessWidget {
  const _DispatchSummaryPanel({required this.summary});

  final ExpeditionDispatchSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MetricItem(
              label: 'Expedida',
              value: summary.dispatchedLabel,
              compact: false,
            ),
          ),
          Container(
            width: 1,
            height: 42,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0xFFE9F0F5),
          ),
          Expanded(
            child: _MetricItem(
              label: 'Armazenada',
              value: summary.storedLabel,
              compact: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpeditionMetrics extends StatelessWidget {
  const _ExpeditionMetrics({required this.order, this.compact = false});

  final ExpeditionOrder order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Quantidade', order.quantity),
      ('Origem', order.origin),
      ('Liberada', order.readyAt),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 12 : 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4EDF4)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            Expanded(
              child: _MetricItem(
                label: metrics[i].$1,
                value: metrics[i].$2,
                compact: compact,
              ),
            ),
            if (i < metrics.length - 1)
              Container(
                width: 1,
                height: compact ? 36 : 42,
                margin: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
                color: const Color(0xFFE9F0F5),
              ),
          ],
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.compact,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.label,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.text,
            fontSize: compact ? 16 : 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DestinationPanel extends StatelessWidget {
  const _DestinationPanel({required this.order, this.compact = false});

  final ExpeditionOrder order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Pedido', order.orderCode),
      ('Destino', order.customer),
      ('Canal', order.channel),
      ('Transporte', order.carrier),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB8DFF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Destino',
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            _InfoRow(label: rows[i].$1, value: rows[i].$2),
            if (i < rows.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _PackagingPanel extends StatelessWidget {
  const _PackagingPanel({required this.order, this.compact = false});

  final ExpeditionOrder order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4EDF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conferencia de embalagem',
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < order.packaging.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.packaging[i],
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: compact ? 12 : 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            if (i < order.packaging.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.label,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpeditionActions extends StatelessWidget {
  const _ExpeditionActions({
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onFinish,
    this.compact = false,
  });

  final ExpeditionStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (status == ExpeditionStatus.completed) {
      return Container(
        width: compact ? double.infinity : 480,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F6EC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFE5CC)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Despacho finalizado e assinado.',
                style: TextStyle(
                  color: AppColors.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (status == ExpeditionStatus.waiting) {
      return _ActionButton(
        label: 'Iniciar conferencia',
        icon: Icons.play_arrow_rounded,
        onPressed: onStart,
        fillColor: AppColors.primary,
        foregroundColor: Colors.white,
        width: compact ? double.infinity : 250,
      );
    }

    if (status == ExpeditionStatus.paused) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _ActionButton(
            label: 'Retomar conferencia',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
            fillColor: AppColors.primary,
            foregroundColor: Colors.white,
            width: compact ? double.infinity : 250,
          ),
          _ActionButton(
            label: 'Finalizar despacho',
            icon: Icons.check_rounded,
            onPressed: onFinish,
            foregroundColor: AppColors.green,
            borderColor: AppColors.green,
            width: compact ? double.infinity : 250,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionButton(
          label: 'Pausar OP',
          icon: Icons.pause_rounded,
          onPressed: onPause,
          foregroundColor: AppColors.orangeText,
          borderColor: AppColors.orange,
          width: compact ? double.infinity : 190,
        ),
        _ActionButton(
          label: 'Finalizar despacho',
          icon: Icons.check_rounded,
          onPressed: onFinish,
          fillColor: AppColors.green,
          foregroundColor: Colors.white,
          width: compact ? double.infinity : 250,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
    this.icon,
    this.fillColor,
    this.borderColor,
    this.width,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color? fillColor;
  final Color? borderColor;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          backgroundColor: fillColor ?? Colors.white,
          foregroundColor: foregroundColor,
          side: BorderSide(
            color: borderColor ?? fillColor ?? Colors.white,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EDF4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 1,
      color: const Color(0xFFEEF3F7),
    );
  }
}

class _QuantityFlowPreview extends StatelessWidget {
  const _QuantityFlowPreview({
    required this.available,
    required this.middleLabel,
    required this.middleValue,
    required this.resultLabel,
    required this.resultValue,
  });

  final int available;
  final String middleLabel;
  final int middleValue;
  final String resultLabel;
  final int resultValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuantityFlowItem(
              label: 'Disponivel',
              value: available,
              color: AppColors.text,
            ),
          ),
          Expanded(
            child: _QuantityFlowItem(
              label: middleLabel,
              value: middleValue,
              color: AppColors.green,
            ),
          ),
          Expanded(
            child: _QuantityFlowItem(
              label: resultLabel,
              value: resultValue,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityFlowItem extends StatelessWidget {
  const _QuantityFlowItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.label,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$value un',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

Future<int?> showStoredDispatchDialog(
  BuildContext context,
  ExpeditionStoredOrder order,
) {
  final compact = MediaQuery.sizeOf(context).width < 720;

  if (compact) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StoredDispatchSheet(order: order, compact: true),
    );
  }

  return showDialog<int>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      backgroundColor: Colors.transparent,
      child: _StoredDispatchSheet(order: order),
    ),
  );
}

class _StoredDispatchSheet extends StatefulWidget {
  const _StoredDispatchSheet({required this.order, this.compact = false});

  final ExpeditionStoredOrder order;
  final bool compact;

  @override
  State<_StoredDispatchSheet> createState() => _StoredDispatchSheetState();
}

class _StoredDispatchSheetState extends State<_StoredDispatchSheet> {
  late final TextEditingController _quantityController;
  String? _quantityError;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: '${widget.order.quantity}',
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxQuantity = widget.order.quantity;
    final requestedQuantity = int.tryParse(_quantityController.text) ?? 0;
    final previewQuantity = requestedQuantity.clamp(0, maxQuantity).toInt();
    final remainingQuantity = maxQuantity - previewQuantity;

    return _ModalSurface(
      compact: widget.compact,
      maxWidth: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.compact) const _SheetHandle(),
          const Text(
            'Expedir armazenada',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.order.number} possui $maxQuantity un armazenadas.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFB8DFF2)),
            ),
            child: Text(
              '${widget.order.orderCode} · ${widget.order.product}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Quantidade para expedir',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _quantityController,
            onChanged: (_) {
              setState(() => _quantityError = null);
            },
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '1 a $maxQuantity',
              errorText: _quantityError,
              filled: true,
              fillColor: const Color(0xFFF8FBFD),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: _dialogFieldBorder(AppColors.border),
              enabledBorder: _dialogFieldBorder(AppColors.border),
              focusedBorder: _dialogFieldBorder(AppColors.primary, width: 1.5),
            ),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _QuantityFlowPreview(
            available: maxQuantity,
            middleLabel: 'Sera expedido',
            middleValue: previewQuantity,
            resultLabel: 'Restara',
            resultValue: remainingQuantity,
          ),
          const SizedBox(height: 10),
          _SmallChoiceButton(
            label: 'Expedir tudo',
            onTap: () {
              setState(() {
                _quantityController.text = '$maxQuantity';
                _quantityError = null;
              });
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _DialogButton(
                  label: 'Cancelar',
                  onPressed: () => Navigator.of(context).pop(null),
                  fillColor: const Color(0xFFF6F9FB),
                  foregroundColor: AppColors.muted,
                  borderColor: AppColors.border,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _DialogButton(
                  label: 'Expedir',
                  onPressed: _dispatch,
                  fillColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _dialogFieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  void _dispatch() {
    final quantity = int.tryParse(_quantityController.text.trim()) ?? -1;
    final maxQuantity = widget.order.quantity;
    if (quantity <= 0 || quantity > maxQuantity) {
      setState(() {
        _quantityError = 'Use uma quantidade entre 1 e $maxQuantity.';
      });
      return;
    }
    Navigator.of(context).pop(quantity);
  }
}

Future<int?> showExpeditionPinDialog(
  BuildContext context,
  ExpeditionOrder order,
) {
  final compact = MediaQuery.sizeOf(context).width < 720;

  if (compact) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExpeditionPinSheet(order: order, compact: true),
    );
  }

  return showDialog<int>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      backgroundColor: Colors.transparent,
      child: _ExpeditionPinSheet(order: order),
    ),
  );
}

class _ExpeditionPinSheet extends StatefulWidget {
  const _ExpeditionPinSheet({required this.order, this.compact = false});

  final ExpeditionOrder order;
  final bool compact;

  @override
  State<_ExpeditionPinSheet> createState() => _ExpeditionPinSheetState();
}

class _ExpeditionPinSheetState extends State<_ExpeditionPinSheet> {
  final _pinController = TextEditingController();
  late final TextEditingController _storageController;
  Operator? _operator;
  bool _invalidPin = false;
  bool _wrongStage = false;
  String? _storageError;

  @override
  void initState() {
    super.initState();
    _storageController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _pinController.dispose();
    _storageController.dispose();
    super.dispose();
  }

  void _onPinChanged(String value) {
    if (value.length < 4) {
      setState(() {
        _operator = null;
        _invalidPin = false;
        _wrongStage = false;
      });
      return;
    }

    final operator = context.read<OperatorAssignmentStore>().findByPin(value);
    setState(() {
      _operator = operator;
      _invalidPin = operator == null;
      _wrongStage = operator != null && operator.stage != WorkStage.expedition;
    });
  }

  @override
  Widget build(BuildContext context) {
    final valid = _operator != null && !_wrongStage;
    final maxQuantity = widget.order.quantityValue;
    final storageQuantity = int.tryParse(_storageController.text) ?? 0;
    final previewStorageQuantity = storageQuantity
        .clamp(0, maxQuantity)
        .toInt();
    final previewDispatchQuantity = maxQuantity - previewStorageQuantity;

    return _ModalSurface(
      compact: widget.compact,
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.compact) const _SheetHandle(),
          const Text(
            'Assinatura do operador',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Digite o PIN para finalizar o despacho da ${widget.order.number}.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFB8DFF2)),
            ),
            child: Text(
              '${widget.order.orderCode} · ${widget.order.customer}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Quantidade para armazenamento',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _storageController,
            onChanged: (_) {
              setState(() => _storageError = null);
            },
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '0 a $maxQuantity',
              errorText: _storageError,
              filled: true,
              fillColor: const Color(0xFFF8FBFD),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: _pinBorder(AppColors.border),
              enabledBorder: _pinBorder(AppColors.border),
              focusedBorder: _pinBorder(AppColors.primary, width: 1.5),
            ),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SmallChoiceButton(
                  label: 'Sem armazenar',
                  onTap: () {
                    setState(() {
                      _storageController.text = '0';
                      _storageError = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallChoiceButton(
                  label: 'Armazenar tudo',
                  onTap: () {
                    setState(() {
                      _storageController.text = '$maxQuantity';
                      _storageError = null;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _QuantityFlowPreview(
            available: maxQuantity,
            middleLabel: 'Vai armazenar',
            middleValue: previewStorageQuantity,
            resultLabel: 'Sera expedido',
            resultValue: previewDispatchQuantity,
          ),
          const SizedBox(height: 24),
          const Text(
            'PIN (4 digitos)',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pinController,
            onChanged: _onPinChanged,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 12,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF8FBFD),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: _pinBorder(AppColors.border),
              enabledBorder: _pinBorder(
                _invalidPin
                    ? const Color(0xFFD45B5B)
                    : valid
                    ? AppColors.green
                    : AppColors.border,
              ),
              focusedBorder: _pinBorder(
                _invalidPin
                    ? const Color(0xFFD45B5B)
                    : valid
                    ? AppColors.green
                    : AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_invalidPin)
            const _PinFeedback(
              icon: Icons.error_outline_rounded,
              color: Color(0xFFD45B5B),
              bgColor: Color(0xFFFFF0F0),
              borderColor: Color(0xFFE8C4C4),
              text: 'PIN nao encontrado. Verifique e tente novamente.',
            ),
          if (valid)
            _PinFeedback(
              icon: Icons.check_circle_rounded,
              color: AppColors.green,
              bgColor: const Color(0xFFE7F6EC),
              borderColor: const Color(0xFFBFE5CC),
              text: 'Operador: ${_operator!.name} (${_operator!.stage.label})',
            ),
          if (_wrongStage && _operator != null)
            _PinFeedback(
              icon: Icons.warning_amber_rounded,
              color: AppColors.orangeText,
              bgColor: const Color(0xFFFFF8EC),
              borderColor: const Color(0xFFEFDFBF),
              text:
                  'PIN de ${_operator!.name}, vinculado a etapa "${_operator!.stage.label}". '
                  'Voce esta na etapa "Expedicao".',
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _DialogButton(
                  label: 'Cancelar',
                  onPressed: () => Navigator.of(context).pop(null),
                  fillColor: const Color(0xFFF6F9FB),
                  foregroundColor: AppColors.muted,
                  borderColor: AppColors.border,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _DialogButton(
                  label: 'Finalizar',
                  onPressed: valid ? _finish : null,
                  fillColor: valid ? AppColors.green : const Color(0xFFE4EDF4),
                  foregroundColor: valid ? Colors.white : AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _pinBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  void _finish() {
    final quantity = int.tryParse(_storageController.text.trim()) ?? -1;
    final maxQuantity = widget.order.quantityValue;
    if (quantity < 0 || quantity > maxQuantity) {
      setState(() {
        _storageError = 'Use uma quantidade entre 0 e $maxQuantity.';
      });
      return;
    }
    Navigator.of(context).pop(quantity);
  }
}

class _SmallChoiceButton extends StatelessWidget {
  const _SmallChoiceButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _ModalSurface extends StatelessWidget {
  const _ModalSurface({
    required this.child,
    required this.compact,
    required this.maxWidth,
  });

  final Widget child;
  final bool compact;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: compact ? Alignment.bottomCenter : Alignment.center,
      child: Container(
        width: compact ? double.infinity : null,
        constraints: BoxConstraints(
          maxWidth: compact ? double.infinity : maxWidth,
        ),
        margin: EdgeInsets.only(
          left: compact ? 10 : 0,
          right: compact ? 10 : 0,
          bottom: compact ? 10 : 0,
        ),
        padding: EdgeInsets.fromLTRB(
          compact ? 24 : 36,
          compact ? 16 : 32,
          compact ? 24 : 36,
          compact ? 24 : 28,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 22 : 16),
        ),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.fillColor,
    required this.foregroundColor,
    this.onPressed,
    this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color fillColor;
  final Color foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: fillColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: const Color(0xFFE4EDF4),
          disabledForegroundColor: AppColors.muted,
          side: BorderSide(color: borderColor ?? fillColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 50,
        height: 4,
        margin: const EdgeInsets.only(bottom: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFCBD7E1),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _PinFeedback extends StatelessWidget {
  const _PinFeedback({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalExpeditionNotice extends StatelessWidget {
  const _LocalExpeditionNotice();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Conferência local. Não emite nota nem altera o estoque do Protheus.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        IconButton(
          tooltip: 'Consultar Protheus',
          icon: const Icon(Icons.manage_search_outlined),
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed('/expedicao'),
        ),
      ],
    ),
  );
}
