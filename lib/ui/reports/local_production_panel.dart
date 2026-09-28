import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class LocalProductionPanel extends StatefulWidget {
  const LocalProductionPanel({super.key, required this.report});
  final WarehouseReport report;
  @override
  State<LocalProductionPanel> createState() => _LocalProductionPanelState();
}

class _LocalProductionPanelState extends State<LocalProductionPanel> {
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final local = report.local!;
    final rows = local['rows'] as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          report.originLabel,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final metric in local['metrics'] as List)
              Container(
                width: 205,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${metric['label']}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${metric['value']}',
                      style: const TextStyle(
                        fontSize: 22,
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
        Text(
          '${local['notice']}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Nenhum evento concluído nos filtros selecionados. Os registros aparecerão conforme o fluxo for utilizado neste dispositivo.',
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(
                AppColors.background,
              ),
              dataRowMinHeight: 56,
              dataRowMaxHeight: 120,
              columns: [
                for (final title in local['headers'] as List)
                  DataColumn(
                    label: Text(
                      '$title',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
              rows: [
                for (final row in rows.skip(_page * 10).take(10))
                  DataRow(
                    cells: [
                      for (final value in row as List)
                        DataCell(
                          SizedBox(
                            width: 160,
                            child: Tooltip(
                              message: '$value',
                              child: Text(
                                '$value',
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        if (rows.length > 10)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Página anterior',
                onPressed: _page == 0 ? null : () => setState(() => _page--),
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${_page + 1} / ${(rows.length / 10).ceil()}'),
              IconButton(
                tooltip: 'Próxima página',
                onPressed: (_page + 1) * 10 >= rows.length
                    ? null
                    : () => setState(() => _page++),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }
}
