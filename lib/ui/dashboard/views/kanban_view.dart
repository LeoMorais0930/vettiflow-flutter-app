import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/op_card.dart';

/// Cor de destaque por etapa (espelha o acento usado na TV).
Color stageAccent(ProductionStage stage) {
  return switch (stage) {
    ProductionStage.warehouse => const Color(0xFF0077BD),
    ProductionStage.smd => const Color(0xFF0E9C8A),
    ProductionStage.firmware => const Color(0xFF6D5BD0),
    ProductionStage.soldering => const Color(0xFFD97706),
    ProductionStage.testing => const Color(0xFF0E9C8A),
    ProductionStage.closing => const Color(0xFFC2410C),
    ProductionStage.expedition => const Color(0xFF209F58),
    ProductionStage.storage || ProductionStage.completed => AppColors.muted,
  };
}

class KanbanView extends StatefulWidget {
  final List<OrdemProducao> ordens;
  final ValueChanged<String> onOpenOP;

  const KanbanView({super.key, required this.ordens, required this.onOpenOP});

  @override
  State<KanbanView> createState() => _KanbanViewState();
}

class _KanbanViewState extends State<KanbanView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const flow = ProductionStage.productionFlow;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 14.0;
        const minColumnWidth = 170.0;
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : flow.length * minColumnWidth;
        final totalGap = gap * (flow.length - 1);
        final contentWidth = available.clamp(
          flow.length * minColumnWidth + totalGap,
          double.infinity,
        );
        final columnWidth = (contentWidth - totalGap) / flow.length;

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: contentWidth > available,
            trackVisibility: contentWidth > available,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.only(bottom: 14),
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < flow.length; i++) ...[
                      SizedBox(
                        width: columnWidth,
                        child: _KanbanColumn(
                          stage: flow[i],
                          items: widget.ordens
                              .where((op) => op.stage == flow[i])
                              .toList(),
                          onOpenOP: widget.onOpenOP,
                        ),
                      ),
                      if (i < flow.length - 1) const SizedBox(width: gap),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final ProductionStage stage;
  final List<OrdemProducao> items;
  final ValueChanged<String> onOpenOP;

  const _KanbanColumn({
    required this.stage,
    required this.items,
    required this.onOpenOP,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 600),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: stageAccent(stage),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stage.label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgHeader,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${items.length}',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Nenhuma OP',
                style: TextStyle(fontSize: 12, color: AppColors.textWeak),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(10),
                itemCount: items.length,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (_, i) => OpCard(
                  op: items[i],
                  accentColor: stageAccent(stage),
                  onTap: () => onOpenOP(items[i].numero),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
