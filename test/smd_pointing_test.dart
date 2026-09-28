import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_persistence.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_database.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/ui/smd/smd_work_page.dart';

const paula = Operator(
  name: 'Paula teste',
  username: 'smd-test',
  password: '',
  pin: 'PIN-NAO-GRAVAR',
  stage: WorkStage.smd,
  area: WorkArea.smd,
);
const other = Operator(
  name: 'Outro setor',
  username: 'other-test',
  password: '',
  pin: '',
  stage: WorkStage.warehouse,
  area: WorkArea.warehouse,
);
ProductionOrderFlow order({
  List<ProductionStage> route = const [
    ProductionStage.smd,
    ProductionStage.testing,
  ],
}) => ProductionOrderFlow(
  number: 'SMD-TEST',
  productCode: 'PLACA',
  productName: 'Placa',
  quantity: 10,
  unit: 'PC',
  currentStage: route.first,
  plannedStages: route,
  status: ProductionRunStatus.waiting,
  priority: 'Normal',
  orderWarehouse: '03',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  test(
    'falha ao salvar permite tentar de novo sem duplicar quantidade',
    () async {
      final memory = _MemoryPersistence();
      final store = ProductionFlowStore(
        seedOrders: [order()],
        persistence: memory,
      );
      memory.fail = true;
      await expectLater(
        store.pointSmd(
          'SMD-TEST',
          operator: paula,
          entryId: 'retry',
          quantity: 2,
        ),
        throwsStateError,
      );
      expect(store.orders.single.smd.produced, 0);
      memory.fail = false;
      await store.pointSmd(
        'SMD-TEST',
        operator: paula,
        entryId: 'retry',
        quantity: 2,
      );
      expect(store.orders.single.smd.produced, 2);
      expect(store.orders.single.smd.entries, hasLength(1));
      store.dispose();
    },
  );
  test(
    'parciais, duplicidade, saldo e conclusão pela rota escolhida',
    () async {
      final memory = _MemoryPersistence();
      final store = ProductionFlowStore(
        seedOrders: [order()],
        persistence: memory,
      );
      await store.pointSmd(
        'SMD-TEST',
        operator: paula,
        entryId: 'p1',
        quantity: 2.5,
      );
      await store.pointSmd(
        'SMD-TEST',
        operator: paula,
        entryId: 'p1',
        quantity: 2.5,
      );
      expect(store.orders.single.smd.entries, hasLength(1));
      await expectLater(
        store.pointSmd('SMD-TEST', operator: paula, entryId: 'p1', quantity: 3),
        throwsStateError,
      );
      await expectLater(
        store.pointSmd('SMD-TEST', operator: paula, entryId: 'p2', quantity: 8),
        throwsStateError,
      );
      await expectLater(
        store.completeSmd('SMD-TEST', operator: paula),
        throwsStateError,
      );
      await expectLater(store.completeStage('SMD-TEST'), throwsStateError);
      expect(store.orders.single.currentStage, ProductionStage.smd);
      await store.pointSmd(
        'SMD-TEST',
        operator: paula,
        entryId: 'p2',
        quantity: 7.5,
      );
      expect(store.orders.single.currentStage, ProductionStage.smd);
      await store.completeSmd('SMD-TEST', operator: paula);
      expect(store.orders.single.currentStage, ProductionStage.testing);
      await expectLater(
        store.updatePlannedStages('SMD-TEST', [
          ProductionStage.testing,
          ProductionStage.smd,
        ]),
        throwsStateError,
      );
      expect(store.orders.single.smd.completedBy, paula.name);
      expect(store.orders.single.timings, isEmpty);
      expect(store.orders.single.operatorSessions, isEmpty);
      expect(memory.payload, isNot(contains(paula.pin)));
      final restored = ProductionFlowStore(persistence: memory);
      expect(restored.orders.single.smd.produced, 10);
      expect(restored.orders.single.unit, 'PC');
      expect(restored.orders.single.smd.completedAt, isNotNull);
      await expectLater(restored.regressStage('SMD-TEST'), throwsStateError);
      store.dispose();
      restored.dispose();
    },
  );

  test('SMD opcional, conta autorizada e quantidade válida', () async {
    final skipped = ProductionFlowStore(
      seedOrders: [
        order(route: const [ProductionStage.testing]),
      ],
    );
    await expectLater(
      skipped.pointSmd('SMD-TEST', operator: paula, entryId: 'p', quantity: 1),
      throwsStateError,
    );
    final store = ProductionFlowStore(seedOrders: [order()]);
    await expectLater(
      store.pointSmd('SMD-TEST', operator: other, entryId: 'p', quantity: 1),
      throwsStateError,
    );
    for (final quantity in [0, -1, double.nan, double.infinity]) {
      await expectLater(
        store.pointSmd(
          'SMD-TEST',
          operator: paula,
          entryId: 'p',
          quantity: quantity,
        ),
        throwsStateError,
      );
    }
    expect(store.orders.single.smd.entries, isEmpty);
    skipped.dispose();
    store.dispose();
  });

  test(
    'correção mantém original e devolve saldo, fim da rota não cria nova etapa',
    () async {
      final store = ProductionFlowStore(
        seedOrders: [
          order(route: const [ProductionStage.smd]),
        ],
      );
      await store.pointSmd(
        'SMD-TEST',
        operator: paula,
        entryId: 'p',
        quantity: 4,
      );
      await expectLater(
        store.reverseSmdPointing(
          'SMD-TEST',
          operator: paula,
          pointingId: 'p',
          reason: '',
        ),
        throwsStateError,
      );
      await store.reverseSmdPointing(
        'SMD-TEST',
        operator: paula,
        pointingId: 'p',
        reason: 'Quantidade incorreta',
      );
      await store.reverseSmdPointing(
        'SMD-TEST',
        operator: paula,
        pointingId: 'p',
        reason: 'Quantidade incorreta',
      );
      expect(store.orders.single.smd.entries, hasLength(2));
      expect(store.orders.single.smd.produced, 0);
      await store.pointSmd(
        'SMD-TEST',
        operator: paula,
        entryId: 'p2',
        quantity: 10,
      );
      await store.completeSmd('SMD-TEST', operator: paula);
      expect(store.orders.single.currentStage, ProductionStage.completed);
      await expectLater(
        store.reverseSmdPointing(
          'SMD-TEST',
          operator: paula,
          pointingId: 'p2',
          reason: 'Tardio',
        ),
        throwsStateError,
      );
      store.dispose();
    },
  );

  test('duplo envio simultâneo não perde histórico nem excede saldo', () async {
    final db = _SlowDatabase();
    final store = ProductionFlowStore(database: db, seedOrders: [order()]);
    final first = store.pointSmd(
      'SMD-TEST',
      operator: paula,
      entryId: 'p1',
      quantity: 6,
    );
    await expectLater(
      store.pointSmd('SMD-TEST', operator: paula, entryId: 'p2', quantity: 6),
      throwsStateError,
    );
    db.saved.complete();
    await first;
    expect(store.orders.single.smd.produced, 6);
    expect(store.orders.single.smd.entries, hasLength(1));
    store.dispose();
  });

  testWidgets(
    'Paula aponta na fila local e vê histórico no desktop e celular',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final account = Operator.all.firstWhere((o) => o.username == 'paula');
      final assignments = OperatorAssignmentStore()
        ..authenticate(account.username, account.password);
      final store = ProductionFlowStore(seedOrders: [order()]);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider.value(value: assignments),
            ChangeNotifierProvider(create: (_) => WarehouseRequestStore()),
          ],
          child: const MaterialApp(home: SmdWorkPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Após o SMD: Teste'), findsOneWidget);
      await tester.tap(find.text('Apontar produção'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantidade produzida agora'),
        '3,5',
      );
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(find.text('Restante: 6,5 PC'), findsOneWidget);
      await tester.tap(find.text('Histórico'));
      await tester.pumpAndSettle();
      expect(find.text('Produção apontada · 3,5 PC'), findsOneWidget);
      expect(find.text('Anular apontamento'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.text('Produção apontada · 3,5 PC'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      assignments.dispose();
    },
  );
}

class _MemoryPersistence extends ProductionFlowPersistence {
  String? payload;
  bool fail = false;
  @override
  String? read() => payload;
  @override
  void write(String value) {
    if (fail) throw StateError('Armazenamento indisponível');
    payload = value;
  }
}

class _SlowDatabase extends EmptyProductionFlowDatabase {
  final saved = Completer<void>();
  @override
  Future<void> saveOrder(
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem, {
    required String eventType,
  }) => saved.future;
}
