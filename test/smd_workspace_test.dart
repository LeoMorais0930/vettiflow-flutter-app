import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_read_repository.dart';
import 'package:vetti_flow_1_0/ui/smd/smd_page.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_read_page.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> mount(
    WidgetTester tester,
    List<Uri> requests, {
    Widget page = const SmdPage(),
    bool mobile = false,
  }) async {
    tester.view.physicalSize = mobile
        ? const Size(390, 844)
        : const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = WarehouseReadRepository(
      baseUrl: 'http://api',
      httpClient: MockClient((r) async {
        requests.add(r.url);
        return http.Response(
          jsonEncode({
            'total': 120,
            'databaseLatestRecord': '20260918',
            'items': [
              r.url.queryParameters['view'] == 'orders'
                  ? {
                      'id': 'SC2:1',
                      'op': '01600101001',
                      'code': '500-0001',
                      'description': 'Placa SMD',
                      'quantity': 100.5,
                      'produced': 20.25,
                      'unit': 'PC',
                      'closed': 0,
                      'date': '20260801',
                    }
                  : {
                      'id': 'SD3:1',
                      'code': '500-0001',
                      'op': '01600101001',
                      'description': 'Placa SMD',
                      'quantity': 20.25,
                      'unit': 'PC',
                      'kind': 'production',
                      'flow': 'in',
                      'operator': 'paulad',
                      'date': '20260917',
                      'document': '016001010',
                      'reversed': 0,
                    },
            ],
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      Provider.value(
        value: repo,
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'SMD reads open official OPs and distinct posting/material views',
    (tester) async {
      final requests = <Uri>[];
      await mount(tester, requests);
      expect(requests.last.queryParameters, containsPair('view', 'orders'));
      expect(requests.last.queryParameters, containsPair('local', '03'));
      expect(requests.last.queryParameters, containsPair('status', 'active'));
      expect(requests.last.queryParameters, containsPair('page_size', '50'));
      expect(find.text('01600101001'), findsOneWidget);
      expect(find.textContaining('Restante: 80,25'), findsOneWidget);
      expect(find.text('Iniciar SMD'), findsNothing);
      expect(find.text('Concluir apontamento'), findsNothing);
      expect(find.byKey(const ValueKey('warehouse-selector')), findsNothing);
      await tester.tap(find.text('Apontamentos'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters, containsPair('kind', 'production'));
      expect(requests.last.queryParameters, containsPair('view', 'history'));
      expect(find.textContaining('paulad'), findsOneWidget);
      expect(find.textContaining('OP 01600101001'), findsOneWidget);
      await tester.tap(find.text('Consumo'));
      await tester.pumpAndSettle();
      expect(
        requests.last.queryParameters,
        containsPair('kind', 'consumption'),
      );
      await tester.tap(find.text('Movimentações'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters, containsPair('kind', 'all'));
      expect(tester.takeException(), isNull);
    },
  );

  for (final page in [const SmdPage(), const WarehouseReadPage()]) {
    testWidgets(
      '${page.runtimeType} month includes leap day, persists across tabs and resets pagination',
      (tester) async {
        final requests = <Uri>[];
        await mount(tester, requests, page: page);
        if (page is! SmdPage) {
          await tester.tap(find.text('Histórico'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byTooltip('Próxima página'));
        await tester.pumpAndSettle();
        expect(requests.last.queryParameters['page'], '2');
        await tester.tap(find.byKey(const ValueKey('period-picker')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('period-year')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2024').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fev'));
        await tester.pumpAndSettle();
        expect(requests.last.queryParameters['start'], '2024-02-01');
        expect(requests.last.queryParameters['end'], '2024-02-29');
        expect(requests.last.queryParameters['page'], '1');
        await tester.tap(find.text(page is SmdPage ? 'Apontamentos' : 'OPs'));
        await tester.pumpAndSettle();
        expect(requests.last.queryParameters['start'], '2024-02-01');
        expect(requests.last.queryParameters['end'], '2024-02-29');
        await tester.tap(find.byKey(const ValueKey('period-picker')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Todo o período'));
        await tester.pumpAndSettle();
        expect(requests.last.queryParameters.containsKey('start'), isFalse);
        expect(requests.last.queryParameters.containsKey('end'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('SMD fits mobile and stock does not imply a historical balance', (
    tester,
  ) async {
    final requests = <Uri>[];
    await mount(tester, requests, mobile: true);
    expect(find.text('01600101001'), findsOneWidget);
    await tester.ensureVisible(find.text('Estoque'));
    await tester.tap(find.text('Estoque'));
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['view'], 'stock');
    expect(find.text('Saldos atuais'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
