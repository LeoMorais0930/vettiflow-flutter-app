import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class ProductionInsightsPanel extends StatefulWidget {
  const ProductionInsightsPanel({
    super.key,
    required this.report,
    required this.onFilter,
  });
  final WarehouseReport report;
  final ValueChanged<Map<String, dynamic>> onFilter;
  @override
  State<ProductionInsightsPanel> createState() =>
      _ProductionInsightsPanelState();
}

class _ProductionInsightsPanelState extends State<ProductionInsightsPanel> {
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final data = report.production!;
    final maximum = data.rows.fold<num>(
      1,
      (v, r) => (r['quantity'] as num) > v ? r['quantity'] as num : v,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final metric in {
              'OPs com apontamento': data.metrics['orderCount'],
              'Produtos / unidades': data.metrics['productCount'],
              'Dias com apontamento': data.metrics['activeDays'],
              'Apontamentos válidos': report.total,
            }.entries)
              Container(
                width: 190,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.key,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reportNumber(metric.value),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.title,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          report.analysisLabel,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.title,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'PR0 sem marca de estorno. Quantidades separadas por produto e unidade.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          data.notice,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        if (report.analysis == 'destinations')
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Local em que o apontamento entrou. Não comprova envio ao cliente nem conclusão de reparo.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        if (!data.comparableQuantities && data.rows.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Filtre um produto e unidade para comparar as quantidades no gráfico.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        if ((data.metrics['withoutOrder'] as num? ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${reportNumber(data.metrics['withoutOrder'])} apontamentos sem OP informada.',
              style: const TextStyle(color: AppColors.orangeText),
            ),
          ),
        const SizedBox(height: 12),
        if (data.rows.isEmpty)
          const Text('Nenhum apontamento válido no recorte.'),
        for (final row in data.rows.skip(_page * 12).take(12))
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderLight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      ProductionInsights.rowLabel(row, report.analysis),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${reportNumber(row['quantity'])} ${row['unit']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                if (report.analysis != 'output')
                  Text(
                    '${row['description']}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  '${reportNumber(row['count'])} apontamentos · ${reportNumber(row['orderCount'])} OPs · ${reportNumber(row['activeDays'])} dias com apontamento',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (data.comparableQuantities) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: ((row['quantity'] as num) / maximum)
                        .clamp(0, 1)
                        .toDouble(),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.filter_alt_outlined, size: 16),
                    label: Text(
                      report.analysis == 'orders'
                          ? 'Filtrar esta OP e produto'
                          : 'Filtrar este produto',
                    ),
                    onPressed: () => widget.onFilter(row),
                  ),
                ),
              ],
            ),
          ),
        if (data.rows.length > 12)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Página anterior',
                onPressed: _page == 0 ? null : () => setState(() => _page--),
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${_page + 1} / ${(data.rows.length / 12).ceil()}'),
              IconButton(
                tooltip: 'Próxima página',
                onPressed: (_page + 1) * 12 >= data.rows.length
                    ? null
                    : () => setState(() => _page++),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        const SizedBox(height: 12),
        const Text(
          'A quantidade apontada mede saída registrada da produção. Os tempos, operadores e pausas estão nas análises de VettiFlow · operação.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }
}
