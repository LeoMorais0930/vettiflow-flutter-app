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

class TestOperation {
  const TestOperation({
    required this.number,
    required this.product,
    required this.quantity,
    required this.quantityValue,
    required this.origin,
    required this.receivedAt,
    required this.receivedAgo,
    required this.station,
    required this.checklist,
    required this.firmwareDefects,
  });

  final String number;
  final String product;
  final String quantity;
  final int quantityValue;
  final String origin;
  final String receivedAt;
  final String receivedAgo;
  final String station;
  final List<String> checklist;
  final List<DefectEntry> firmwareDefects;
}

class DefectEntry {
  const DefectEntry({
    required this.code,
    required this.title,
    required this.quantity,
  });

  final String code;
  final String title;
  final String quantity;
}

class TestDefectOption {
  const TestDefectOption({required this.code, required this.title});

  final String code;
  final String title;

  static const all = [
    TestDefectOption(code: 'T1', title: 'Nao liga'),
    TestDefectOption(code: 'T2', title: 'Sem resposta'),
    TestDefectOption(code: 'T3', title: 'Consumo alto'),
    TestDefectOption(code: 'T4', title: 'Falha RF'),
    TestDefectOption(code: 'T5', title: 'LED incorreto'),
    TestDefectOption(code: 'T6', title: 'Botao falhando'),
    TestDefectOption(code: 'T7', title: 'Falha intermitente'),
    TestDefectOption(code: 'T8', title: 'Outro defeito'),
  ];
}

enum TestingStatus {
  waiting(
    'Aguardando',
    AppColors.muted,
    Color(0xFFEFF3F7),
    Icons.schedule_rounded,
  ),
  active(
    'Em teste',
    AppColors.primary,
    Color(0xFFE7F4FB),
    Icons.science_rounded,
  ),
  paused(
    'Pausada',
    AppColors.orangeText,
    Color(0xFFFBF1E2),
    Icons.pause_rounded,
  ),
  completed(
    'Concluida',
    AppColors.green,
    Color(0xFFE7F6EC),
    Icons.check_circle_rounded,
  );

  const TestingStatus(this.label, this.color, this.surface, this.icon);

  final String label;
  final Color color;
  final Color surface;
  final IconData icon;
}

class TestingPage extends StatefulWidget {
  const TestingPage({super.key});

  @override
  State<TestingPage> createState() => _TestingPageState();
}

