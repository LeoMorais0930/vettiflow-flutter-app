import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/flow_op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_read_repository.dart';
import 'package:vetti_flow_1_0/ui/production/production_read_page.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/nova_op_dialog.dart';
import 'package:vetti_flow_1_0/ui/production/production_route_field.dart';
import 'package:vetti_flow_1_0/ui/firmware/firmware_page.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'production managers can open the Protheus consultation from the dashboard shortcut',
    (tester) async {
      for (final username in ['tatiane', 'andressa', 'admin']) {
        final operator = Operator.all.firstWhere((o) => o.username == username);
        final assignments = OperatorAssignmentStore()
          ..authenticate(operator.username, operator.password);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: assignments,
            child: MaterialApp(
              home: const Scaffold(body: ProductionNavigationButton()),
              routes: {
                '/producao': (_) =>
                    const Scaffold(body: Text('Consulta da produção')),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Produção · Protheus'));
        await tester.pumpAndSettle();
        expect(find.text('Consulta da produção'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        assignments.dispose();
      }
    },
  );
  test('invalid or repeated stages do not create a local OP', () async {
    final store = ProductionFlowStore();
    for (final route in [
      [ProductionStage.completed],
      [ProductionStage.testing, ProductionStage.testing],
    ]) {
      await expectLater(
        store.createOrder(
          productCode: 'X',
          quantity: 3,
          priority: 'Media',
          operatorName: 'Tatiane',
          plannedStages: route,
        ),
        throwsArgumentError,
      );
      expect(store.orders, isEmpty);
    }
    store.dispose();
  });

  testWidgets('route picker reorders on mobile and cancel preserves the plan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    List<ProductionStage>? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionRouteField(
            stages: ProductionRouteField.available,
            onChanged: (stages) => chosen = stages,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('production-route')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Adiar Gravacao'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(chosen, isNull);
    await tester.tap(find.byKey(const ValueKey('production-route')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-testing')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-testing')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Antecipar Teste'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Usar sequência'));
    await tester.pumpAndSettle();
    expect(chosen!.first, ProductionStage.testing);
    expect(chosen!.last, ProductionStage.expedition);
    expect(tester.takeException(), isNull);
  });

  testWidgets('operator sees the actual end of the selected sequence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = ProductionFlowStore();
    await store.createOrder(
      productCode: 'X',
      quantity: 3,
      priority: 'Media',
      operatorName: 'Tatiane',
      plannedStages: const [ProductionStage.firmware],
    );
    final assignments = OperatorAssignmentStore();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: assignments),
        ],
        child: const MaterialApp(home: FirmwarePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fim da sequência'), findsOneWidget);
    expect(find.text('Soldagem'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    assignments.dispose();
  });
  test(
    'Tatiane and Andressa choose the first, intermediate and last stages at creation',
    () async {
      for (final name in ['Tatiane', 'Andressa']) {
        final store = ProductionFlowStore();
        final repository = FlowOpRepository(store);
        final created = await repository.criarOrdem(
          NovaOrdemDTO(
            produto: '500-001 - Placa',
            productCode: '500-001',
            armazem: '05',
            openedBy: name,
            qtd: 10,
            responsavel: '',
            plannedStages: const [
              ProductionStage.testing,
              ProductionStage.soldering,
            ],
          ),
        );
        expect(created.stage, ProductionStage.testing);
        await store.completeTesting(created.numero, defects: const []);
        expect(store.orders.single.currentStage, ProductionStage.soldering);
        await store.regressStage(created.numero);
        expect(store.orders.single.currentStage, ProductionStage.testing);
        await store.completeTesting(created.numero, defects: const []);
        await store.completeStage(created.numero);
        expect(store.orders.single.currentStage, ProductionStage.completed);
        expect(store.orders.single.status, ProductionRunStatus.completed);
        expect(store.orders.single.dispatchedQuantity, 0);
        expect(store.activeOrders, isEmpty);
        store.dispose();
      }
    },
  );

  test(
    'a one-stage OP finishes without inserting expedition or another stage',
    () async {
      final store = ProductionFlowStore();
      final order = await store.createOrder(
        productCode: 'X',
        quantity: 3,
        priority: 'Media',
        operatorName: 'Tatiane',
        plannedStages: const [ProductionStage.closing],
      );
      expect(order.currentStage, ProductionStage.closing);
      expect(order.nextStage, ProductionStage.completed);
      await store.completeClosing(order.number, closedQuantity: 3);
      expect(store.orders.single.status, ProductionRunStatus.completed);
      expect(store.orders.single.dispatchedQuantity, 0);
      store.dispose();
    },
  );

  testWidgets('new OP form sends the chosen sequence in its DTO', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    NovaOrdemDTO? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NovaOpDialog(
            produtos: const ['X - Placa'],
            responsaveis: const [],
            currentOperatorName: 'Tatiane',
            onCreate: (dto) => submitted = dto,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('production-route')));
    await tester.tap(find.byKey(const ValueKey('production-route')));
    await tester.pumpAndSettle();
    for (final stage in [
      ProductionStage.firmware,
      ProductionStage.soldering,
      ProductionStage.closing,
      ProductionStage.expedition,
    ]) {
      await tester.tap(find.byKey(ValueKey('route-${stage.name}')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Usar sequência'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Criar OP'));
    await tester.tap(find.text('Criar OP'));
    expect(submitted?.plannedStages, [ProductionStage.testing]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administrator can plan production without a name allowlist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    NovaOrdemDTO? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NovaOpDialog(
            produtos: const ['X - Placa'],
            responsaveis: const [],
            currentOperatorName: 'Artur Augusto',
            canPlanProduction: true,
            onCreate: (dto) => submitted = dto,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('production-route')));
    await tester.tap(find.byKey(const ValueKey('production-route')));
    await tester.pumpAndSettle();
    for (final stage in [
      ProductionStage.firmware,
      ProductionStage.soldering,
      ProductionStage.closing,
      ProductionStage.expedition,
    ]) {
      await tester.tap(find.byKey(ValueKey('route-${stage.name}')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Usar sequência'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Criar OP'));
    await tester.tap(find.text('Criar OP'));
    expect(submitted?.plannedStages, [ProductionStage.testing]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'production consultation includes linked movements outside 05 and retains month',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <Uri>[];
      final repo = WarehouseReadRepository(
        baseUrl: 'http://api',
        httpClient: MockClient((r) async {
          expect(r.method, 'GET');
          requests.add(r.url);
          return http.Response(
            jsonEncode({
              'items': r.url.queryParameters['view'] == 'orders'
                  ? []
                  : [
                      {
                        'code': '575-001',
                        'description': 'Produto acabado',
                        'warehouse': '10',
                        'op': '01600001001',
                        'cf': 'PR0',
                        'kind': 'production',
                        'flow': 'in',
                        'quantity': 0.5,
                        'unit': 'PC',
                        'date': '20260910',
                        'operator': 'TATIANE',
                      },
                    ],
              'total': 1,
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        Provider.value(
          value: repo,
          child: const MaterialApp(home: ProductionReadPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.last.path, '/api/v1/producao');
      expect(requests.last.queryParameters['status'], 'active');
      expect(find.byKey(const ValueKey('warehouse-selector')), findsNothing);
      await tester.tap(find.text('Apontamentos'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['kind'], 'production');
      expect(find.textContaining('Armazém 10'), findsWidgets);
      expect(find.text('0,5 PC'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('period-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Consumo'));
      await tester.pumpAndSettle();
      expect(
        requests.last.queryParameters['start']!.endsWith('-09-01'),
        isTrue,
      );
      expect(requests.last.queryParameters['end']!.endsWith('-09-30'), isTrue);
      expect(requests.last.queryParameters['kind'], 'consumption');
      expect(tester.takeException(), isNull);
    },
  );
}
