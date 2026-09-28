import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_read_repository.dart';
import 'package:vetti_flow_1_0/ui/expedition/expedition_read_page.dart';
import 'package:vetti_flow_1_0/ui/expedition/expedition_page.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'local conference does not invent a sales order or an approved testing stage',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = ProductionFlowStore();
      await store.createOrder(
        productCode: '575-0764',
        quantity: 10,
        priority: 'Media',
        operatorName: 'Tatiane',
        plannedStages: const [ProductionStage.expedition],
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider(create: (_) => OperatorAssignmentStore()),
          ],
          child: const MaterialApp(home: ExpeditionPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Não emite nota'), findsOneWidget);
      expect(find.textContaining('PED-'), findsNothing);
      expect(find.textContaining('Teste aprovado'), findsNothing);
      expect(find.textContaining('Sem pedido vinculado'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'expedition shortcut is available to its operators and management',
    (tester) async {
      for (final operator in [
        Operator.all.firstWhere((o) => o.stage == WorkStage.expedition),
        Operator.all.firstWhere((o) => o.username == 'admin'),
        Operator.all.firstWhere((o) => o.username == 'juliana'),
      ]) {
        final store = OperatorAssignmentStore()
          ..authenticate(operator.username, operator.password);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: store,
            child: MaterialApp(
              home: const Scaffold(body: ExpeditionNavigationButton()),
              routes: {
                '/expedicao': (_) => const Scaffold(body: Text('Consulta 10')),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (operator.username == 'juliana') {
          expect(find.text('Expedição'), findsNothing);
        } else {
          await tester.tap(find.text('Expedição'));
          await tester.pumpAndSettle();
          expect(find.text('Consulta 10'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      }
    },
  );
  Future<void> mount(
    WidgetTester tester,
    List<Uri> requests, {
    bool mobile = false,
    bool fail = false,
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
        expect(r.method, 'GET');
        requests.add(r.url);
        if (r.url.path.contains('/notas/')) {
          return http.Response(
            jsonEncode({
              'readOnly': true,
              'headerStatus': 'found',
              'item': {'salesOrder': '123456', 'salesOrderItem': '02'},
              'document': {
                'carrier': '01',
                'carrierName': 'Transportadora teste',
                'trackingCode': '',
                'trackingType': 'CR',
                'trackingEnabled': 'S',
                'trackingLog': '',
                'volume1': 2,
                'packaging1': 'CAIXA',
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'total': 120,
            'databaseLatestRecord': '20260918',
            'summary': [],
            'items': [
              {
                'id': 'SD2:7',
                'source': 'SD2',
                'warehouse': '10',
                'code': '575-0764',
                'description': 'Produto acabado',
                'quantity': 2,
                'unit': 'PC',
                'kind': 'dispatch',
                'flow': 'none',
                'tes': '609',
                'cfop': '5922',
                'date': '20260915',
                'document': '000123',
                'reversed': 0,
              },
            ],
          }),
          fail ? 503 : 200,
        );
      }),
    );
    addTearDown(repo.close);
    await tester.pumpWidget(
      Provider.value(
        value: repo,
        child: MaterialApp(
          home: const ExpeditionReadPage(),
          routes: {
            '/expedicao/fluxo-local': (_) =>
                const Scaffold(body: Text('Fluxo local aberto')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'expedition reads only 10 with month, pagination and fiscal shipping details',
    (tester) async {
      final requests = <Uri>[];
      await mount(tester, requests);
      expect(requests.last.path, '/api/v1/expedicao');
      expect(requests.last.queryParameters['local'], '10');
      expect(requests.last.queryParameters.containsKey('start'), isFalse);
      expect(find.byKey(const ValueKey('warehouse-selector')), findsNothing);
      expect(find.text('Finalizar despacho'), findsNothing);
      await tester.tap(find.text('Histórico'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Próxima página'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['page'], '2');
      await tester.tap(find.byKey(const ValueKey('period-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['page'], '1');
      await tester.tap(find.text('Notas'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['end'], endsWith('-09-30'));
      expect(requests.last.queryParameters['kind'], 'fiscal');
      expect(find.text('Sem efeito no estoque'), findsOneWidget);
      await tester.tap(find.text('575-0764'));
      await tester.pumpAndSettle();
      expect(requests.last.path, '/api/v1/expedicao/notas/7');
      expect(find.text('123456'), findsOneWidget);
      expect(find.textContaining('Transportadora teste'), findsOneWidget);
      expect(find.text('Não informado'), findsWidgets);
      expect(find.text('Entregue'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile expedition keeps current stock and offers separate local conference',
    (tester) async {
      final requests = <Uri>[];
      await mount(tester, requests, mobile: true);
      await tester.ensureVisible(find.text('Estoque'));
      await tester.tap(find.text('Estoque'));
      await tester.pumpAndSettle();
      expect(find.text('Saldos atuais'), findsOneWidget);
      await tester.tap(find.byTooltip('Conferência local'));
      await tester.pumpAndSettle();
      expect(find.text('Fluxo local aberto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('expedition can retry a failed read', (tester) async {
    final requests = <Uri>[];
    await mount(tester, requests, fail: true);
    expect(find.text('Não foi possível carregar'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(requests.length, 2);
    expect(tester.takeException(), isNull);
  });
}
