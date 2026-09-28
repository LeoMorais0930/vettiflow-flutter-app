import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';

/// Aba "Relatórios" do painel de produção.
///
/// Lê diretamente o [ProductionFlowStore] — a fonte mais rica de dados, com
/// carimbos de tempo por etapa, quantidades fechadas/armazenadas e datas de
/// criação/finalização de cada OP. Todos os indicadores são derivados desse
/// histórico, então a tela reflete o fluxo real de produção em tempo real.
class ReportsView extends StatelessWidget {
  const ReportsView({super.key, this.visibleArea});

  final WorkArea? visibleArea;

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<ProductionFlowStore>().orders;
    final operator = context.watch<OperatorAssignmentStore?>()?.currentOperator;
    final generalManagement =
        operator?.canManageAssignments == true && operator?.managesArea == null;
    final sectors = generalManagement
        ? ReportSector.values
        : switch (visibleArea) {
            WorkArea.warehouse => [ReportSector.warehouse],
            WorkArea.smd => [ReportSector.smd],
            WorkArea.support => [ReportSector.support],
            WorkArea.production => [
              ReportSector.production,
              ReportSector.expedition,
            ],
            _ => <ReportSector>[],
          };
    final report = ProductionReport(
      orders,
      DateTime.now(),
      visibleArea: visibleArea,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sectors.isNotEmpty) ...[
          const Text(
            'Relatórios do Protheus',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sector in sectors)
                OutlinedButton.icon(
                  icon: const Icon(Icons.summarize_outlined, size: 18),
                  label: Text(
                    sector == ReportSector.management
                        ? 'Consolidado geral'
                        : sector.label,
                  ),
                  onPressed: () =>
                      Navigator.of(context).pushNamed(sector.route),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        const Text(
          'VettiFlow · dados locais deste dispositivo',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 10),
        _ReportsHeader(report: report),
        const SizedBox(height: 18),
        if (report.orders.isEmpty)
          const _EmptyReports()
        else ...[
          _SummaryGrid(report: report),
          const SizedBox(height: 18),
          _DefectTypePanel(report: report),
          const SizedBox(height: 18),
          _StageTimingPanel(report: report),
          const SizedBox(height: 18),
          _PauseEventsPanel(report: report),
          const SizedBox(height: 18),
          _OperatorWorkPanel(report: report),
          const SizedBox(height: 18),
          _ProductBreakdownPanel(report: report),
          const SizedBox(height: 18),
          _OrdersDetailPanel(report: report),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Modelo de cálculo dos relatórios
// ---------------------------------------------------------------------------

/// Estatísticas de uma única etapa de produção agregadas por todas as OPs.
class StageStats {
  StageStats(this.stage);

  final ProductionStage stage;
  Duration total = Duration.zero;
  int samples = 0;

  void add(Duration d) {
    total += d;
    samples++;
  }

  Duration get average => samples == 0
      ? Duration.zero
      : Duration(microseconds: total.inMicroseconds ~/ samples);
}

/// Estatísticas agregadas por produto.
class ProductStats {
  ProductStats(this.code, this.name);

  final String code;
  final String name;
  int orders = 0;
  int producedUnits = 0;
  int defectUnits = 0;
  int inspectedUnits = 0;

  String get label => code.isEmpty ? name : '$code · $name';

  double get defectRate =>
      inspectedUnits == 0 ? 0 : defectUnits / inspectedUnits;
}

/// Estatísticas de um tipo de defeito (T1..T8) agregadas por todas as OPs.
class DefectTypeStats {
  DefectTypeStats(this.code, this.title);

  final String code;
  final String title;
  int quantity = 0;
  int occurrences = 0;

  void add(int q) {
    quantity += q;
    occurrences++;
  }
}

class PauseEventRow {
  const PauseEventRow(this.order, this.event);

  final ProductionOrderFlow order;
  final ProductionPauseEvent event;
}

class OperatorWorkRow {
  const OperatorWorkRow(this.order, this.session);

  final ProductionOrderFlow order;
  final ProductionOperatorSession session;
}

/// Consolida todos os cálculos de relatório a partir das OPs do store.
class ProductionReport {
  ProductionReport(
    List<ProductionOrderFlow> sourceOrders,
    this.now, {
    this.visibleArea,
  }) : orders = sourceOrders.where((order) {
         if (visibleArea == null) return true;
         return _orderTouchesArea(order, visibleArea);
       }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)) {
    _compute();
  }

  final List<ProductionOrderFlow> orders;
  final DateTime now;
  final WorkArea? visibleArea;

  int totalOrders = 0;
  int finishedOrders = 0;
  int inProductionOrders = 0;
  int storedOrders = 0;

  int producedUnits = 0;
  int defectUnits = 0;
  int inspectedUnits = 0;

  Duration _finishedDurationTotal = Duration.zero;
  int _finishedDurationSamples = 0;

  final Map<ProductionStage, StageStats> stageStats = {
    for (final stage in ProductionStage.productionFlow)
      stage: StageStats(stage),
  };

  final Map<String, ProductStats> _productStats = {};
  final Map<String, DefectTypeStats> _defectTypes = {};

  List<ProductStats> get productStats {
    final list = _productStats.values.toList()
      ..sort((a, b) => b.orders.compareTo(a.orders));
    return list;
  }

  List<DefectTypeStats> get defectTypes {
    final list = _defectTypes.values.toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    return list;
  }

  List<PauseEventRow> get pauseEvents {
    final rows =
        [
            for (final order in orders)
              for (final event in order.pauseEvents)
                PauseEventRow(order, event),
          ].where((row) {
            final area = visibleArea;
            return area == null || _areaForStage(row.event.stage) == area;
          }).toList()
          ..sort((a, b) => b.event.createdAt.compareTo(a.event.createdAt));
    return rows;
  }

  List<OperatorWorkRow> get operatorWorkRows {
    final rows =
        [
            for (final order in orders)
              for (final session in order.operatorSessions)
                OperatorWorkRow(order, session),
          ].where((row) {
            final area = visibleArea;
            return area == null || _areaForStage(row.session.stage) == area;
          }).toList()
          ..sort((a, b) => b.session.startedAt.compareTo(a.session.startedAt));
    return rows;
  }

  List<ProductionStage> get visibleStages {
    final area = visibleArea;
    if (area == null) return ProductionStage.productionFlow;
    return ProductionStage.productionFlow
        .where((stage) => _areaForStage(stage) == area)
        .toList();
  }

  String get averageDurationLabel =>
      visibleArea == null ? 'Tempo médio de produção' : 'Tempo médio no setor';

  Duration get averageProductionDuration => _finishedDurationSamples == 0
      ? Duration.zero
      : Duration(
          microseconds:
              _finishedDurationTotal.inMicroseconds ~/ _finishedDurationSamples,
        );

  double get defectRate =>
      inspectedUnits == 0 ? 0 : defectUnits / inspectedUnits;

  void _compute() {
    totalOrders = orders.length;
    for (final order in orders) {
      if (order.totalStoredQuantity > 0) storedOrders++;
      if (order.isDone) {
        finishedOrders++;
        final finished = finishedAt(order);
        if (finished != null || visibleArea != null) {
          final elapsed = visibleArea == null
              ? order.totalElapsed(now)
              : visibleElapsed(order);
          if (elapsed != Duration.zero) {
            _finishedDurationTotal += elapsed;
            _finishedDurationSamples++;
          }
        }
      } else {
        inProductionOrders++;
      }

      // Tempo por etapa (apenas etapas concluídas contam para a média).
      for (final stage in visibleStages) {
        final timing = order.timings[stage];
        if (timing?.startedAt != null && timing?.completedAt != null) {
          stageStats[stage]!.add(timing!.elapsed(now));
        }
      }

      final product = _productStats.putIfAbsent(
        order.productCode,
        () => ProductStats(order.productCode, order.productName),
      );
      product.orders++;

      // Produção aprovada — conhecida após o fechamento.
      if (order.timings[ProductionStage.closing]?.completedAt != null) {
        producedUnits += order.closedQuantity;
        product.producedUnits += order.closedQuantity;
      }

      // Defeitos — registrados e conhecidos após o teste.
      final defects = defectsOf(order);
      if (defects != null) {
        defectUnits += defects;
        inspectedUnits += order.quantity;
        product.defectUnits += defects;
        product.inspectedUnits += order.quantity;
        for (final defect in order.testDefects) {
          _defectTypes
              .putIfAbsent(
                defect.code,
                () => DefectTypeStats(defect.code, defect.title),
              )
              .add(defect.quantity);
        }
      }
    }
  }

  /// Momento em que a OP foi finalizada (expedição concluída), ou `null`.
  DateTime? finishedAt(ProductionOrderFlow order) {
    if (!order.isDone) return null;
    return order.timings[ProductionStage.expedition]?.completedAt ??
        order.updatedAt;
  }

  /// Total de dispositivos marcados como defeito no teste. `null` enquanto o
  /// teste da OP não foi concluído (defeito ainda desconhecido).
  int? defectsOf(ProductionOrderFlow order) {
    final tested = order.timings[ProductionStage.testing]?.completedAt;
    if (tested == null) return null;
    return order.totalDefects;
  }

  Duration visibleElapsed(ProductionOrderFlow order) {
    return visibleStages.fold<Duration>(
      Duration.zero,
      (total, stage) =>
          total + (order.timings[stage]?.elapsed(now) ?? Duration.zero),
    );
  }
}

// ---------------------------------------------------------------------------
// Cabeçalho
// ---------------------------------------------------------------------------

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({required this.report});

  final ProductionReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.bgAndamento,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Relatórios de Produção',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${report.totalOrders} OP${report.totalOrders == 1 ? '' : 's'} · '
                  'atualizado ${DateFormat('dd/MM HH:mm').format(report.now)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
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

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Nenhuma OP registrada ainda.\nOs relatórios aparecem conforme a produção avança.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resumo (KPIs)
// ---------------------------------------------------------------------------

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.report});

