import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart';

/// Render a fetched snapshot, never requery the API during export.
Future<Uint8List> buildWarehouseReportPdf(
  WarehouseReport report, {
  bool includeDetails = false,
  bool includeChart = true,
}) async {
  if (includeDetails && !report.canDetail) {
    throw StateError(
      'Atualize ou reduza os filtros para incluir o detalhamento.',
    );
  }
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/IBMPlexSans-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/IBMPlexSans-SemiBold.ttf'),
  );
  final logo = pw.MemoryImage(
    (await rootBundle.load(
      'assets/images/vetti-flow-logo.png',
    )).buffer.asUint8List(),
  );
  final doc = pw.Document(
    title:
        '${report.sector.label} - ${report.analysisLabel} - ${report.periodLabel}',
    author: 'VettiFlow',
    subject: '${report.originLabel} - ${report.analysisLabel}',
  );
  final blue = PdfColor.fromHex('#0077BD');
  final ink = PdfColor.fromHex('#162C3A');
  final pale = PdfColor.fromHex('#EFF4F8');
  pw.Widget heading(String label) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
    child: pw.Text(
      label,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: ink,
      ),
    ),
  );
  pw.Widget table(
    List<String> headers,
    List<List<String>> rows, {
    Map<int, pw.TableColumnWidth>? widths,
  }) => pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    headerStyle: pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
    cellStyle: pw.TextStyle(fontSize: 8, color: ink),
    headerDecoration: pw.BoxDecoration(color: blue),
    oddRowDecoration: pw.BoxDecoration(color: pale),
    cellPadding: const pw.EdgeInsets.all(4),
    cellAlignment: pw.Alignment.centerLeft,
    columnWidths: widths,
    border: null,
  );
  final chart = report.series.length > 24
      ? report.series.sublist(report.series.length - 24)
      : report.series;
  final maxCount = chart.fold<num>(
    1,
    (m, r) => (r['count'] as num) > m ? r['count'] as num : m,
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(30),
      maxPages: 60,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: blue, width: 1)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Image(logo, width: 84, height: 25, fit: pw.BoxFit.contain),
            pw.Text(
              '${report.sector.label.toUpperCase()} / ${report.analysisLabel.toUpperCase()}',
              style: pw.TextStyle(font: bold, fontSize: 10, color: blue),
            ),
            pw.Text(
              report.isLocal
                  ? 'VettiFlow | Local'
                  : '${report.warehouses.join(', ')} | Filial ${report.filial} | DEV',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
      footer: (context) {
        // MultiPage.maxPages is debug-only; this guard also runs in release builds.
        if (context.pageNumber > 60) {
          throw StateError(
            'O PDF excedeu 60 páginas. Reduza os filtros ou gere o resumo.',
          );
        }
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'VettiFlow | ${report.id} | ${DateFormat('dd/MM/yyyy HH:mm').format(report.asOf)}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        );
      },
      build: (context) => [
        pw.SizedBox(height: 14),
        pw.Text(
          report.periodLabel,
          style: pw.TextStyle(fontSize: 24, font: bold, color: ink),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          report.isLocal
              ? report.originLabel
              : 'Protheus ${report.database} | Empresa ${report.company} | Consulta somente leitura',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 12),
        pw.Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in {
              if (report.isLocal) ...{
                for (final item in report.local!['metrics'] as List)
                  '${item['label']}': '${item['value']}',
              } else if (report.production != null) ...{
                'OPs com apontamento': reportNumber(
                  report.production!.metrics['orderCount'],
                ),
                'Dias com apontamento': reportNumber(
                  report.production!.metrics['activeDays'],
                ),
                'Apontamentos válidos': reportNumber(report.total),
              } else ...{
                'Registros no recorte': reportNumber(report.total),
                'Marcados como estornados': reportNumber(report.reversedCount),
                'Último registro do recorte': reportDate(report.lastRecord),
              },
            }.entries)
              pw.Container(
                width: 235,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: pale),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(entry.key, style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      entry.value,
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 19,
                        color: blue,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        heading('Filtros aplicados'),
        pw.Text(
          report.filterLabels.join(' | '),
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          report.isLocal
              ? 'Último evento do recorte: ${reportDate(report.lastRecord)}. Gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(report.asOf)}.'
              : 'Último registro nas tabelas do DEV consultadas: ${reportDate(report.databaseLatestRecord)}. Detalhamento: ${includeDetails ? 'incluído, ${report.items.length} registros' : 'não incluído'}.',
          style: const pw.TextStyle(fontSize: 9),
        ),
        if (report.isLocal) ...[
          heading(report.analysisLabel),
          pw.Text(
            '${report.local!['notice']}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          if ((report.local!['rows'] as List).isEmpty)
            pw.Text('Nenhum evento concluído no recorte.'),
          if ((report.local!['rows'] as List).isNotEmpty)
            table(List<String>.from(report.local!['headers'] as List), [
              for (final row in report.local!['rows'] as List)
                List<String>.from(row as List),
            ]),
        ] else if (report.production != null) ...[
          heading(report.analysisLabel),
          pw.Text(
            'PR0 sem marca de estorno. Quantidades separadas por produto e unidade.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            report.production!.notice,
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          if (report.production!.rows.isEmpty)
            pw.Text('Nenhum apontamento válido no recorte.'),
          if (report.production!.rows.isNotEmpty)
            table(
              [
                'Recorte / produto',
                'Quantidade',
                'Apontamentos',
                'OPs',
                'Dias com apontamento',
              ],
              [
                for (final row in report.production!.rows)
                  [
                    '${ProductionInsights.rowLabel(row, report.analysis)}\n${row['description']}',
                    '${reportNumber(row['quantity'])} ${row['unit']}',
                    reportNumber(row['count']),
                    reportNumber(row['orderCount']),
                    reportNumber(row['activeDays']),
                  ],
              ],
              widths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(1.4),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
              },
            ),
          if (includeChart &&
              report.production!.comparableQuantities &&
              report.production!.rows.length > 1) ...[
            pw.NewPage(),
            heading('Quantidades no recorte'),
            pw.Text(
              'Até 24 grupos do quadro selecionado; mesmo produto e unidade.',
              style: const pw.TextStyle(fontSize: 9),
            ),
            for (final row in report.production!.rows.take(24))
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 5),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 230,
                      child: pw.Text(
                        ProductionInsights.rowLabel(row, report.analysis),
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                    pw.SizedBox(
                      width: 440,
                      child: pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Container(
                          height: 8,
                          width:
                              440 *
                              ((row['quantity'] as num) /
                                      report.production!.rows.fold<num>(
                                        1,
                                        (m, r) => (r['quantity'] as num) > m
                                            ? r['quantity'] as num
                                            : m,
                                      ))
                                  .clamp(0, 1),
                          color: blue,
                        ),
                      ),
                    ),
                    pw.SizedBox(
                      width: 70,
                      child: pw.Text(
                        '${reportNumber(row['quantity'])} ${row['unit']}',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ] else ...[
          if (report.sector != ReportSector.warehouse) ...[
            heading('Registros por armazém'),
            pw.Text(report.scopeNote, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 8),
            table(
              ['Armazém físico', 'Registros'],
              [
                for (final row in report.warehouseSummary)
                  [
                    reportWarehouse(row['warehouse']),
                    reportNumber(row['count']),
                  ],
              ],
            ),
          ],
          heading('Resumo por movimento - recorte completo'),
          if (report.total == 0)
            pw.Text('Nenhum registro encontrado para os filtros selecionados.'),
          if (report.summary.isNotEmpty)
            table(
              [
                'Movimento',
                'Sentido / efeito em estoque',
                'Situação',
                'Registros',
              ],
              [
                for (final row in report.summary)
                  [
                    reportKind(row['kind']),
                    reportFlow(row['flow']),
                    reportSituation(row),
                    reportNumber(row['count']),
                  ],
              ],
            ),
          if (includeChart && chart.isNotEmpty) ...[
            pw.NewPage(),
            heading('Evolução de registros'),
            pw.Text(
              'Até 24 períodos com registro mais recentes. Contagem de registros, não quantidade de peças.',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 10),
            for (final row in chart)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 70,
                      child: pw.Text(
                        reportDate('${row['period']}'),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.SizedBox(
                      width: 600,
                      child: pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Container(
                          width: 600 * (row['count'] as num) / maxCount,
                          height: 9,
                          color: blue,
                        ),
                      ),
                    ),
                    pw.SizedBox(
                      width: 50,
                      child: pw.Text(
                        reportNumber(row['count']),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (report.products.isNotEmpty) ...[
            pw.NewPage(),
            heading('Quantidades por produto e unidade'),
            pw.Text(
              report.productNotice,
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 8),
            table(
              [
                'Produto',
                'Movimento',
                'Sentido',
                'Situação',
                'Quantidade',
                'Registros',
              ],
              [
                for (final row in report.products)
                  [
                    '${row['code']}\n${row['description']}\nLocal ${row['warehouse'] ?? report.warehouses.join(', ')}',
                    reportKind(row['kind']),
                    reportFlow(row['flow']),
                    reportSituation(row),
                    '${reportNumber(row['quantity'])} ${row['unit']}',
                    reportNumber(row['count']),
                  ],
              ],
              widths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.6),
                2: const pw.FlexColumnWidth(1.6),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.3),
                5: const pw.FlexColumnWidth(1),
              },
            ),
          ],
        ],
        if (includeDetails && report.items.isNotEmpty) ...[
          pw.NewPage(),
          heading('Registros do recorte - detalhamento completo'),
          table(
            [
              'Data / fonte',
              'Produto',
              'Movimento / códigos',
              'Quantidade',
              'Documento / OP',
              'Usuário',
              'Contraparte',
            ],
            [
              for (final row in report.items)
                [
                  '${reportDate('${row['date']}')}\n${row['source']}\nLocal ${row['warehouse'] ?? ''}',
                  '${row['code']}\n${row['description']}',
                  '${reportKind(row['kind'])} | ${reportFlow(row['flow'])}\n${reportSituation(row)}\n${[
                    for (final key in ['cf', 'tm', 'tes', 'cfop'])
                      if ('${row[key] ?? ''}'.isNotEmpty) '${key.toUpperCase()}: ${row[key]}',
                  ].join(' / ')}',
                  '${reportNumber(row['quantity'])} ${row['unit']}',
                  '${row['document'] ?? ''}${'${row['series'] ?? ''}'.isEmpty ? '' : ' / ${row['series']}'}\n${row['op'] ?? ''}',
                  '${row['operator'] ?? ''}'.isEmpty
                      ? 'Não informado'
                      : '${row['operator']}',
                  row['kind'] != 'transfer'
                      ? '-'
                      : row['peerCount'] == 1
                      ? 'Local ${row['otherWarehouse']}\n${row['otherCode']}\n${reportNumber(row['otherQuantity'])} ${row['otherUnit']}'
                      : 'Sem par inequívoco',
                ],
            ],
            widths: {
              0: const pw.FlexColumnWidth(1.1),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(2.3),
              3: const pw.FlexColumnWidth(1.1),
              4: const pw.FlexColumnWidth(1.6),
              5: const pw.FlexColumnWidth(1.3),
              6: const pw.FlexColumnWidth(1.5),
            },
          ),
        ],
        heading('Como ler este relatório'),
        for (final note in report.notes)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Text(note, style: const pw.TextStyle(fontSize: 9)),
          ),
        if (!includeDetails && !report.isLocal)
          pw.Text(report.detailNotice, style: const pw.TextStyle(fontSize: 9)),
      ],
    ),
  );
  final bytes = await doc.save();
  if (doc.document.pdfPageList.pages.length > 60) {
    throw StateError('O PDF excedeu 60 páginas. Reduza os filtros.');
  }
  return bytes;
}
