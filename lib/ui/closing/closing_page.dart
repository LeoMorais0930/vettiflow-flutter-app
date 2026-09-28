import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/layout/app_breakpoints.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/collaborator_stage_view.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/pause_reason_dialog.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

class ClosingOperation {
  const ClosingOperation({
    required this.number,
    required this.product,
    required this.quantity,
    required this.origin,
    required this.receivedAt,
    required this.receivedAgo,
    required this.status,
    this.nextStageLabel = 'Expedicao',
  });

  final String nextStageLabel;
  final String number;
  final String product;
  final String quantity;
  final String origin;
  final String receivedAt;
  final String receivedAgo;
  final ProductionRunStatus status;
}

class ClosingSignature {
  const ClosingSignature({required this.operator, required this.observation});

  final Operator operator;
  final String observation;
}

class ClosingPage extends StatefulWidget {
  const ClosingPage({super.key});

  @override
  State<ClosingPage> createState() => _ClosingPageState();
}

class _ClosingPageState extends State<ClosingPage> {
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
      .ordersAtStage(ProductionStage.closing);

  ProductionOrderFlow? _selectedFlowOrder() {
    final orders = _flowOrders();
    if (orders.isEmpty) return null;
    final index = _selectedIndex.clamp(0, orders.length - 1).toInt();
    return orders[index];
  }

  ClosingOperation _operationFromFlow(ProductionOrderFlow order) {
    final elapsed = order.activeElapsed(DateTime.now());
    return ClosingOperation(
      number: order.number,
      product: order.productLabel,
      quantity: order.productionQuantityLabel,
      origin: order.previousStageLabel,
      nextStageLabel: order.nextStageLabel,
      receivedAt: _clockLabel(order.updatedAt),
      receivedAgo: order.timings[ProductionStage.closing]?.startedAt == null
          ? 'Aguardando fechamento'
          : 'Tempo na etapa: ${formatProductionDuration(elapsed)}',
      status: order.status,
    );
  }

  void _select(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _startOperation() async {
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
      stage: ProductionStage.closing,
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

  Future<void> _advanceOperation() async {
    final flowOrder = _selectedFlowOrder();
    if (flowOrder == null) return;
    final operation = _operationFromFlow(flowOrder);
    final signature = await showClosingSignatureDialog(context, operation);
    if (!mounted || signature == null) return;

    await context.read<ProductionFlowStore>().completeStage(
      flowOrder.number,
      observation: signature.observation,
      operatorName: signature.operator.name,
      operatorPin: signature.operator.pin,
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
              ? '${operation.number}: sua participação foi concluída.'
              : flowOrder.nextStage == ProductionStage.completed
              ? '${operation.number}: sequência concluída no VettiFlow.'
              : '${operation.number} liberada para ${flowOrder.nextStage.label}.',
        ),
      ),
    );
  }

