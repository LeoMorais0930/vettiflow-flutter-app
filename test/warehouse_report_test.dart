import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_read_repository.dart';
import 'package:vetti_flow_1_0/ui/reports/warehouse_report_page.dart';
import 'package:vetti_flow_1_0/ui/reports/warehouse_report_pdf.dart';

Map<String, dynamic> sampleReport({String detailStatus = 'not_requested'}) => {
  'version': 1,
  'id': 'qa-report',
  'database': 'HMLp12',
  'company': '010',
  'warehouse': '01',
  'filial': '04',
  'total': 1205,
  'startedAt': '2026-09-24T12:00:00Z',
  'asOf': '2026-09-24T12:00:01Z',
  'firstRecord': '20260901',
  'lastRecord': '20260918',
  'databaseLatestRecord': '20260918',
  'filters': {
    'start': '2026-09-01',
    'end': '2026-09-30',
    'kinds': [],
    'status': 'all',
  },
  'summary': [
    {'kind': 'transfer', 'flow': 'out', 'reversed': 0, 'count': 1200},
    {'kind': 'transfer', 'flow': 'out', 'reversed': 1, 'count': 5},
  ],
  'series': [
    {'period': '20260901', 'count': 1200},
    {'period': '20260918', 'count': 5},
  ],
  'seriesUnit': 'day',
  'seriesGroupCount': 2,
  'products': [
    {
      'code': '123-456',
      'description': 'Componente de precisão e conexão',
      'unit': 'M',
      'quantity': 0.83,
      'kind': 'transfer',
      'flow': 'out',
      'reversed': 0,
      'count': 1200,
    },
  ],
  'productGroupCount': 125,
  'detailStatus': detailStatus,
  'detailLimit': 1000,
  'items': [],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  test(
    'report request keeps multiple kinds and official snapshot filters',
    () async {
      late Uri uri;
      final repo = WarehouseReadRepository(
        baseUrl: 'http://api',
        apiToken: 'report-test',
        httpClient: MockClient((r) async {
          uri = r.url;
          expect(r.headers['X-API-Token'], 'report-test');
          return http.Response(
            jsonEncode(sampleReport()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(repo.close);
      final result = await repo.report(
        ReportFilters(
          kinds: const ['transfer', 'receipt'],
          operator: 'vera',
          product: '123',
          details: true,
        ),
      );
      expect(uri.path, '/api/v1/relatorios/almoxarifado');
      expect(uri.queryParametersAll['kinds'], ['transfer', 'receipt']);
      expect(uri.queryParameters['operator'], 'vera');
      expect(result.total, 1205);
      expect(result.reversedCount, 5);
      expect(result.filterLabels.join(' '), contains('Setembro de 2026'));
      expect(reportNumber(0.83), '0,83');
      expect(reportNumber(null), 'Não informado');
    },
  );

  testWidgets('preview uses full totals and invalidates after filter edits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    final repo = WarehouseReadRepository(
      baseUrl: 'http://api',
      httpClient: MockClient((r) async {
        calls++;
        return http.Response(
          jsonEncode(sampleReport(detailStatus: 'too_large')),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(repo.close);
    await tester.pumpWidget(
      Provider.value(
        value: repo,
        child: const MaterialApp(home: WarehouseReportPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('1.205'), findsWidgets);
    expect(find.textContaining('1.000'), findsWidgets);
    expect(find.textContaining('125'), findsWidgets);
    expect(find.text('Gerar resumo em PDF'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('report-pdf')))
          .onPressed,
      isNotNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('report-query')),
      'Componente',
    );
    await tester.pump();
    expect(
      find.text('Aplique os filtros para atualizar o relatório.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('report-pdf')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('mobile filters and error recovery do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = WarehouseReadRepository(
      baseUrl: 'http://api',
      httpClient: MockClient((r) async => http.Response('{}', 503)),
    );
    addTearDown(repo.close);
    await tester.pumpWidget(
      Provider.value(
        value: repo,
        child: const MaterialApp(home: WarehouseReportPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Aplicar filtros'));
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível gerar o relatório. Tente novamente.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('PDF keeps full scope summary and refuses incomplete detail', () async {
    final report = WarehouseReport(sampleReport(detailStatus: 'too_large'));
    final bytes = await buildWarehouseReportPdf(report);
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    if (Platform.environment['VF_REPORT_QA'] == '1') {
      final dir = Directory('tmp/pdfs')..createSync(recursive: true);
      File('${dir.path}/almoxarifado-qa.pdf').writeAsBytesSync(bytes);
    }
    await expectLater(
      buildWarehouseReportPdf(report, includeDetails: true),
      throwsStateError,
    );
  });

  test(
    'empty PDF and detail PDF preserve decimal quantities and source notes',
    () async {
      final empty = sampleReport(detailStatus: 'complete')
        ..addAll({
          'total': 0,
          'summary': [],
          'products': [],
          'series': [],
          'productGroupCount': 0,
          'seriesGroupCount': 0,
        });
      expect(
        (await buildWarehouseReportPdf(
          WarehouseReport(empty),
          includeDetails: true,
        )).length,
        greaterThan(1000),
      );
      final detailed = sampleReport(detailStatus: 'complete')
        ..addAll({
          'total': 1,
          'items': [
            {
              'id': 'SD3:1',
              'source': 'SD3',
              'date': '20260918',
              'code': 'ABC',
              'description': 'Conexão elétrica',
              'quantity': 0.83,
              'unit': 'M',
              'kind': 'transfer',
              'flow': 'out',
              'reversed': 0,
              'peerCount': 1,
              'otherWarehouse': '05',
              'otherCode': 'DEF',
              'otherQuantity': 0.83,
              'otherUnit': 'M',
              'cf': 'RE4',
              'tm': '999',
              'document': '123',
              'op': '00101001001',
              'operator': 'vera',
            },
          ],
        });
      final report = WarehouseReport(detailed);
      expect(report.canDetail, isTrue);
      expect(
        (await buildWarehouseReportPdf(
          report,
          includeDetails: true,
          includeChart: false,
        )).length,
        greaterThan(1000),
      );
      if (Platform.environment['VF_REPORT_QA'] == '1') {
        final real = WarehouseReport(
          jsonDecode(
                File('.dart_tool/report-september.json').readAsStringSync(),
              )
              as Map<String, dynamic>,
        );
        expect(real.total, real.items.length);
        final bytes = await buildWarehouseReportPdf(real, includeDetails: true);
        File('tmp/pdfs/almoxarifado-setembro-dev.pdf').writeAsBytesSync(bytes);
      }
    },
  );

  testWidgets(
    'complete detail can be inspected and multiple kinds are applied together',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Uri request;
      final data = sampleReport(detailStatus: 'complete')
        ..addAll({
          'total': 1,
          'items': [
            {
              'source': 'SD3',
              'date': '20260918',
              'code': 'ABC',
              'description': 'Conexão',
              'quantity': 0.83,
              'unit': 'M',
              'kind': 'transfer',
              'flow': 'out',
              'reversed': 0,
              'document': '123',
              'operator': 'vera',
            },
          ],
        });
      final repo = WarehouseReadRepository(
        baseUrl: 'http://api',
        httpClient: MockClient((r) async {
          request = r.url;
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(repo.close);
      await tester.pumpWidget(
        Provider.value(
          value: repo,
          child: const MaterialApp(home: WarehouseReportPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Transferências'));
      await tester.tap(find.widgetWithText(FilterChip, 'Ajustes'));
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(request.queryParametersAll['kinds'], ['transfer', 'adjustment']);
      await tester.ensureVisible(find.text('18/09/2026 · ABC'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('18/09/2026 · ABC'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Quantidade: 0,83 M'), findsOneWidget);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
