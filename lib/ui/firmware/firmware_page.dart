import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/layout/app_breakpoints.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/firmware_completion_dialogs.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/firmware_models.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/operation_actions.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/operation_card.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/operation_metrics.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/collaborator_stage_view.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/pause_reason_dialog.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

class FirmwarePage extends StatefulWidget {
  const FirmwarePage({
    super.key,
    this.stage = ProductionStage.firmware,
    this.workStage = WorkStage.firmware,
    this.title = 'Gravacao de Firmware',
    this.operatorName = 'Juliana',
    this.operatorRole = 'Gravacao',
    this.origin = 'SMD',
    this.emptyText = 'Nenhuma OP aguardando firmware.',
    this.queueSubtitle = 'OPs direcionadas para esta etapa.',
    this.runningMetricLabel = 'Em gravacao',
    this.nextStageLabel = 'Soldagem',
    this.startLabel = 'Iniciar gravacao',
    this.resumeLabel = 'Retomar gravacao',
    this.completeLabel = 'Concluir OP',
    this.pauseLabel = 'Pausar OP',
    this.waitingHint = 'Inicie a gravacao para liberar as demais acoes.',
    this.runningHint = 'Gravacao em andamento. Pause ou conclua a OP.',
    this.pausedHint = 'OP pausada. Retome ou conclua a gravacao.',
    this.completedLabel = 'OP concluida e enviada para a proxima etapa.',
    this.completionSnackTarget = 'Soldagem',
    this.collectDefectsOnComplete = true,
    this.stageIcon = Icons.memory_rounded,
    this.accent = AppColors.primary,
  });

  final ProductionStage stage;
  final WorkStage workStage;
  final String title;
  final String operatorName;
  final String operatorRole;
  final String origin;
  final String emptyText;
  final String queueSubtitle;
  final String runningMetricLabel;
  final String nextStageLabel;
  final String startLabel;
  final String resumeLabel;
  final String completeLabel;
  final String pauseLabel;
  final String waitingHint;
  final String runningHint;
  final String pausedHint;
  final String completedLabel;
  final String completionSnackTarget;
  final bool collectDefectsOnComplete;
  final IconData stageIcon;
  final Color accent;

  @override
  State<FirmwarePage> createState() => _FirmwarePageState();
}

class _FirmwarePageState extends State<FirmwarePage> {
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

  List<ProductionOrderFlow> _flowOrders() =>
      context.read<ProductionFlowStore>().ordersAtStage(widget.stage);

  ProductionOrderFlow? _selectedFlowOrder() {
    final orders = _flowOrders();
    if (orders.isEmpty) return null;
    final index = _selectedIndex.clamp(0, orders.length - 1).toInt();
    return orders[index];
  }

  FirmwareOperation _operationFromFlow(ProductionOrderFlow order) {
    final elapsed = order.activeElapsed(DateTime.now());
    return FirmwareOperation(
      number: order.number,
      product: order.productLabel,
      quantity: order.productionQuantityLabel,
      origin: order.previousStageLabel,
      receivedAt: _timeLabel(order.updatedAt),
      receivedAgo: order.timings[widget.stage]?.startedAt == null
          ? 'Aguardando inicio'
          : 'Tempo na etapa: ${formatProductionDuration(elapsed)}',
    );
  }

  FirmwareStatus _statusFromFlow(ProductionRunStatus status) {
    return switch (status) {
      ProductionRunStatus.waiting => FirmwareStatus.waiting,
      ProductionRunStatus.active => FirmwareStatus.recording,
      ProductionRunStatus.paused => FirmwareStatus.paused,
      ProductionRunStatus.completed => FirmwareStatus.completed,
    };
  }

