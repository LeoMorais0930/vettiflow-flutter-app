import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_read_repository.dart';
import 'package:vetti_flow_1_0/ui/support/support_page.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'support and management have a shortcut; unrelated operators do not',
    (tester) async {
      for (final username in ['bruno', 'admin', 'juliana']) {
        final operator = Operator.all.firstWhere((o) => o.username == username);
        final assignments = OperatorAssignmentStore()
          ..authenticate(operator.username, operator.password);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: assignments,
            child: MaterialApp(
              home: const Scaffold(body: SupportNavigationButton()),
              routes: {
                '/suporte': (_) =>
                    const Scaffold(body: Text('Consulta do suporte')),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (username == 'juliana') {
          expect(find.text('Suporte'), findsNothing);
        } else {
          await tester.tap(find.text('Suporte'));
          await tester.pumpAndSettle();
          expect(find.text('Consulta do suporte'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
        assignments.dispose();
      }
    },
  );

  testWidgets(
    'local defects remain visible on mobile even when the OP ends, without implying repair or transfer',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = ProductionFlowStore();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: const MaterialApp(
            home: Scaffold(body: SupportDefectsButton()),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Defeitos da produção'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nenhum defeito registrado no VettiFlow.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      final order = await store.createOrder(
        productCode: '500-0001',
        quantity: 10,
        priority: 'Media',
        operatorName: 'Tatiane',
        plannedStages: const [ProductionStage.testing],
      );
      await store.completeTesting(
        order.number,
        defects: const [
          DefectRecord(code: 'D01', title: 'Falha no teste', quantity: 2),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Defeitos da produção'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Registros locais dos testes'),
        findsOneWidget,
      );
      expect(find.text('D01 · Falha no teste'), findsOneWidget);
      expect(find.text('2 un'), findsOneWidget);
      expect(find.textContaining('Concluída'), findsNothing);
      expect(find.text('Enviar requisição'), findsNothing);
      expect(store.orders.single.currentStage, ProductionStage.completed);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
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
        return http.Response(
          jsonEncode({
            'total': 120,
            'databaseLatestRecord': '20260918',
            'summary': [],
            'items': [
              {
                'id': 'SD1:1',
                'source': 'SD1',
                'warehouse': r.url.queryParameters['local'],
                'code': '500-0001',
                'description': 'Placa para conserto',
                'quantity': 2,
                'unit': 'PC',
                'kind': 'receipt',
                'flow': 'none',
                'tes': '079',
                'affectsStock': 'N',
                'cfop': '2915',
                'date': '20260917',
                'document': '12345',
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
      MultiProvider(
        providers: [
          Provider.value(value: repo),
          ChangeNotifierProvider(create: (_) => ProductionFlowStore()),
          ChangeNotifierProvider(create: (_) => OperatorAssignmentStore()),
        ],
        child: const MaterialApp(home: SupportPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'support reads official records with only its two warehouses and preserves monthly filters',
    (tester) async {
      final requests = <Uri>[];
      await mount(tester, requests);
      expect(requests.last.path, '/api/v1/suporte');
      expect(requests.last.queryParameters['local'], '06');
      expect(requests.last.queryParameters.containsKey('start'), isFalse);
      expect(requests.last.queryParameters['page_size'], '8');
      expect(find.textContaining('18/09/2026'), findsOneWidget);
      expect(find.text('Iniciar conferência'), findsNothing);
      await tester.tap(find.text('Histórico'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Próxima página'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['page'], '2');
      await tester.tap(find.byKey(const ValueKey('period-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['end'], endsWith('-09-30'));
      expect(requests.last.queryParameters['page'], '1');
      await tester.tap(find.byKey(const ValueKey('warehouse-selector')));
      await tester.pumpAndSettle();
      expect(find.text('01 · Almoxarifado'), findsNothing);
      await tester.tap(find.text('07 · Suporte externo').last);
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['local'], '07');
      expect(requests.last.queryParameters['end'], endsWith('-09-30'));
      await tester.tap(find.text('Notas'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['kind'], 'fiscal');
      expect(find.text('Sem efeito no estoque'), findsOneWidget);
      await tester.tap(find.text('500-0001'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Referências do Protheus'));
      await tester.tap(find.text('Referências do Protheus'));
      await tester.pumpAndSettle();
      expect(find.text('079'), findsOneWidget);
      expect(find.text('2915'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'support fits mobile and current stock has no historical date filter',
    (tester) async {
      final requests = <Uri>[];
      await mount(tester, requests, mobile: true);
      await tester.ensureVisible(find.text('Estoque'));
      await tester.tap(find.text('Estoque'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['view'], 'stock');
      expect(find.text('Saldos atuais'), findsOneWidget);
      expect(find.byKey(const ValueKey('period-picker')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('support offers retry when DEV cannot be read', (tester) async {
    final requests = <Uri>[];
    await mount(tester, requests, fail: true);
    expect(find.text('Não foi possível carregar'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(requests.length, 2);
  });
}
