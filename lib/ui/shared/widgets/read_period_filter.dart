import 'package:flutter/material.dart';

const _months = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];
const _shortMonths = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

String readPeriodLabel(DateTime? start, DateTime? end) {
  if (start == null || end == null) return 'Todo o período';
  if (start.day == 1 &&
      start.year == end.year &&
      start.month == end.month &&
      end.day == DateTime(start.year, start.month + 1, 0).day) {
    return '${_months[start.month - 1]} de ${start.year}';
  }
  String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  return '${date(start)} — ${date(end)}';
}

/// Shared date selection for read-only sector queries. Bounds are inclusive.
class ReadPeriodFilter extends StatelessWidget {
  const ReadPeriodFilter({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
    this.dateLabel = 'Data do movimento',
  });
  final DateTime? start;
  final DateTime? end;
  final String dateLabel;
  final ValueChanged<DateTimeRange?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(dateLabel, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        key: const ValueKey('period-picker'),
        icon: const Icon(Icons.calendar_month_outlined, size: 18),
        label: Text(readPeriodLabel(start, end)),
        onPressed: () async {
          var year = (start ?? DateTime.now()).year;
          final result = await showDialog<_PeriodChoice>(
            context: context,
            builder: (dialogContext) => StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                title: const Text('Escolher mês'),
                content: SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        key: const ValueKey('period-year'),
                        initialValue: year,
                        decoration: const InputDecoration(labelText: 'Ano'),
                        menuMaxHeight: 280,
                        items: [
                          for (var y = DateTime.now().year; y >= 1900; y--)
                            DropdownMenuItem(value: y, child: Text('$y')),
                        ],
                        onChanged: (value) =>
                            setState(() => year = value ?? year),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 3,
                        childAspectRatio: 1.7,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (var month = 1; month <= 12; month++)
                            TextButton(
                              onPressed: () => Navigator.pop(
                                dialogContext,
                                _PeriodChoice(
                                  range: DateTimeRange(
                                    start: DateTime(year, month),
                                    end: DateTime(year, month + 1, 0),
                                  ),
                                ),
                              ),
                              child: Text(_shortMonths[month - 1]),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(dialogContext, const _PeriodChoice()),
                    child: const Text('Todo o período'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      dialogContext,
                      const _PeriodChoice(custom: true),
                    ),
                    child: const Text('Personalizar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          );
          if (result == null || !context.mounted) return;
          if (!result.custom) {
            onChanged(result.range);
            return;
          }
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(1900),
            lastDate: DateTime(DateTime.now().year, 12, 31),
            initialDateRange: start == null || end == null
                ? null
                : DateTimeRange(start: start!, end: end!),
            helpText: 'Período da consulta',
            saveText: 'Aplicar',
            cancelText: 'Cancelar',
          );
          if (range != null && context.mounted) onChanged(range);
        },
      ),
    ],
  );
}

class _PeriodChoice {
  const _PeriodChoice({this.range, this.custom = false});
  final DateTimeRange? range;
  final bool custom;
}