  void _select(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _startRecording() async {
    final order = _selectedFlowOrder();
    if (order == null) return;
    final operator = context.read<OperatorAssignmentStore>().currentOperator;
    await context.read<ProductionFlowStore>().startStage(
      order.number,
      operatorName: operator?.name ?? widget.operatorName,
      operatorPin: operator?.pin,
    );
  }

  Future<void> _pauseOperation() async {
    final order = _selectedFlowOrder();
    if (order == null) return;
    final request = await showPauseReasonDialog(
      context,
      stage: widget.stage,
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

  Future<void> _resetOperation() async {
    final order = _selectedFlowOrder();
    if (order == null) return;
    await context.read<ProductionFlowStore>().resetStage(order.number);
  }

  Future<void> _completeOperation() async {
    final flowOrder = _selectedFlowOrder();
    if (flowOrder == null) return;
    final selectedOperation = _operationFromFlow(flowOrder);
    final defects = widget.collectDefectsOnComplete
        ? await showFirmwareDefectsDialog(
            context,
            maxQuantity: flowOrder.productionQuantity.floor(),
          )
        : const <DefectRecord>[];
    if (!mounted || defects == null) return;

    final signature = await showFirmwarePinDialog(
      context,
      selectedOperation,
      defects: defects,
      currentStage: widget.workStage,
    );
    if (!mounted || signature == null) return;

    await context.read<ProductionFlowStore>().completeStage(
      flowOrder.number,
      operatorName: signature.name,
      operatorPin: signature.pin,
      defects: defects,
    );
    if (!mounted) return;
    setState(() => _selectedIndex = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context
                      .read<ProductionFlowStore>()
                      .orders
                      .firstWhere((o) => o.number == flowOrder.number)
                      .currentStage ==
                  flowOrder.currentStage
              ? '${flowOrder.number}: sua participação foi concluída.'
              : flowOrder.nextStage == ProductionStage.completed
              ? '${flowOrder.number}: sequência concluída no VettiFlow.'
              : '${flowOrder.number} liberada para ${flowOrder.nextStage.label}.',
        ),
      ),
    );
  }

  void _showMobileActions(BuildContext context) {
    final flowOrder = _selectedFlowOrder();
    if (flowOrder == null) return;
    final status = _statusFromFlow(flowOrder.status);
    final op = _operationFromFlow(flowOrder);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MobileActionSheet(
        operation: op,
        status: status,
        startLabel: widget.startLabel,
        resumeLabel: widget.resumeLabel,
        completeLabel: widget.completeLabel,
        pauseLabel: widget.pauseLabel,
        completedLabel: widget.completedLabel,
        onStart: () {
          Navigator.pop(ctx);
          _startRecording();
        },
        onPause: () {
          Navigator.pop(ctx);
          _pauseOperation();
        },
        onComplete: () {
          Navigator.pop(ctx);
          _completeOperation();
        },
        onReset: () {
          Navigator.pop(ctx);
          _resetOperation();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentOperator = context
        .watch<OperatorAssignmentStore>()
        .currentOperator;
    final displayOperatorName = currentOperator?.stage == widget.workStage
        ? currentOperator!.name
        : widget.operatorName;
    final displayOperatorRole = currentOperator?.stage == widget.workStage
        ? currentOperator!.role
        : widget.operatorRole;
    final flowOrders = context.watch<ProductionFlowStore>().ordersAtStage(
      widget.stage,
    );
    if (_selectedIndex >= flowOrders.length && flowOrders.isNotEmpty) {
      _selectedIndex = flowOrders.length - 1;
    }
    final operations = flowOrders.map(_operationFromFlow).toList();
    final statuses = {
      for (var i = 0; i < flowOrders.length; i++)
        i: _statusFromFlow(flowOrders[i].status),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = constraints.maxWidth >= 1180
            ? AppFormFactor.expanded
            : AppBreakpoints.fromWidth(constraints.maxWidth);
        final isMobile = formFactor != AppFormFactor.expanded;

        if (isMobile) {
          if (operations.isEmpty) {
            return _EmptyFirmwareStage(
              compact: true,
              title: widget.title,
              operatorName: displayOperatorName,
              operatorRole: displayOperatorRole,
              emptyText: widget.emptyText,
            );
          }
          return _MobileFirmwareLayout(
            operations: operations,
            selectedIndex: _selectedIndex,
            statuses: statuses,
            title: widget.title,
            operatorName: displayOperatorName,
            onSelect: (i) {
              _select(i);
              _showMobileActions(context);
            },
          );
        }

        if (operations.isEmpty) {
          return _EmptyFirmwareStage(
            title: widget.title,
            operatorName: displayOperatorName,
            operatorRole: displayOperatorRole,
            emptyText: widget.emptyText,
          );
        }
        return _DesktopFirmwareLayout(
          operations: operations,
          selectedIndex: _selectedIndex,
          statuses: statuses,
          title: widget.title,
          operatorName: displayOperatorName,
          operatorRole: displayOperatorRole,
          queueSubtitle: widget.queueSubtitle,
          runningMetricLabel: widget.runningMetricLabel,
          nextStageLabel: flowOrders[_selectedIndex].nextStageLabel,
          startLabel: widget.startLabel,
          resumeLabel: widget.resumeLabel,
          completeLabel: widget.completeLabel,
          pauseLabel: widget.pauseLabel,
          waitingHint: widget.waitingHint,
          runningHint: widget.runningHint,
          pausedHint: widget.pausedHint,
          completedLabel: widget.completedLabel,
          stageIcon: widget.stageIcon,
          accent: widget.accent,
          onSelect: _select,
          onStart: _startRecording,
          onPause: _pauseOperation,
          onComplete: _completeOperation,
          onReset: _resetOperation,
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Mobile action sheet (flutuante ao clicar no card)
// ────────────────────────────────────────────────────────────────────

class _MobileActionSheet extends StatelessWidget {
  const _MobileActionSheet({
    required this.operation,
    required this.status,
    required this.startLabel,
    required this.resumeLabel,
    required this.completeLabel,
    required this.pauseLabel,
    required this.completedLabel,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
    required this.onReset,
  });

  final FirmwareOperation operation;
  final FirmwareStatus status;
  final String startLabel;
  final String resumeLabel;
  final String completeLabel;
  final String pauseLabel;
  final String completedLabel;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              OperationStatusChip(status: status, compact: true),
            ],
          ),
          const SizedBox(height: 16),
          OperationMetrics(operation: operation, compact: true),
          const SizedBox(height: 20),
          OperationActions(
            status: status,
            compact: true,
            startLabel: startLabel,
            resumeLabel: resumeLabel,
            completeLabel: completeLabel,
            pauseLabel: pauseLabel,
            completedLabel: completedLabel,
            onStart: onStart,
            onPause: onPause,
            onComplete: onComplete,
            onReset: onReset,
          ),
        ],
      ),
    );
  }
}

class _EmptyFirmwareStage extends StatelessWidget {
  const _EmptyFirmwareStage({
    this.compact = false,
    required this.title,
    required this.operatorName,
    required this.operatorRole,
    required this.emptyText,
  });