class _TestingPageState extends State<TestingPage> {
  var _selectedIndex = 0;
  bool _initialSelectionApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialSelectionApplied) return;
    _initialSelectionApplied = true;
    final number = ModalRoute.of(context)?.settings.arguments;
    if (number is! String) return;
    final index = _flowOrders().indexWhere((order) => order.number == number);
    if (index >= 0) _selectedIndex = index;
  }

  List<ProductionOrderFlow> _flowOrders() => context
      .read<ProductionFlowStore>()
      .ordersAtStage(ProductionStage.testing);

  ProductionOrderFlow? _selectedFlowOrder() {
    final orders = _flowOrders();
    if (orders.isEmpty) return null;
    final index = _selectedIndex.clamp(0, orders.length - 1).toInt();
    return orders[index];
  }

  TestOperation _operationFromFlow(ProductionOrderFlow order) {
    final catalog = context.read<ProductionFlowStore>().catalogItem(
      order.productCode,
    );
    final elapsed = order.activeElapsed(DateTime.now());
    final checklist = catalog.components.isEmpty
        ? const [
            'Inicializacao e consumo em repouso',
            'Resposta funcional do produto',
            'Inspecao visual final',
          ]
        : [
            'Inicializacao e consumo em repouso',
            'Validar ${catalog.components.first.description}',
            'Inspecao visual final',
          ];
    return TestOperation(
      number: order.number,
      product: order.productLabel,
      quantity: order.productionQuantityLabel,
      quantityValue: order.productionQuantity.floor(),
      origin: order.previousStageLabel,
      receivedAt: _clockLabel(order.updatedAt),
      receivedAgo: order.timings[ProductionStage.testing]?.startedAt == null
          ? 'Aguardando inicio'
          : 'Tempo na etapa: ${formatProductionDuration(elapsed)}',
      station: '',
      checklist: checklist,
      firmwareDefects: order.testDefects
          .map(
            (defect) => DefectEntry(
              code: defect.code,
              title: defect.title,
              quantity: '${defect.quantity} un',
            ),
          )
          .toList(),
    );
  }

  TestingStatus _statusFromFlow(ProductionOrderFlow order) {
    return switch (order.status) {
      ProductionRunStatus.waiting => TestingStatus.waiting,
      ProductionRunStatus.active => TestingStatus.active,
      ProductionRunStatus.paused => TestingStatus.paused,
      ProductionRunStatus.completed => TestingStatus.completed,
    };
  }

  void _select(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _startTest() async {
    final order = _selectedFlowOrder();
    if (order == null) return;
    final operator = context.read<OperatorAssignmentStore>().currentOperator;
    await context.read<ProductionFlowStore>().startStage(
      order.number,
      operatorName: operator?.name ?? 'Operador',
      operatorPin: operator?.pin,
    );
  }

  Future<void> _pauseOperation() async {
    final order = _selectedFlowOrder();
    if (order == null) return;
    final request = await showPauseReasonDialog(
      context,
      stage: ProductionStage.testing,
      maxQuantity: order.productionQuantity.floor(),
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

  Future<void> _completeTest() async {
    final flowOrder = _selectedFlowOrder();
    if (flowOrder == null) return;
    final operation = _operationFromFlow(flowOrder);
    final defects = await showTestDefectsDialog(context, operation);
    if (!mounted || defects == null) return;

    final signed = await showTestPinDialog(
      context,
      operation,
      defects: defects,
    );
    if (!mounted || signed == null) return;

    await context.read<ProductionFlowStore>().completeTesting(
      flowOrder.number,
      defects: defects,
      operatorName: signed.name,
      operatorPin: signed.pin,
    );
    if (!mounted) return;
    final current = context.read<ProductionFlowStore>().orders.firstWhere(
      (o) => o.number == flowOrder.number,
    );
    final suffix = current.currentStage == ProductionStage.testing
        ? 'sua sessão foi concluída. Há outros operadores nesta etapa.'
        : current.isDone
        ? 'sequência concluída no VettiFlow.'
        : 'liberada para ${current.currentStage.label}.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${operation.number} $suffix')));
  }

  void _showMobileActions(BuildContext context) {
    final order = _selectedFlowOrder();
    if (order == null) return;
    final status = _statusFromFlow(order);
    final operation = _operationFromFlow(order);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MobileTestingActionSheet(
        operation: operation,
        status: status,
        onStart: () {
          Navigator.pop(ctx);
          _startTest();
        },
        onPause: () {
          Navigator.pop(ctx);
          _pauseOperation();
        },
        onComplete: () {
          Navigator.pop(ctx);
          _completeTest();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flowOrders = context.watch<ProductionFlowStore>().ordersAtStage(
      ProductionStage.testing,
    );
    if (_selectedIndex >= flowOrders.length) {
      _selectedIndex = flowOrders.isEmpty ? 0 : flowOrders.length - 1;
    }
    final operations = flowOrders.map(_operationFromFlow).toList();
    final statuses = {
      for (var i = 0; i < flowOrders.length; i++)
        i: _statusFromFlow(flowOrders[i]),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = AppBreakpoints.fromWidth(constraints.maxWidth);
        final isMobile = formFactor != AppFormFactor.expanded;

        if (operations.isEmpty) {
          return _EmptyTestingStage(compact: isMobile);
        }

        if (isMobile) {
          return _MobileTestingLayout(
            operations: operations,
            selectedIndex: _selectedIndex,
            statuses: statuses,
            onSelect: (index) {
              _select(index);
              _showMobileActions(context);
            },
          );
        }

        return _DesktopTestingLayout(
          operations: operations,
          selectedIndex: _selectedIndex,
          statuses: statuses,
          onSelect: _select,
          onStart: _startTest,
          onPause: _pauseOperation,
          onComplete: _completeTest,
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

class _EmptyTestingStage extends StatelessWidget {
  const _EmptyTestingStage({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: compact
          ? const Color(0xFF101820)
          : AppColors.pageBackground,
      body: SafeArea(
        child: Center(
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: compact ? 430 : double.infinity,
            ),
            margin: compact ? const EdgeInsets.all(10) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: AppColors.pageBackground,
              borderRadius: BorderRadius.circular(compact ? 22 : 0),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                VettiTopBar(
                  title: 'Teste de Producao',
                  operatorName:
                      context
                          .watch<OperatorAssignmentStore>()
                          .currentOperator
                          ?.name ??
                      'Operador',
                  operatorRole: 'Teste',
                  compact: compact,
                ),
                const Expanded(
                  child: _EmptyStageMessage(
                    icon: Icons.science_rounded,
                    title: 'Nenhuma OP em teste',
                    text:
                        'As OPs aparecem aqui assim que a soldagem for concluida.',
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

class _EmptyStageMessage extends StatelessWidget {
  const _EmptyStageMessage({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileTestingActionSheet extends StatelessWidget {
  const _MobileTestingActionSheet({
    required this.operation,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
  });

  final TestOperation operation;
  final TestingStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;

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
                        operation.number,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        operation.product,
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
                _TestingStatusChip(status: status, compact: true),
              ],
            ),
            const SizedBox(height: 16),
            _TestingMetrics(operation: operation, compact: true),
            const SizedBox(height: 16),
            _FirmwareDefectsPanel(operation: operation, compact: true),
            const SizedBox(height: 20),
            _TestingActions(
              status: status,
              compact: true,
              onStart: onStart,
              onPause: onPause,
              onComplete: onComplete,
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileTestingLayout extends StatelessWidget {
  const _MobileTestingLayout({
    required this.operations,
    required this.selectedIndex,
    required this.statuses,
    required this.onSelect,
  });

  final List<TestOperation> operations;
  final int selectedIndex;
  final Map<int, TestingStatus> statuses;
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
                  title: 'Teste de Producao',
                  operatorName:
                      context
                          .watch<OperatorAssignmentStore>()
                          .currentOperator
                          ?.name ??
                      'Operador',
                  compact: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OPs para teste',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Toque na OP para ver checklist e acoes.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (var i = 0; i < operations.length; i++) ...[
                          _TestingCard(
                            operation: operations[i],
                            selected: i == selectedIndex,
                            status: statuses[i] ?? TestingStatus.waiting,
                            compact: true,
                            onTap: () => onSelect(i),
                          ),
                          if (i < operations.length - 1)
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

class _DesktopTestingLayout extends StatelessWidget {
  const _DesktopTestingLayout({
    required this.operations,
    required this.selectedIndex,
    required this.statuses,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
  });

  final List<TestOperation> operations;
  final int selectedIndex;
  final Map<int, TestingStatus> statuses;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;

  TestOperation get selectedOperation => operations[selectedIndex];
  TestingStatus get status => statuses[selectedIndex] ?? TestingStatus.waiting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          VettiTopBar(
            title: 'Teste de Producao',
            operatorName:
                context
                    .watch<OperatorAssignmentStore>()
                    .currentOperator
                    ?.name ??
                'Operador',
            operatorRole: 'Teste',
          ),
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
                        child: _DesktopTestingQueue(
                          operations: operations,
                          selectedIndex: selectedIndex,
                          statuses: statuses,
                          onSelect: onSelect,
                        ),
                      ),
                      const SizedBox(width: 36),
                      Expanded(
                        child: _DesktopTestingDetail(
                          operation: selectedOperation,
                          status: status,
                          onStart: onStart,
                          onPause: onPause,
                          onComplete: onComplete,
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

class _DesktopTestingQueue extends StatelessWidget {
  const _DesktopTestingQueue({
    required this.operations,
    required this.selectedIndex,
    required this.statuses,
    required this.onSelect,
  });

  final List<TestOperation> operations;
  final int selectedIndex;
  final Map<int, TestingStatus> statuses;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'OPs para teste',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _CountBadge(value: '${operations.length}'),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Liberadas pela soldagem para teste funcional.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < operations.length; i++) ...[
            _TestingCard(
              operation: operations[i],
              selected: i == selectedIndex,
              status: statuses[i] ?? TestingStatus.waiting,
              onTap: () => onSelect(i),
            ),
            if (i < operations.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DesktopTestingDetail extends StatelessWidget {
  const _DesktopTestingDetail({
    required this.operation,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
  });

  final TestOperation operation;
  final TestingStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;

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
                      operation.number,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      operation.product,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      operation.receivedAgo,
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
              _TestingStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 24),
          _TestingMetrics(operation: operation),
          const SizedBox(height: 24),
          _FirmwareDefectsPanel(operation: operation),
          const SizedBox(height: 28),
          _DividerLine(),
          const SizedBox(height: 28),
          const Text(
            'Acoes do teste',
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
          _TestingActions(
            status: status,
            onStart: onStart,
            onPause: onPause,
            onComplete: onComplete,
          ),
        ],
      ),
    );
  }

  String _actionHint(TestingStatus status) {
    return switch (status) {
      TestingStatus.waiting => 'Inicie o teste para liberar pausa e conclusao.',
      TestingStatus.active => 'Teste em andamento. Pause ou conclua a OP.',
      TestingStatus.paused => 'OP pausada. Retome ou conclua com assinatura.',
      TestingStatus.completed => 'OP finalizada nesta etapa.',
    };
  }
}

class _TestingCard extends StatelessWidget {
  const _TestingCard({
    required this.operation,
    required this.selected,
    required this.status,
    required this.onTap,
    this.compact = false,
  });

  final TestOperation operation;
  final bool selected;
  final TestingStatus status;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = status != TestingStatus.waiting;
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
                              operation.number,
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
                            _TestingStatusChip(status: status, compact: true),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        operation.product,
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
                        operation.quantity,
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

class _TestingStatusChip extends StatelessWidget {
  const _TestingStatusChip({required this.status, this.compact = false});

  final TestingStatus status;
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

class _TestingMetrics extends StatelessWidget {
  const _TestingMetrics({required this.operation, this.compact = false});

  final TestOperation operation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Quantidade', operation.quantity),
      ('Origem', operation.origin),
      ('Recebida', operation.receivedAt),
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

class _FirmwareDefectsPanel extends StatelessWidget {
  const _FirmwareDefectsPanel({required this.operation, this.compact = false});

  final TestOperation operation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFDFBF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Defeitos da gravacao',
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (operation.firmwareDefects.isEmpty)
            const Text(
              'Nenhum defeito herdado.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            )
          else
            for (final defect in operation.firmwareDefects) ...[
              Text(
                '${defect.code} - ${defect.title}: ${defect.quantity}',
                style: const TextStyle(
                  color: AppColors.orangeText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
            ],
        ],
      ),
    );
  }
}

class _TestingActions extends StatelessWidget {
  const _TestingActions({
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
    this.compact = false,
  });

  final TestingStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (status == TestingStatus.completed) {
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
                'O teste será registrado e a OP seguirá a sequência planejada. Defeitos ficam disponíveis para o suporte.',
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

    if (status == TestingStatus.waiting) {
      return _ActionButton(
        label: 'Iniciar teste',
        icon: Icons.play_arrow_rounded,
        onPressed: onStart,
        fillColor: AppColors.primary,
        foregroundColor: Colors.white,
        width: compact ? double.infinity : 220,
      );
    }

    if (status == TestingStatus.paused) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _ActionButton(
            label: 'Retomar teste',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
            fillColor: AppColors.primary,
            foregroundColor: Colors.white,
            width: compact ? double.infinity : 220,
          ),
          _ActionButton(
            label: 'Concluir teste',
            icon: Icons.check_rounded,
            onPressed: onComplete,
            foregroundColor: AppColors.green,
            borderColor: AppColors.green,
            width: compact ? double.infinity : 220,
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
          label: 'Concluir teste',
          icon: Icons.check_rounded,
          onPressed: onComplete,
          fillColor: AppColors.green,
          foregroundColor: Colors.white,
          width: compact ? double.infinity : 220,
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

Future<List<DefectRecord>?> showTestDefectsDialog(
  BuildContext context,
  TestOperation operation,
) {
  final compact = MediaQuery.sizeOf(context).width < 720;

  if (compact) {
    return showModalBottomSheet<List<DefectRecord>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _TestDefectsSheet(operation: operation, compact: true),
    );
  }

  return showDialog<List<DefectRecord>>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      backgroundColor: Colors.transparent,
      child: _TestDefectsSheet(operation: operation),
    ),
  );
}

class _TestDefectsSheet extends StatefulWidget {
  const _TestDefectsSheet({required this.operation, this.compact = false});

  final TestOperation operation;
  final bool compact;

  @override
  State<_TestDefectsSheet> createState() => _TestDefectsSheetState();
}

class _TestDefectsSheetState extends State<_TestDefectsSheet> {
  // code -> quantidade. A presença da chave indica que o defeito está marcado.
  final _quantities = <String, int>{};
  final _controllers = <String, TextEditingController>{};

  int get _maxQty =>
      widget.operation.quantityValue <= 0 ? 1 : widget.operation.quantityValue;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggle(String code) {
    setState(() {
      if (_quantities.containsKey(code)) {
        _quantities.remove(code);
      } else {
        _quantities[code] = 1;
        _controllers.putIfAbsent(code, () => TextEditingController()).text =
            '1';
      }
    });
  }

  void _setQty(String code, int value) {
    final clamped = value.clamp(1, _maxQty);
    setState(() => _quantities[code] = clamped);
  }

  List<DefectRecord> get _records => TestDefectOption.all
      .where((defect) => _quantities.containsKey(defect.code))
      .map(
        (defect) => DefectRecord(
          code: defect.code,
          title: defect.title,
          quantity: _quantities[defect.code]!,
        ),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final records = _records;
    final totalDefects = records.fold<int>(0, (sum, d) => sum + d.quantity);
    final exceedsOrder = totalDefects > _maxQty;

    return _ModalSurface(
      compact: widget.compact,
      maxWidth: 540,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.compact) const _SheetHandle(),
          const Text(
            'Defeitos do teste',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.operation.number} · marque os defeitos e informe quantos dispositivos foram afetados.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          _InheritedDefectsSummary(operation: widget.operation),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final defect in TestDefectOption.all)
                _DefectChip(
                  defect: defect,
                  selected: _quantities.containsKey(defect.code),
                  onTap: () => _toggle(defect.code),
                ),
            ],
          ),
          if (records.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Quantidade por defeito',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final defect in records) ...[
              _DefectQuantityRow(
                code: defect.code,
                title: defect.title,
                controller: _controllers[defect.code]!,
                maxQty: _maxQty,
                onChanged: (value) => _setQty(defect.code, value),
                onStep: (delta) {
                  final next = (_quantities[defect.code]! + delta).clamp(
                    1,
                    _maxQty,
                  );
                  _controllers[defect.code]!.text = '$next';
                  _setQty(defect.code, next);
                },
              ),
              const SizedBox(height: 8),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEFDFBF)),
              ),
              child: Text(
                exceedsOrder
                    ? 'Total $totalDefects maior que a quantidade da OP ($_maxQty).'
                    : 'Total: $totalDefects dispositivo${totalDefects == 1 ? '' : 's'} '
                          'em ${records.length} tipo${records.length == 1 ? '' : 's'} de defeito.',
                style: TextStyle(
                  color: exceedsOrder
                      ? const Color(0xFFD45B5B)
                      : AppColors.orangeText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
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
                  label: records.isEmpty
                      ? 'Continuar sem defeitos'
                      : 'Continuar com $totalDefects un',
                  onPressed: exceedsOrder
                      ? null
                      : () => Navigator.of(context).pop(records),
                  fillColor: exceedsOrder
                      ? const Color(0xFFCBD7E1)
                      : AppColors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DefectQuantityRow extends StatelessWidget {
  const _DefectQuantityRow({
    required this.code,
    required this.title,
    required this.controller,
    required this.maxQty,
    required this.onChanged,
    required this.onStep,
  });

  final String code;
  final String title;
  final TextEditingController controller;
  final int maxQty;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3EDF4)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              code,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _StepButton(icon: Icons.remove_rounded, onTap: () => onStep(-1)),
          SizedBox(
            width: 54,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed != null) onChanged(parsed);
              },
            ),
          ),
          _StepButton(icon: Icons.add_rounded, onTap: () => onStep(1)),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD8E6EE)),
          ),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _InheritedDefectsSummary extends StatelessWidget {
  const _InheritedDefectsSummary({required this.operation});

  final TestOperation operation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEFDFBF)),
      ),
      child: Text(
        operation.firmwareDefects.isEmpty
            ? 'Sem defeitos herdados da gravacao.'
            : 'Herdados da gravacao: ${operation.firmwareDefects.map((d) => d.code).join(', ')}',
        style: const TextStyle(
          color: AppColors.orangeText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DefectChip extends StatelessWidget {
  const _DefectChip({
    required this.defect,
    required this.selected,
    required this.onTap,
  });

  final TestDefectOption defect;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF4DB) : const Color(0xFFF8FBFD),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.orange : const Color(0xFFE3EDF4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.orange : const Color(0xFFEBF1F6),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                defect.code,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              defect.title,
              style: TextStyle(
                color: selected ? AppColors.orangeText : AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<Operator?> showTestPinDialog(
  BuildContext context,
  TestOperation operation, {
  List<DefectRecord> defects = const [],
}) {
  final compact = MediaQuery.sizeOf(context).width < 720;

  if (compact) {
    return showModalBottomSheet<Operator>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _TestPinSheet(operation: operation, defects: defects, compact: true),
    );
  }

  return showDialog<Operator>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      backgroundColor: Colors.transparent,
      child: _TestPinSheet(operation: operation, defects: defects),
    ),
  );
}

class _TestPinSheet extends StatefulWidget {
  const _TestPinSheet({
    required this.operation,
    this.defects = const [],
    this.compact = false,
  });

  final TestOperation operation;
  final List<DefectRecord> defects;
  final bool compact;

  @override
  State<_TestPinSheet> createState() => _TestPinSheetState();
}

class _TestPinSheetState extends State<_TestPinSheet> {
  final _pinController = TextEditingController();
  Operator? _operator;
  bool _invalidPin = false;
  bool _wrongStage = false;

  @override
  void dispose() {
    _pinController.dispose();
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
      _wrongStage = operator != null && operator.stage != WorkStage.testing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final valid = _operator != null && !_wrongStage;

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
            'Digite o PIN para concluir o teste da ${widget.operation.number}.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
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
                  'Voce esta na etapa "Teste".',
            ),
          if (widget.defects.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEFDFBF)),
              ),
              child: Text(
                'Defeitos do teste: ${widget.defects.map((d) => '${d.code} (${d.quantity})').join(', ')}',
                style: const TextStyle(
                  color: AppColors.orangeText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _DialogButton(
                  label: 'Cancelar',
                  onPressed: () => Navigator.of(context).pop(),
                  fillColor: const Color(0xFFF6F9FB),
                  foregroundColor: AppColors.muted,
                  borderColor: AppColors.border,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _DialogButton(
                  label: 'Concluir OP',
                  onPressed: valid
                      ? () => Navigator.of(context).pop(_operator)
                      : null,
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
