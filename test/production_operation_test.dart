import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_database.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_persistence.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/ui/production/production_work_page.dart';
import 'package:vetti_flow_1_0/ui/testing/testing_page.dart';

const actor = Operator(
  name: 'Operadora',
  username: 'op-test',
  password: '',
  pin: 'NAO-SALVAR-NO-PREPARO',
  stage: WorkStage.testing,
  area: WorkArea.production,
);
ProductionOrderFlow order({
  String number = 'OP-TEST',
  String warehouse = '05',
  ProductionStage stage = ProductionStage.testing,
  List<ProductionStage>? route,
}) => ProductionOrderFlow(
  number: number,
  productCode: 'PLACA',
  productName: 'Placa teste',
  quantity: 10,
  unit: 'PC',
  currentStage: stage,
  status: ProductionRunStatus.waiting,
  priority: 'Normal',
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
  orderWarehouse: warehouse,
  plannedStages: route ?? [ProductionStage.testing, ProductionStage.soldering],
  testDefects: const [
    DefectRecord(code: 'T1', title: 'Falha A', quantity: 9),
    DefectRecord(code: 'T2', title: 'Falha B', quantity: 8),
  ],
);

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  test(
    'divisão por destino não infere peças pelos defeitos e não avança etapas',
    () async {
      final memory = Memory();
      final database = CountingDatabase();
      final store = ProductionFlowStore(
        seedOrders: [order()],
        persistence: memory,
        database: database,
      );
      addTearDown(store.dispose);
      await store.prepareProductionDispatch(
        'OP-TEST',
        operator: actor,
        entryId: 'one',
        destination: '06',
        quantity: 2.5,
        reason: 'Conferência',
      );
      await store.prepareProductionDispatch(
        'OP-TEST',
        operator: actor,
        entryId: 'one',
        destination: '06',
        quantity: 2.5,
        reason: 'Conferência',
      );
      await store.prepareProductionDispatch(
        'OP-TEST',
        operator: actor,
        entryId: 'two',
        destination: '10',
        quantity: 7.5,
        reason: 'Lote final',
      );
      final current = store.orders.single;
      expect(current.dispatchDrafts.length, 2);
      expect(current.preparedQuantity, 10);
      expect(current.availableToPrepare, 0);
      expect(current.currentStage, ProductionStage.testing);
      expect(current.quantity, 10);
      expect(current.dispatchedQuantity, 0);
      expect(current.operatorSessions, isEmpty);
      expect(current.timings, isEmpty);
      expect(database.saves, 0);
      expect(memory.payload, isNot(contains(actor.pin)));
      await expectLater(
        store.prepareProductionDispatch(
          'OP-TEST',
          operator: actor,
          entryId: 'three',
          destination: '07',
          quantity: 1,
          reason: 'Excesso',
        ),
        throwsStateError,
      );
      await expectLater(
        store.prepareProductionDispatch(
          'OP-TEST',
          operator: actor,
          entryId: 'one',
          destination: '07',
          quantity: 2.5,
          reason: 'Conferência',
        ),
        throwsStateError,
      );
      await expectLater(
        store.completeExpedition('OP-TEST', storedQuantity: 0),
        throwsStateError,
      );
      await expectLater(store.cancelOrder('OP-TEST'), throwsStateError);
      final restored = ProductionFlowStore(persistence: memory);
      addTearDown(restored.dispose);
      expect(restored.orders.single.preparedQuantity, 10);
      expect(restored.orders.single.dispatchDrafts.first.destination, '06');
    },
  );

  test(
    'cancelamento preserva preparo original e libera apenas a quantidade cancelada',
    () async {
      final memory = Memory();
      final store = ProductionFlowStore(
        seedOrders: [order()],
        persistence: memory,
      );
      addTearDown(store.dispose);
      await store.prepareProductionDispatch(
        'OP-TEST',
        operator: actor,
        entryId: 'one',
        destination: '07',
        quantity: 4,
        reason: 'Análise',
      );
      await store.prepareProductionDispatch(
        'OP-TEST',
        operator: actor,
        entryId: 'two',
        destination: '10',
        quantity: 6,
        reason: 'Entrega',
      );
      await expectLater(
        store.cancelProductionDispatch(
          'OP-TEST',
          operator: actor,
          entryId: 'one',
          reason: '',
        ),
        throwsStateError,
      );
      await store.cancelProductionDispatch(
        'OP-TEST',
        operator: actor,
        entryId: 'one',
        reason: 'Destino incorreto',
      );
      await store.cancelProductionDispatch(
        'OP-TEST',
        operator: actor,
        entryId: 'one',
        reason: 'Tentativa repetida',
      );
      expect(store.orders.single.availableToPrepare, 4);
      final cancelled = store.orders.single.dispatchDrafts.first;
      expect(cancelled.quantity, 4);
      expect(cancelled.reason, 'Análise');
      expect(cancelled.cancellationReason, 'Destino incorreto');
      expect(cancelled.operatorUsername, actor.username);
      final restored = ProductionFlowStore(persistence: memory);
      expect(restored.orders.single.dispatchDrafts.first.isCancelled, isTrue);
      expect(restored.orders.single.availableToPrepare, 4);
      restored.dispose();
    },
  );

  test(
    'preparo valida função, OP, unidade, etapa e quantidade; falha local permite nova tentativa',
    () async {
      final memory = Memory();
      final store = ProductionFlowStore(
        seedOrders: [
          order(),
          order(number: 'SMD', stage: ProductionStage.smd),
        ],
        persistence: memory,
      );
      addTearDown(store.dispose);
      final paula = Operator.all.firstWhere((o) => o.username == 'paula');
      await expectLater(
        store.prepareProductionDispatch(
          'OP-TEST',
          operator: paula,
          entryId: 'one',
          destination: '10',
          quantity: 1,
          reason: 'Teste',
        ),
        throwsStateError,
      );
      for (final quantity in [0, -1, double.nan, double.infinity, 11]) {
        await expectLater(
          store.prepareProductionDispatch(
            'OP-TEST',
            operator: actor,
            entryId: 'one',
            destination: '10',
            quantity: quantity,
            reason: 'Teste',
          ),
          throwsStateError,
        );
      }
      await expectLater(
        store.prepareProductionDispatch(
          'SMD',
          operator: actor,
          entryId: 'one',
          destination: '10',
          quantity: 1,
          reason: 'Teste',
        ),
        throwsStateError,
      );
      await expectLater(
        store.prepareProductionDispatch(
          'OP-TEST',
          operator: actor,
          entryId: 'one',
          destination: '04',
          quantity: 1,
          reason: 'Teste',
        ),
        throwsStateError,
      );
      await expectLater(
        store.prepareProductionDispatch(
          'missing',
          operator: actor,
          entryId: 'one',
          destination: '10',
          quantity: 1,
          reason: 'Teste',
        ),
        throwsStateError,
      );
      memory.fail = true;
      await expectLater(
        store.prepareProductionDispatch(
          'OP-TEST',
          operator: actor,
          entryId: 'one',
          destination: '10',
          quantity: 1,
          reason: 'Teste',
        ),
        throwsStateError,
      );
      expect(store.orders.first.dispatchDrafts, isEmpty);
      memory.fail = false;
      await store.prepareProductionDispatch(
        'OP-TEST',
        operator: actor,
        entryId: 'one',
        destination: '10',
        quantity: 1,
        reason: 'Teste',
      );
      expect(store.orders.first.preparedQuantity, 1);
      expect(order(warehouse: '').canPrepareDispatch, isFalse);
    },
  );

  test('mutação concorrente da etapa não sobrescreve um preparo', () async {
    final database = SlowDatabase();
    final store = ProductionFlowStore(
      seedOrders: [order()],
      database: database,
    );
    addTearDown(store.dispose);
    final starting = store.startStage(
      'OP-TEST',
      operatorName: actor.name,
      operatorPin: actor.pin,
    );
    await expectLater(
      store.prepareProductionDispatch(
        'OP-TEST',
        operator: actor,
        entryId: 'one',
        destination: '10',
        quantity: 1,
        reason: 'Teste',
      ),
      throwsStateError,
    );
    database.pending.complete();
    await starting;
    await store.prepareProductionDispatch(
      'OP-TEST',
      operator: actor,
      entryId: 'one',
      destination: '10',
      quantity: 1,
      reason: 'Teste',
    );
    expect(store.orders.single.operatorSessions.single.isRunning, isTrue);
    expect(store.orders.single.preparedQuantity, 1);
  });

  test(
    'teste encerra a sessão assinada, mantém outros operadores e segue rota escolhida',
    () async {
      final store = ProductionFlowStore(seedOrders: [order()]);
      addTearDown(store.dispose);
      await store.startStage('OP-TEST', operatorName: 'A', operatorPin: 'a');
      await store.startStage('OP-TEST', operatorName: 'B', operatorPin: 'b');
      await store.completeTesting(
        'OP-TEST',
        operatorName: 'A',
        operatorPin: 'a',
        defects: const [
          DefectRecord(code: 'X', title: 'Ocorrência', quantity: 1),
        ],
      );
      expect(store.orders.single.currentStage, ProductionStage.testing);
      expect(store.orders.single.testDefects.last.code, 'X');
      expect(store.orders.single.operatorSessions.first.isCompleted, isTrue);
      expect(store.orders.single.operatorSessions.last.isRunning, isTrue);
      await store.completeTesting(
        'OP-TEST',
        operatorName: 'B',
        operatorPin: 'b',
        defects: const [],
      );
      expect(store.orders.single.currentStage, ProductionStage.soldering);
      expect(
        store.orders.single.operatorSessions.every((s) => s.isCompleted),
        isTrue,
      );
      await expectLater(
        store.completeTesting('OP-TEST', defects: const []),
        throwsStateError,
      );
    },
  );

  test(
    'concluir teste pausado desconta pausa da etapa e fecha seu histórico',
    () async {
      final start = DateTime.now().subtract(const Duration(minutes: 20));
      final paused = start.add(const Duration(minutes: 10));
      final store = ProductionFlowStore(
        seedOrders: [
          order().copyWith(
            status: ProductionRunStatus.paused,
            timings: {
              ProductionStage.testing: ProductionStageTiming(
                startedAt: start,
                pausedAt: paused,
              ),
            },
            operatorSessions: [
              ProductionOperatorSession(
                stage: ProductionStage.testing,
                operatorName: 'A',
                operatorPin: 'a',
                startedAt: start,
                pausedAt: paused,
              ),
            ],
            pauseEvents: [
              ProductionPauseEvent(
                stage: ProductionStage.testing,
                operatorName: 'A',
                operatorPin: 'a',
                createdAt: paused,
                reason: PauseReason.outro,
                producedQuantity: 2,
              ),
            ],
          ),
        ],
      );
      addTearDown(store.dispose);
      await store.completeTesting(
        'OP-TEST',
        operatorName: 'A',
        operatorPin: 'a',
        defects: const [],
      );
      final current = store.orders.single;
      expect(
        current.timings[ProductionStage.testing]!.elapsed(DateTime.now()),
        const Duration(minutes: 10),
      );
      expect(
        current.operatorSessions.single.elapsed(DateTime.now()),
        const Duration(minutes: 10),
      );
      expect(current.pauseEvents.single.resumedAt, isNotNull);
    },
  );

  test(
    'cancelamento em curso bloqueia preparo; remover outra OP não troca a atualização',
    () async {
      final deletingDb = SlowDeleteDatabase();
      final deletingStore = ProductionFlowStore(
        seedOrders: [order()],
        database: deletingDb,
      );
      final deleting = deletingStore.cancelOrder('OP-TEST');
      await expectLater(
        deletingStore.prepareProductionDispatch(
          'OP-TEST',
          operator: actor,
          entryId: 'one',
          destination: '10',
          quantity: 1,
          reason: 'Teste',
        ),
        throwsStateError,
      );
      deletingDb.pending.complete();
      await deleting;
      expect(deletingStore.orders, isEmpty);
      deletingStore.dispose();

      final database = SlowDatabase();
      final store = ProductionFlowStore(
        seedOrders: [
          order(number: 'A'),
          order(number: 'B'),
        ],
        database: database,
      );
      final starting = store.startStage(
        'B',
        operatorName: actor.name,
        operatorPin: actor.pin,
      );
      await store.cancelOrder('A');
      database.pending.complete();
      await starting;
      expect(store.orders.single.number, 'B');
      expect(store.orders.single.status, ProductionRunStatus.active);
      store.dispose();
    },
  );

  testWidgets(
    'produção abre a OP escolhida e preparos ficam visíveis por destino em tela estreita',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = ProductionFlowStore(
        seedOrders: [
          order(number: 'FIRST'),
          order(number: 'SECOND'),
        ],
      );
      final manager = Operator.all.firstWhere((o) => o.username == 'tatiane');
      final assignments = OperatorAssignmentStore()
        ..authenticate(manager.username, manager.password);
      Widget app(Widget home) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: assignments),
        ],
        child: MaterialApp(
          home: home,
          routes: {'/teste': (_) => const TestingPage()},
        ),
      );
      await tester.pumpWidget(app(const ProductionWorkPage()));
      await tester.pumpAndSettle();
      expect(find.text('Operação da produção'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Preparar envio').first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suporte · 06').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantidade'),
        '2,5',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo do envio'),
        'Conferir lote',
      );
      await tester.tap(find.text('Salvar preparo'));
      await tester.pumpAndSettle();
      expect(store.orders.first.preparedQuantity, 2.5);
      expect(
        find.text('2,5 PC · Preparado · entrega pendente'),
        findsOneWidget,
      );
      await tester.tap(find.text('Em produção'));
      await tester.pumpAndSettle();
      final opening = find.widgetWithText(FilledButton, 'Abrir etapa').last;
      await tester.ensureVisible(opening);
      await tester.pumpAndSettle();
      await tester.tap(opening);
      await tester.pumpAndSettle();
      expect(
        ModalRoute.of(
          tester.element(find.byType(TestingPage)),
        )!.settings.arguments,
        'SECOND',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await store.prepareProductionDispatch(
        'FIRST',
        operator: actor,
        entryId: 's',
        destination: '07',
        quantity: 4,
        reason: 'Análise do suporte',
      );
      await store.prepareProductionDispatch(
        'SECOND',
        operator: actor,
        entryId: 'e',
        destination: '10',
        quantity: 6,
        reason: 'Envio final',
      );
      tester.view.physicalSize = const Size(390, 844);
      final supportActor = Operator.all.firstWhere(
        (operator) => operator.username == 'bruno',
      );
      assignments.authenticate(supportActor.username, supportActor.password);
      await tester.pumpWidget(
        app(const ProductionWorkPage(destinationSector: 'support')),
      );
      await tester.pumpAndSettle();
      expect(find.text('FIRST · Suporte · 07'), findsOneWidget);
      expect(find.textContaining('SECOND'), findsNothing);
      expect(find.text('Cancelar preparo'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      assignments.dispose();
    },
  );
}

class Memory extends ProductionFlowPersistence {
  String? payload;
  bool fail = false;
  @override
  String? read() => payload;
  @override
  void write(String value) {
    if (fail) throw StateError('Falha ao salvar');
    payload = value;
  }
}

class SlowDeleteDatabase extends EmptyProductionFlowDatabase {
  final pending = Completer<void>();
  @override
  Future<void> deleteOrder(
    String number, {
    ProductionOrderFlow? order,
    ProductionCatalogItem? catalogItem,
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) => pending.future;
}

class CountingDatabase extends EmptyProductionFlowDatabase {
  int saves = 0;
  @override
  Future<void> saveOrder(
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem, {
    required String eventType,
  }) async {
    saves++;
  }
}

class SlowDatabase extends EmptyProductionFlowDatabase {
  final pending = Completer<void>();
  @override
  Future<void> saveOrder(
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem, {
    required String eventType,
  }) => pending.future;
}