  final bool compact;
  final String title;
  final String operatorName;
  final String operatorRole;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (compact) {
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
                    title: title,
                    operatorName: operatorName,
                    compact: true,
                  ),
                  Expanded(
                    child: Center(child: _EmptyStageMessage(text: emptyText)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          VettiTopBar(
            title: title,
            operatorName: operatorName,
            operatorRole: operatorRole,
          ),
          Expanded(
            child: Center(child: _EmptyStageMessage(text: emptyText)),
          ),
        ],
      ),
    );
  }
}

class _EmptyStageMessage extends StatelessWidget {
  const _EmptyStageMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

String _timeLabel(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

// ────────────────────────────────────────────────────────────────────
// Mobile layout — so lista de cards, tap abre o sheet
// ────────────────────────────────────────────────────────────────────

class _MobileFirmwareLayout extends StatelessWidget {
  const _MobileFirmwareLayout({
    required this.operations,
    required this.selectedIndex,
    required this.statuses,
    required this.title,
    required this.operatorName,
    required this.onSelect,
  });

  final List<FirmwareOperation> operations;
  final int selectedIndex;
  final Map<int, FirmwareStatus> statuses;
  final String title;
  final String operatorName;
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
                  title: title,
                  operatorName: operatorName,
                  compact: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OPs disponiveis',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Toque na OP para ver detalhes e acoes.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (var i = 0; i < operations.length; i++) ...[
                          OperationCard(
                            operation: operations[i],
                            selected: i == selectedIndex,
                            status: statuses[i] ?? FirmwareStatus.waiting,
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

// ────────────────────────────────────────────────────────────────────
// Desktop layout — lista esquerda + detalhe completo a direita
// ────────────────────────────────────────────────────────────────────

class _DesktopFirmwareLayout extends StatelessWidget {
  const _DesktopFirmwareLayout({
    required this.operations,
    required this.selectedIndex,
    required this.statuses,
    required this.title,
    required this.operatorName,
    required this.operatorRole,
    required this.queueSubtitle,
    required this.runningMetricLabel,
    required this.nextStageLabel,
    required this.startLabel,
    required this.resumeLabel,
    required this.completeLabel,
    required this.pauseLabel,
    required this.waitingHint,
    required this.runningHint,
    required this.pausedHint,
    required this.completedLabel,
    required this.stageIcon,
    required this.accent,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
    required this.onReset,
  });

  final List<FirmwareOperation> operations;
  final int selectedIndex;
  final Map<int, FirmwareStatus> statuses;
  final String title;
  final String operatorName;
  final String operatorRole;
  final String queueSubtitle;
  final String runningMetricLabel;
  final String nextStageLabel;
  final String startLabel;
  final String resumeLabel;
  final String completeLabel;
  final String pauseLabel;
  final String waitingHint;
  final String runningHint;
  final String pausedHint;
  final String completedLabel;
  final IconData stageIcon;
  final Color accent;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;
  final VoidCallback onReset;

  FirmwareOperation get selectedOperation => operations[selectedIndex];
  FirmwareStatus get status =>
      statuses[selectedIndex] ?? FirmwareStatus.waiting;
  List<CollaboratorStageMetric> get metrics {
    final recording = statuses.values
        .where((status) => status == FirmwareStatus.recording)
        .length;
    final paused = statuses.values
        .where((status) => status == FirmwareStatus.paused)
        .length;

    return [
      CollaboratorStageMetric(
        label: 'OPs na etapa',
        value: '${operations.length}',
        icon: stageIcon,
        accent: accent,
      ),
      CollaboratorStageMetric(
        label: runningMetricLabel,
        value: '$recording',
        icon: Icons.play_circle_rounded,
        accent: AppColors.green,
      ),
      CollaboratorStageMetric(
        label: 'Pausadas',
        value: '$paused',
        icon: Icons.pause_circle_rounded,
        accent: AppColors.orange,
      ),
      CollaboratorStageMetric(
        label: 'Proxima etapa',
        value: nextStageLabel,
        icon: Icons.precision_manufacturing,
        accent: const Color(0xFF7458D8),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          VettiTopBar(
            title: title,
            operatorName: operatorName,
            operatorRole: operatorRole,
          ),
          Expanded(
            child: CollaboratorStageBody(
              child: CollaboratorStageContent(
                metrics: metrics,
                queue: CollaboratorPanel(
                  padding: const EdgeInsets.all(20),
                  accent: accent,
                  child: _DesktopOperationsPanel(
                    operations: operations,
                    selectedIndex: selectedIndex,
                    statuses: statuses,
                    queueSubtitle: queueSubtitle,
                    stageIcon: stageIcon,
                    onSelect: onSelect,
                  ),
                ),
                detail: CollaboratorPanel(
                  padding: const EdgeInsets.all(28),
                  accent: status.color,
                  child: _DesktopDetailPanel(
                    operation: selectedOperation,
                    status: status,
                    startLabel: startLabel,
                    resumeLabel: resumeLabel,
                    completeLabel: completeLabel,
                    pauseLabel: pauseLabel,
                    waitingHint: waitingHint,
                    runningHint: runningHint,
                    pausedHint: pausedHint,
                    completedLabel: completedLabel,
                    onStart: onStart,
                    onPause: onPause,
                    onComplete: onComplete,
                    onReset: onReset,
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

class _DesktopOperationsPanel extends StatelessWidget {
  const _DesktopOperationsPanel({
    required this.operations,
    required this.selectedIndex,
    required this.statuses,
    required this.queueSubtitle,
    required this.stageIcon,
    required this.onSelect,
  });

  final List<FirmwareOperation> operations;
  final int selectedIndex;
  final Map<int, FirmwareStatus> statuses;
  final String queueSubtitle;
  final IconData stageIcon;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollaboratorQueueHeading(
          icon: stageIcon,
          title: 'OPs disponiveis',
          subtitle: queueSubtitle,
          count: '${operations.length}',
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < operations.length; i++) ...[
          OperationCard(
            operation: operations[i],
            selected: i == selectedIndex,
            status: statuses[i] ?? FirmwareStatus.waiting,
            onTap: () => onSelect(i),
          ),
          if (i < operations.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DesktopDetailPanel extends StatelessWidget {
  const _DesktopDetailPanel({
    required this.operation,
    required this.status,
    required this.startLabel,
    required this.resumeLabel,
    required this.completeLabel,
    required this.pauseLabel,
    required this.waitingHint,
    required this.runningHint,
    required this.pausedHint,
    required this.completedLabel,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
    required this.onReset,
  });

  final FirmwareOperation operation;
  final FirmwareStatus status;
  final String startLabel;
  final String resumeLabel;
  final String completeLabel;
  final String pauseLabel;
  final String waitingHint;
  final String runningHint;
  final String pausedHint;
  final String completedLabel;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            OperationStatusChip(status: status),
          ],
        ),
        const SizedBox(height: 24),
        OperationMetrics(operation: operation),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          height: 1,
          color: const Color(0xFFEEF3F7),
        ),
        const SizedBox(height: 28),
        const Text(
          'Acoes da OP',
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
        OperationActions(
          status: status,
          startLabel: startLabel,
          resumeLabel: resumeLabel,
          completeLabel: completeLabel,
          pauseLabel: pauseLabel,
          completedLabel: completedLabel,
          onStart: onStart,
          onPause: onPause,
          onComplete: onComplete,
          onReset: onReset,
        ),
      ],
    );
  }

  String _actionHint(FirmwareStatus status) {
    return switch (status) {
      FirmwareStatus.waiting => waitingHint,
      FirmwareStatus.recording => runningHint,
      FirmwareStatus.paused => pausedHint,
      FirmwareStatus.completed => 'OP finalizada nesta etapa.',
    };
  }
}