  final ProductionReport report;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _StatCard(
        icon: Icons.receipt_long_rounded,
        label: 'Total de OPs',
        value: '${report.totalOrders}',
        color: AppColors.primary,
      ),
      _StatCard(
        icon: Icons.check_circle_rounded,
        label: 'Finalizadas',
        value: '${report.finishedOrders}',
        sub:
            '${report.storedOrders} armazenada${report.storedOrders == 1 ? '' : 's'}',
        color: AppColors.green,
      ),
      _StatCard(
        icon: Icons.autorenew_rounded,
        label: 'Em produção',
        value: '${report.inProductionOrders}',
        color: AppColors.orange,
      ),
      _StatCard(
        icon: Icons.timer_outlined,
        label: report.averageDurationLabel,
        value: report.averageProductionDuration == Duration.zero
            ? '—'
            : formatProductionDuration(report.averageProductionDuration),
        sub: 'por OP finalizada',
        color: AppColors.primary,
      ),
      _StatCard(
        icon: Icons.inventory_2_outlined,
        label: 'Dispositivos produzidos',
        value: NumberFormat.decimalPattern(
          'pt_BR',
        ).format(report.producedUnits),
        sub: 'aprovados no fechamento',
        color: AppColors.green,
      ),
      _StatCard(
        icon: Icons.report_gmailerrorred_rounded,
        label: 'Defeitos',
        value: NumberFormat.decimalPattern('pt_BR').format(report.defectUnits),
        sub: report.inspectedUnits == 0
            ? 'sem dados'
            : 'taxa ${(report.defectRate * 100).toStringAsFixed(1)}%',
        color: AppColors.danger,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 13.0;
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sub,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textWeak,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Defeitos por tipo
// ---------------------------------------------------------------------------

class _DefectTypePanel extends StatelessWidget {
  const _DefectTypePanel({required this.report});

  final ProductionReport report;

  @override
  Widget build(BuildContext context) {
    final types = report.defectTypes;
    final maxQty = types.fold<int>(
      0,
      (m, t) => t.quantity > m ? t.quantity : m,
    );
    final number = NumberFormat.decimalPattern('pt_BR');

    return _Panel(
      title: 'Defeitos por tipo',
      subtitle: 'Dispositivos reprovados no teste, agrupados por defeito',
      icon: Icons.report_gmailerrorred_rounded,
      child: types.isEmpty
          ? const Text(
              'Nenhum defeito registrado nos testes até o momento.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          : Column(
              children: [
                for (var i = 0; i < types.length; i++) ...[
                  _DefectTypeBar(
                    stats: types[i],
                    maxQty: maxQty,
                    number: number,
                  ),
                  if (i < types.length - 1) const SizedBox(height: 14),
                ],
              ],
            ),
    );
  }
}

class _DefectTypeBar extends StatelessWidget {
  const _DefectTypeBar({
    required this.stats,
    required this.maxQty,
    required this.number,
  });

  final DefectTypeStats stats;
  final int maxQty;
  final NumberFormat number;

  @override
  Widget build(BuildContext context) {
    final fraction = maxQty == 0
        ? 0.0
        : (stats.quantity / maxQty).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                stats.code,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.danger,
                ),
              ),
            ),
            Expanded(
              child: Text(
                stats.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
            Text(
              '${number.format(stats.quantity)} un · ${stats.occurrences} OP${stats.occurrences == 1 ? '' : 's'}',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textCode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 8,
            color: AppColors.bgProgress,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction == 0 ? 0.001 : fraction,
              child: Container(color: AppColors.danger),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tempo médio por etapa
// ---------------------------------------------------------------------------

class _StageTimingPanel extends StatelessWidget {
  const _StageTimingPanel({required this.report});

  final ProductionReport report;

  @override
  Widget build(BuildContext context) {
    final stats = report.visibleStages
        .map((s) => report.stageStats[s]!)
        .toList();
    final maxAvg = stats.fold<int>(
      0,
      (m, s) => s.average.inSeconds > m ? s.average.inSeconds : m,
    );

    return _Panel(
      title: 'Tempo médio por etapa',
      subtitle: 'Média das etapas já concluídas em todas as OPs',
      icon: Icons.timeline_rounded,
      child: Column(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            _StageBar(stats: stats[i], maxSeconds: maxAvg),
            if (i < stats.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar({required this.stats, required this.maxSeconds});

  final StageStats stats;
  final int maxSeconds;

  @override
  Widget build(BuildContext context) {
    final hasData = stats.samples > 0;
    final fraction = (!hasData || maxSeconds == 0)
        ? 0.0
        : (stats.average.inSeconds / maxSeconds).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stats.stage.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
            Text(
              hasData
                  ? '${formatProductionDuration(stats.average)} · ${stats.samples} OP${stats.samples == 1 ? '' : 's'}'
                  : 'sem dados',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: hasData ? AppColors.textCode : AppColors.textWeak,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 8,
            color: AppColors.bgProgress,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction == 0 ? 0.001 : fraction,
              child: Container(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pausas e saidas
// ---------------------------------------------------------------------------

class _PauseEventsPanel extends StatelessWidget {
  const _PauseEventsPanel({required this.report});

  final ProductionReport report;

  @override
  Widget build(BuildContext context) {
    final rows = report.pauseEvents.take(8).toList();

    return _Panel(
      title: 'Pausas e saidas',
      subtitle: 'Motivos assinados por PIN e quantidades informadas',
      icon: Icons.pause_circle_outline_rounded,
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Nenhuma pausa registrada ainda.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  _PauseEventItem(row: rows[i], now: report.now),
                  if (i < rows.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _PauseEventItem extends StatelessWidget {
  const _PauseEventItem({required this.row, required this.now});

  final PauseEventRow row;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final duration = formatProductionDuration(row.event.pauseDuration(now));
    final stateLabel = row.event.resumedAt == null ? 'Em pausa' : 'Pausou';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        if (compact) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgHeader,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        row.order.number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexMono(
                          color: AppColors.textCode,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      duration,
                      textAlign: TextAlign.end,
                      style: GoogleFonts.ibmPlexMono(
                        color: AppColors.textCode,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  row.event.operatorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ReportChip(
                      label: row.event.stage.label,
                      color: AppColors.primary,
                    ),
                    _ReportChip(
                      label: row.event.reasonLabel,
                      color: AppColors.orangeText,
                    ),
                    _ReportChip(label: stateLabel, color: AppColors.muted),
                    if (row.event.producedQuantity > 0)
                      _ReportChip(
                        label: '${row.event.producedQuantity} un.',
                        color: AppColors.green,
                      ),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borderLight)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  row.order.number,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexMono(
                    color: AppColors.textCode,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  row.event.operatorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  '${row.event.stage.label} - ${row.event.reasonLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  row.event.resumedAt == null
                      ? 'em pausa: $duration'
                      : 'pausou $duration',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OperatorWorkPanel extends StatelessWidget {
  const _OperatorWorkPanel({required this.report});

  final ProductionReport report;

  @override
  Widget build(BuildContext context) {
    final rows = report.operatorWorkRows.take(10).toList();

    return _Panel(
      title: 'Tempo por colaborador',
      subtitle: 'Tempo trabalhado por pessoa em cada OP e etapa',
      icon: Icons.badge_outlined,
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Nenhum colaborador assinou uma OP ainda.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  _OperatorWorkItem(
                    row: rows[i],
                    now: report.now,
                    statusLabel: _sessionStatus(rows[i].session),
                  ),
                  if (i < rows.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  String _sessionStatus(ProductionOperatorSession session) {
    if (session.isCompleted) return 'concluido';
    if (session.isPaused) return 'pausado';
    return 'rodando';
  }
}

class _OperatorWorkItem extends StatelessWidget {
  const _OperatorWorkItem({
    required this.row,
    required this.now,
    required this.statusLabel,
  });

  final OperatorWorkRow row;
  final DateTime now;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        if (compact) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgHeader,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        row.order.number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexMono(
                          color: AppColors.textCode,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatProductionDuration(row.session.workedDuration(now)),
                      textAlign: TextAlign.end,
                      style: GoogleFonts.ibmPlexMono(
                        color: AppColors.textCode,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  row.session.operatorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ReportChip(
                      label: row.session.stage.label,
                      color: AppColors.primary,
                    ),
                    _ReportChip(
                      label: statusLabel,
                      color: _sessionStatusColor(row.session),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borderLight)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  row.order.number,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexMono(
                    color: AppColors.textCode,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  row.session.operatorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  row.session.stage.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _sessionStatusColor(row.session),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  formatProductionDuration(row.session.workedDuration(now)),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexMono(
                    color: AppColors.textCode,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportChip extends StatelessWidget {
  const _ReportChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color _sessionStatusColor(ProductionOperatorSession session) {
  if (session.isCompleted) return AppColors.green;
  if (session.isPaused) return AppColors.orangeText;
  return AppColors.primary;
}

// ---------------------------------------------------------------------------
// Produção e defeitos por produto
// ---------------------------------------------------------------------------

class _ProductBreakdownPanel extends StatelessWidget {
  const _ProductBreakdownPanel({required this.report});

  final ProductionReport report;

  @override
  Widget build(BuildContext context) {
    final products = report.productStats;
    return _Panel(
      title: 'Produção e defeitos por produto',
      subtitle: 'Unidades aprovadas e reprovadas por modelo',
      icon: Icons.category_outlined,
      child: Column(
        children: [
          for (var i = 0; i < products.length; i++) ...[
            _ProductRow(stats: products[i]),
            if (i < products.length - 1)
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 12),
                color: AppColors.borderLight,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.stats});

  final ProductStats stats;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.decimalPattern('pt_BR');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stats.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${stats.orders} OP${stats.orders == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MiniStat(
              label: 'Produzidos',
              value: number.format(stats.producedUnits),
              color: AppColors.green,
            ),
            _MiniStat(
              label: 'Defeitos',
              value: number.format(stats.defectUnits),
              color: AppColors.danger,
            ),
            _MiniStat(
              label: 'Taxa',
              value: stats.inspectedUnits == 0
                  ? '—'
                  : '${(stats.defectRate * 100).toStringAsFixed(1)}%',
              color: AppColors.primary,
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgHeader,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textCode,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detalhamento por OP (com linha do tempo das etapas)
// ---------------------------------------------------------------------------

class _OrdersDetailPanel extends StatelessWidget {
  const _OrdersDetailPanel({required this.report});

  final ProductionReport report;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Detalhamento das OPs',
      subtitle: report.visibleArea == null
          ? 'Criação, finalização, defeitos e tempo de cada etapa'
          : 'Criação, finalização e tempo apenas do setor visível',
      icon: Icons.fact_check_outlined,
      child: Column(
        children: [
          for (var i = 0; i < report.orders.length; i++) ...[
            _OrderReportCard(order: report.orders[i], report: report),
            if (i < report.orders.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _OrderReportCard extends StatelessWidget {
  const _OrderReportCard({required this.order, required this.report});

  final ProductionOrderFlow order;
  final ProductionReport report;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yy HH:mm');
    final finished = report.finishedAt(order);
    final defects = report.defectsOf(order);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.bgHeader,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
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
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textCode,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusChip(order: order),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.productLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStat(
                label: 'Criada',
                value: dateFmt.format(order.createdAt),
                color: AppColors.primary,
              ),
              _MiniStat(
                label: 'Finalizada',
                value: finished == null ? '—' : dateFmt.format(finished),
                color: finished == null ? AppColors.iconMuted : AppColors.green,
              ),
              _MiniStat(
                label: report.visibleArea == null
                    ? 'Tempo total'
                    : 'Tempo no setor',
                value: formatProductionDuration(
                  report.visibleArea == null
                      ? order.totalElapsed(report.now)
                      : report.visibleElapsed(order),
                ),
                color: AppColors.primary,
              ),
              _MiniStat(
                label: 'Qtd.',
                value: '${order.quantity} un',
                color: AppColors.iconMuted,
              ),
              _MiniStat(
                label: 'Defeitos',
                value: defects == null ? '—' : '$defects un',
                color: AppColors.danger,
              ),
            ],
          ),
          if (order.testDefects.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Defeitos: ${order.testDefects.map((d) => '${d.code} (${d.quantity})').join(' · ')}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.orangeText,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Tempo por etapa',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.label,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 9),
          _StageTimeline(
            order: order,
            now: report.now,
            stages: report.visibleStages,
          ),
        ],
      ),
    );
  }
}

class _StageTimeline extends StatelessWidget {
  const _StageTimeline({
    required this.order,
    required this.now,
    required this.stages,
  });

  final ProductionOrderFlow order;
  final DateTime now;
  final List<ProductionStage> stages;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final stage in stages)
          _StageChip(stage: stage, timing: order.timings[stage], now: now),
      ],
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.stage,
    required this.timing,
    required this.now,
  });

  final ProductionStage stage;
  final ProductionStageTiming? timing;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final started = timing?.startedAt != null;
    final completed = timing?.completedAt != null;

    final Color color;
    final String value;
    if (completed) {
      color = AppColors.green;
      value = formatProductionDuration(timing!.elapsed(now));
    } else if (started) {
      color = AppColors.orange;
      value = 'em andamento';
    } else {
      color = AppColors.iconMuted;
      value = '—';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Text(
                stage.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: completed ? AppColors.textCode : AppColors.textWeak,
            ),
          ),
        ],
      ),
    );
  }
}

/// Etapa que melhor representa onde a OP está no relatório: a que está em
/// andamento; se nenhuma, a última já concluída; senão, a etapa atual.
ProductionStage _reportStage(ProductionOrderFlow order) {
  ProductionStage? inProgress;
  ProductionStage? lastCompleted;
  for (final stage in ProductionStage.productionFlow) {
    final timing = order.timings[stage];
    if (timing == null) continue;
    if (timing.startedAt != null && timing.completedAt == null) {
      inProgress = stage;
    }
    if (timing.completedAt != null) {
      lastCompleted = stage;
    }
  }
  return inProgress ?? lastCompleted ?? order.currentStage;
}

bool _orderTouchesArea(ProductionOrderFlow order, WorkArea area) {
  if (_areaForStage(order.currentStage) == area) return true;
  for (final stage in order.timings.keys) {
    if (_areaForStage(stage) == area) return true;
  }
  for (final session in order.operatorSessions) {
    if (_areaForStage(session.stage) == area) return true;
  }
  for (final pause in order.pauseEvents) {
    if (_areaForStage(pause.stage) == area) return true;
  }
  return false;
}

WorkArea _areaForStage(ProductionStage stage) {
  return switch (stage) {
    ProductionStage.warehouse => WorkArea.warehouse,
    ProductionStage.smd => WorkArea.smd,
    ProductionStage.firmware ||
    ProductionStage.soldering ||
    ProductionStage.testing ||
    ProductionStage.closing ||
    ProductionStage.expedition ||
    ProductionStage.storage ||
    ProductionStage.completed => WorkArea.production,
  };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.order});

  final ProductionOrderFlow order;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    final Color bg;
    if (order.totalStoredQuantity > 0 && order.isDone) {
      label = 'Armazenada';
      color = AppColors.primary;
      bg = AppColors.bgAndamento;
    } else if (order.isDone) {
      label = 'Finalizada';
      color = AppColors.green;
      bg = AppColors.bgFinalizada;
    } else {
      // Mostra a etapa realmente trabalhada (em andamento ou a última
      // concluída), e não a próxima etapa ainda pendente. Assim uma OP que
      // acabou de passar pelo teste aparece como "Teste", não "Fechamento".
      label = _reportStage(order).label;
      color = AppColors.orangeText;
      bg = const Color(0xFFFBF1E2);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painel base reutilizado pelas seções
// ---------------------------------------------------------------------------

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