  void _showMobileActions(BuildContext context) {
    final flowOrder = _selectedFlowOrder();
    if (flowOrder == null) return;
    final operation = _operationFromFlow(flowOrder);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MobileClosingActionSheet(
        operation: operation,
        onStart: () {
          Navigator.pop(ctx);
          _startOperation();
        },
        onPause: () {
          Navigator.pop(ctx);
          _pauseOperation();
        },
        onAdvance: () {
          Navigator.pop(ctx);
          _advanceOperation();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flowOrders = context.watch<ProductionFlowStore>().ordersAtStage(
      ProductionStage.closing,
    );
    if (_selectedIndex >= flowOrders.length) {
      _selectedIndex = flowOrders.isEmpty ? 0 : flowOrders.length - 1;
    }
    final operations = flowOrders.map(_operationFromFlow).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = AppBreakpoints.fromWidth(constraints.maxWidth);
        final isMobile = formFactor != AppFormFactor.expanded;

        if (operations.isEmpty) return _EmptyClosingStage(compact: isMobile);

        if (isMobile) {
          return _MobileClosingLayout(
            operations: operations,
            selectedIndex: _selectedIndex,
            onSelect: (index) {
              _select(index);
              _showMobileActions(context);
            },
          );
        }

        return _DesktopClosingLayout(
          operations: operations,
          selectedIndex: _selectedIndex,
          onSelect: _select,
          onStart: _startOperation,
          onPause: _pauseOperation,
          onAdvance: _advanceOperation,
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

class _EmptyClosingStage extends StatelessWidget {
  const _EmptyClosingStage({required this.compact});

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
                  title: 'Fechamento',
                  operatorName:
                      context
                          .watch<OperatorAssignmentStore>()
                          .currentOperator
                          ?.name ??
                      'Operador',
                  operatorRole: 'Fechamento',
                ),
                const Expanded(
                  child: _EmptyStageMessage(
                    icon: Icons.inventory_2_rounded,
                    title: 'Nenhuma OP em fechamento',
                    text:
                        'As OPs aparecem aqui assim que o teste for concluido.',
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

class _MobileClosingLayout extends StatelessWidget {
  const _MobileClosingLayout({
    required this.operations,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<ClosingOperation> operations;
  final int selectedIndex;
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
                  title: 'Fechamento',
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
                          'OPs para fechamento',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Toque na OP para conferir e avancar.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (var i = 0; i < operations.length; i++) ...[
                          _ClosingCard(
                            operation: operations[i],
                            selected: i == selectedIndex,
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

class _DesktopClosingLayout extends StatelessWidget {
  const _DesktopClosingLayout({
    required this.operations,
    required this.selectedIndex,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onAdvance,
  });

  final List<ClosingOperation> operations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onAdvance;

  ClosingOperation get selectedOperation => operations[selectedIndex];
  List<CollaboratorStageMetric> get metrics => [
    CollaboratorStageMetric(
      label: 'OPs na etapa',
      value: '${operations.length}',
      icon: Icons.inventory_2_rounded,
      accent: AppColors.primary,
    ),
    CollaboratorStageMetric(
      label: 'Prontas para fechar',
      value: '${operations.length}',
      icon: Icons.fact_check_rounded,
      accent: AppColors.green,
    ),
    const CollaboratorStageMetric(
      label: 'Acao exigida',
      value: 'PIN',
      icon: Icons.password_rounded,
      accent: AppColors.orange,
    ),
    CollaboratorStageMetric(
      label: 'Proxima etapa',
      value: selectedOperation.nextStageLabel,
      icon: Icons.local_shipping_rounded,
      accent: Color(0xFF7458D8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          VettiTopBar(
            title: 'Fechamento',
            operatorName:
                context
                    .watch<OperatorAssignmentStore>()
                    .currentOperator
                    ?.name ??
                'Operador',
            operatorRole: 'Fechamento',
          ),
          Expanded(
            child: CollaboratorStageBody(
              child: CollaboratorStageContent(
                metrics: metrics,
                queue: CollaboratorPanel(
                  padding: const EdgeInsets.all(20),
                  accent: AppColors.primary,
                  child: _DesktopClosingQueue(
                    operations: operations,
                    selectedIndex: selectedIndex,
                    onSelect: onSelect,
                  ),
                ),
                detail: CollaboratorPanel(
                  padding: const EdgeInsets.all(28),
                  accent: AppColors.green,
                  child: _DesktopClosingDetail(
                    operation: selectedOperation,
                    onStart: onStart,
                    onPause: onPause,
                    onAdvance: onAdvance,
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

class _DesktopClosingQueue extends StatelessWidget {
  const _DesktopClosingQueue({
    required this.operations,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<ClosingOperation> operations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CollaboratorQueueHeading(
          icon: Icons.inventory_2_rounded,
          title: 'OPs para fechamento',
          subtitle: 'OPs direcionadas para esta etapa.',
          count: '${operations.length}',
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < operations.length; i++) ...[
          _ClosingCard(
            operation: operations[i],
            selected: i == selectedIndex,
            onTap: () => onSelect(i),
          ),
          if (i < operations.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DesktopClosingDetail extends StatelessWidget {
  const _DesktopClosingDetail({
    required this.operation,
    required this.onStart,
    required this.onPause,
    required this.onAdvance,
  });

  final ClosingOperation operation;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _OperationTitle(operation: operation)),
            const SizedBox(width: 14),
            _ClosingStatusChip(status: operation.status),
          ],
        ),
        const SizedBox(height: 24),
        _ClosingMetrics(operation: operation),
        const SizedBox(height: 28),
        const CollaboratorDivider(),
        const SizedBox(height: 24),
        const Text(
          'Acoes da OP',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Confira a OP, assine com PIN e registre uma observacao se necessario.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        _ClosingActions(
          status: operation.status,
          onStart: onStart,
          onPause: onPause,
          onAdvance: onAdvance,
        ),
      ],
    );
  }
}

class _MobileClosingActionSheet extends StatelessWidget {
  const _MobileClosingActionSheet({
    required this.operation,
    required this.onStart,
    required this.onPause,
    required this.onAdvance,
  });

  final ClosingOperation operation;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onAdvance;

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
          const _SheetHandle(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OperationTitle(operation: operation, compact: true),
              ),
              const SizedBox(width: 10),
              _ClosingStatusChip(status: operation.status, compact: true),
            ],
          ),
          const SizedBox(height: 16),
          _ClosingMetrics(operation: operation, compact: true),
          const SizedBox(height: 18),
          _ClosingActions(
            status: operation.status,
            onStart: onStart,
            onPause: onPause,
            onAdvance: onAdvance,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _ClosingCard extends StatelessWidget {
  const _ClosingCard({
    required this.operation,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final ClosingOperation operation;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF7FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE4EDF4),
              width: selected ? 1.6 : 1,
            ),
          ),
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
                        fontSize: compact ? 16 : 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ClosingStatusChip(status: operation.status, compact: true),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                operation.product,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                operation.receivedAgo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationTitle extends StatelessWidget {
  const _OperationTitle({required this.operation, this.compact = false});

  final ClosingOperation operation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          operation.number,
          style: TextStyle(
            color: AppColors.text,
            fontSize: compact ? 18 : 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          operation.product,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: compact ? 13 : 17,
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
    );
  }
}

class _ClosingMetrics extends StatelessWidget {
  const _ClosingMetrics({required this.operation, this.compact = false});

  final ClosingOperation operation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Qtd', operation.quantity),
      ('Origem', operation.origin),
      ('Recebida', operation.receivedAt),
    ];

    return Container(
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

class _ClosingStatusChip extends StatelessWidget {
  const _ClosingStatusChip({required this.status, this.compact = false});

  final ProductionRunStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ProductionRunStatus.waiting => 'Aguardando',
      ProductionRunStatus.active => 'Em fechamento',
      ProductionRunStatus.paused => 'Pausada',
      ProductionRunStatus.completed => 'Concluida',
    };
    final color = switch (status) {
      ProductionRunStatus.waiting => AppColors.muted,
      ProductionRunStatus.active => AppColors.primary,
      ProductionRunStatus.paused => AppColors.orangeText,
      ProductionRunStatus.completed => AppColors.green,
    };
    final surface = switch (status) {
      ProductionRunStatus.waiting => const Color(0xFFEFF3F7),
      ProductionRunStatus.active => const Color(0xFFE7F4FB),
      ProductionRunStatus.paused => const Color(0xFFFBF1E2),
      ProductionRunStatus.completed => const Color(0xFFE7F6EC),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ClosingActions extends StatelessWidget {
  const _ClosingActions({
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onAdvance,
    this.compact = false,
  });

  final ProductionRunStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onAdvance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (status == ProductionRunStatus.waiting) {
      return _ActionButton(
        label: 'Iniciar fechamento',
        icon: Icons.play_arrow_rounded,
        onPressed: onStart,
        fillColor: AppColors.primary,
        foregroundColor: Colors.white,
        width: compact ? double.infinity : 240,
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ActionButton(
          label: status == ProductionRunStatus.paused ? 'Retomar' : 'Pausar',
          icon: status == ProductionRunStatus.paused
              ? Icons.play_arrow_rounded
              : Icons.pause_rounded,
          onPressed: status == ProductionRunStatus.paused ? onStart : onPause,
          fillColor: Colors.white,
          foregroundColor: AppColors.primary,
          width: compact ? double.infinity : 180,
        ),
        _ActionButton(
          label: 'Concluir etapa',
          icon: Icons.local_shipping_rounded,
          onPressed: onAdvance,
          fillColor: AppColors.green,
          foregroundColor: Colors.white,
          width: compact ? double.infinity : 260,
        ),
      ],
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
    this.icon,
    this.fillColor,
    this.width,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color? fillColor;
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
          side: BorderSide(color: fillColor ?? Colors.white, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
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
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFCBD7E1),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

Future<ClosingSignature?> showClosingSignatureDialog(
  BuildContext context,
  ClosingOperation operation,
) {
  final compact = MediaQuery.sizeOf(context).width < 720;

  if (compact) {
    return showModalBottomSheet<ClosingSignature>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _ClosingSignatureSheet(operation: operation, compact: true),
    );
  }

  return showDialog<ClosingSignature>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      backgroundColor: Colors.transparent,
      child: _ClosingSignatureSheet(operation: operation),
    ),
  );
}

class _ClosingSignatureSheet extends StatefulWidget {
  const _ClosingSignatureSheet({required this.operation, this.compact = false});

  final ClosingOperation operation;
  final bool compact;

  @override
  State<_ClosingSignatureSheet> createState() => _ClosingSignatureSheetState();
}

class _ClosingSignatureSheetState extends State<_ClosingSignatureSheet> {
  final _pinController = TextEditingController();
  final _observationController = TextEditingController();
  Operator? _operator;
  bool _invalidPin = false;
  bool _wrongStage = false;

  @override
  void dispose() {
    _pinController.dispose();
    _observationController.dispose();
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
      _wrongStage = operator != null && operator.stage != WorkStage.closing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final valid = _operator != null && !_wrongStage;

    return _ModalSurface(
      compact: widget.compact,
      maxWidth: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.compact) const _SheetHandle(),
          const Text(
            'Assinatura do fechamento',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Digite o PIN para concluir esta etapa da ${widget.operation.number}.',
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
          const SizedBox(height: 14),
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
                  'Voce esta na etapa "Fechamento".',
            ),
          const SizedBox(height: 18),
          const Text(
            'Observacao (opcional)',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _observationController,
            minLines: 3,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Ex.: embalagem conferida, etiqueta aplicada...',
              filled: true,
              fillColor: const Color(0xFFF8FBFD),
              border: _pinBorder(AppColors.border),
              enabledBorder: _pinBorder(AppColors.border),
              focusedBorder: _pinBorder(AppColors.primary, width: 1.5),
            ),
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
                  label: 'Avancar OP',
                  onPressed: valid
                      ? () => Navigator.of(context).pop(
                          ClosingSignature(
                            operator: _operator!,
                            observation: _observationController.text,
                          ),
                        )
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
