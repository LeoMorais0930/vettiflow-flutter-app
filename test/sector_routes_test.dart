import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_request.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/flow_op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_persistence.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/ui/production/production_work_page.dart';

const prod = Operator(
  name: 'Produção',
  username: 'prod',
  password: '',
  pin: 'p',
  stage: WorkStage.testing,
  area: WorkArea.production,
);
const support = Operator(
  name: 'Suporte',
  username: 'support',
  password: '',
  pin: 's',
  stage: WorkStage.support,
  area: WorkArea.support,
);
const expedition = Operator(
  name: 'Expedição',
  username: 'exp',
  password: '',
  pin: 'e',
  stage: WorkStage.expedition,
  area: WorkArea.production,
);
const warehouse = Operator(
  name: 'Almox',
  username: 'warehouse',
  password: '',
  pin: 'w',
  stage: WorkStage.warehouse,
  area: WorkArea.warehouse,
);
const smd = Operator(
  name: 'Paula',
  username: 'smd',
  password: '',
  pin: 'smd',
  stage: WorkStage.smd,
  area: WorkArea.smd,
);
ProductionOrderFlow order({
  List<ProductionStage>? route,
  ProductionStage stage = ProductionStage.completed,
}) => ProductionOrderFlow(
  number: 'OP-ROTA',
  productCode: 'PROD',
  productName: 'Produto',
  quantity: 10,
  unit: 'PC',
  orderWarehouse: '05',
  plannedStages:
      route ??
      [
        ProductionStage.testing,
        ProductionStage.closing,
        ProductionStage.expedition,
      ],
  currentStage: stage,
  status: stage == ProductionStage.completed
      ? ProductionRunStatus.completed
      : ProductionRunStatus.waiting,
  priority: 'Normal',
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);
WarehouseConfirmationRequest material() => WarehouseConfirmationRequest(
  id: 'MAT',
  orderNumber: 'OP-ROTA',
  productCode: 'PROD',
  productName: 'Produto',
  componentCode: 'COMP',
  componentDescription: 'Componente',
  quantity: 10,
  unit: 'KG',
  filial: '04',
  orderWarehouse: '05',
  requestedWarehouse: '01',
  requestedBy: 'Produção',
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

Future<void> event(
  ProductionFlowStore store,
  String draft,
  DispatchAction action,
  num qty,
  Operator actor, {
  String? id,
  ProductionStage? stage,
}) => store.recordDispatchEvent(
  'OP-ROTA',
  draftId: draft,
  eventId:
      id ?? '$draft:${action.name}:${DateTime.now().microsecondsSinceEpoch}',
  action: action,
  quantity: qty,
  note: 'Conferido',
  operator: actor,
  returnStage: stage,
  reference: action == DispatchAction.ship ? 'PED-LOCAL-1' : '',
);
Future<void> prepare(
  ProductionFlowStore store,
  String id,
  String destination,
  num qty,
) => store.prepareProductionDispatch(
  'OP-ROTA',
  operator: prod,
  entryId: id,
  destination: destination,
  quantity: qty,
  reason: 'Teste do fluxo',
);
ProductionDispatchDraft draft(ProductionFlowStore store, String id) =>
    store.orders.single.dispatchDrafts.firstWhere((d) => d.id == id);
void conserve(ProductionDispatchDraft d) => expect(
  d.pendingDelivery +
      d.initialTransit +
      d.supportPending +
      d.supportRepaired +
      d.expeditionTransit +
      d.expeditionReady +
      d.stored +
      d.shipped +
      d.customerReturnTransit +
      d.returnTransit +
      d.returned +
      d.cancelledQuantity,
  closeTo(d.quantity, 1e-8),
);

void main() {
  test(
    'armazenamento parcial chega à gestão e saída total encerra a etapa expedição',
    () async {
      final store = ProductionFlowStore(
        seedOrders: [order(stage: ProductionStage.expedition)],
      );
      await prepare(store, 'exp', '10', 10);
      await event(store, 'exp', DispatchAction.deliver, 10, prod);
      await event(store, 'exp', DispatchAction.receive, 10, expedition);
      await event(store, 'exp', DispatchAction.store, 2.5, expedition);
      final rows = await FlowOpRepository(store).fetchOrdensArmazenadas();
      expect(rows.single.qtdArmazenadaLabel, '2,5 PC');
      expect(store.orders.single.currentStage, ProductionStage.expedition);
      await event(store, 'exp', DispatchAction.ship, 7.5, expedition);
      expect(store.orders.single.totalDispatchedQuantity, 7.5);
      expect(store.orders.single.currentStage, ProductionStage.completed);
      await event(store, 'exp', DispatchAction.unstore, 2.5, expedition);
      expect(await FlowOpRepository(store).fetchOrdensArmazenadas(), isEmpty);
      expect(
        order(
          stage: ProductionStage.expedition,
          route: [ProductionStage.expedition, ProductionStage.testing],
        ).readyForExpedition,
        false,
      );
      store.dispose();
    },
  );
  test(
    'almoxarifado, SMD opcional e sequência interna seguem a programação',
    () async {
      for (final withSmd in [true, false]) {
        final memory = Memory();
        final store = ProductionFlowStore(
          persistence: memory,
          seedOrders: [
            order(
              stage: ProductionStage.warehouse,
              route: [
                ProductionStage.warehouse,
                if (withSmd) ProductionStage.smd,
                ProductionStage.testing,
              ],
            ),
          ],
        );
        final materials = WarehouseRequestStore(seedRequests: [material()]);
        await expectLater(
          store.releaseWarehouseOrder(
            'OP-ROTA',
            operator: warehouse,
            requests: materials.requests,
          ),
          throwsStateError,
        );
        materials.confirm('MAT', warehouse);
        materials.separate('MAT', warehouse, 10);
        materials.deliver('MAT', warehouse, 10);
        await store.releaseWarehouseOrder(
          'OP-ROTA',
          operator: warehouse,
          requests: materials.requests,
        );
        expect(
          store.orders.single.warehouseReleases.single.operatorName,
          warehouse.name,
        );
        final restored = ProductionFlowStore(persistence: memory);
        expect(
          restored.orders.single.warehouseReleases.single.destination,
          withSmd ? ProductionStage.smd : ProductionStage.testing,
        );
        restored.dispose();
        expect(
          store.orders.single.currentStage,
          withSmd ? ProductionStage.smd : ProductionStage.testing,
        );
        if (withSmd) {
          await store.pointSmd(
            'OP-ROTA',
            operator: smd,
            entryId: 'smd',
            quantity: 10,
          );
          await store.completeSmd('OP-ROTA', operator: smd);
        }
        await store.startStage(
          'OP-ROTA',
          operatorName: prod.name,
          operatorPin: prod.pin,
        );
        await store.completeTesting(
          'OP-ROTA',
          operatorName: prod.name,
          operatorPin: prod.pin,
          defects: const [],
        );
        expect(store.orders.single.currentStage, ProductionStage.completed);
        expect(store.orders.single.dispatchedQuantity, 0);
        store.dispose();
        materials.dispose();
      }
    },
  );

  test(
    'material indisponível pode ser cancelado com motivo para liberar a OP',
    () async {
      final materials = WarehouseRequestStore(seedRequests: [material()]);
      materials.reject('MAT', warehouse, 'Sem saldo');
      materials.recordMaterialEvent(
        'MAT',
        warehouse,
        10,
        WarehouseMaterialAction.cancelled,
        eventId: 'cancel',
        note: 'Programação ajustada',
      );
      expect(materials.requests.single.remainingQuantity, 0);
      expect(() => materials.confirm('MAT', warehouse), throwsStateError);
      final store = ProductionFlowStore(
        seedOrders: [
          order(
            stage: ProductionStage.warehouse,
            route: [ProductionStage.warehouse, ProductionStage.testing],
          ),
        ],
      );
      await store.releaseWarehouseOrder(
        'OP-ROTA',
        operator: warehouse,
        requests: materials.requests,
      );
      expect(store.orders.single.currentStage, ProductionStage.testing);
      store.dispose();
      materials.dispose();
    },
  );

  test(
    'parciais percorrem suporte, reparo, expedição, armazenamento, despacho e retornos',
    () async {
      final memory = Memory();
      final start = DateTime.now().subtract(const Duration(hours: 1));
      final store = ProductionFlowStore(
        seedOrders: [
          order().copyWith(
            timings: {
              ProductionStage.testing: ProductionStageTiming(
                startedAt: start,
                completedAt: start.add(const Duration(minutes: 10)),
              ),
            },
          ),
        ],
        persistence: memory,
      );
      await prepare(store, 'support', '07', 3);
      await prepare(store, 'exp', '10', 7);
      await event(store, 'support', DispatchAction.deliver, 3, prod);
      await event(store, 'exp', DispatchAction.deliver, 7, prod);
      expect(store.orders.single.productionQuantity, 0);
      await event(store, 'support', DispatchAction.receive, 3, support);
      await event(store, 'exp', DispatchAction.receive, 7, expedition);
      await event(store, 'support', DispatchAction.diagnose, 0, support);
      await event(store, 'support', DispatchAction.repair, 2, support);
      await event(
        store,
        'support',
        DispatchAction.returnUnrepaired,
        1,
        support,
      );
      await event(
        store,
        'support',
        DispatchAction.sendToExpedition,
        2,
        support,
      );
      await event(
        store,
        'support',
        DispatchAction.receiveFromSupport,
        2,
        expedition,
      );
      await event(store, 'exp', DispatchAction.store, 4, expedition);
      await event(store, 'exp', DispatchAction.ship, 3, expedition);
      await event(store, 'support', DispatchAction.ship, 2, expedition);
      await event(store, 'exp', DispatchAction.unstore, 2, expedition);
      await event(store, 'exp', DispatchAction.ship, 2, expedition);
      await event(store, 'exp', DispatchAction.customerReturn, 2, expedition);
      await event(
        store,
        'exp',
        DispatchAction.receiveCustomerReturn,
        2,
        expedition,
      );
      await event(
        store,
        'exp',
        DispatchAction.returnFromExpedition,
        1,
        expedition,
      );
      await event(
        store,
        'support',
        DispatchAction.receiveReturn,
        1,
        prod,
        stage: ProductionStage.testing,
      );
      await event(
        store,
        'exp',
        DispatchAction.receiveReturn,
        1,
        prod,
        stage: ProductionStage.testing,
      );
      final current = store.orders.single;
      expect(current.productionQuantity, 2);
      expect(current.availableToPrepare, 2);
      expect(current.currentStage, ProductionStage.testing);
      expect(current.timingHistory[ProductionStage.testing], hasLength(1));
      expect(current.totalElapsed(DateTime.now()), const Duration(minutes: 10));
      expect(current.timings[ProductionStage.testing], isNull);
      for (final d in current.dispatchDrafts) {
        conserve(d);
      }
      final restored = ProductionFlowStore(persistence: memory);
      expect(restored.orders.single.productionQuantity, 2);
      expect(draft(restored, 'exp').stored, 2);
      expect(draft(restored, 'exp').expeditionReady, 1);
      expect(
        draft(restored, 'support').shipped + draft(restored, 'exp').shipped,
        5,
      );
      expect(
        restored.orders.single.timingHistory[ProductionStage.testing],
        hasLength(1),
      );
      await restored.startStage(
        'OP-ROTA',
        operatorName: prod.name,
        operatorPin: prod.pin,
      );
      await restored.completeTesting(
        'OP-ROTA',
        operatorName: prod.name,
        operatorPin: prod.pin,
        defects: const [],
      );
      expect(restored.orders.single.currentStage, ProductionStage.closing);
      expect(
        restored.orders.single.allTimings.where(
          (e) => e.key == ProductionStage.testing,
        ),
        hasLength(2),
      );
      store.dispose();
      restored.dispose();
    },
  );

  test(
    'destino recebe só o entregue; origem cancela só o restante; eventos são idempotentes',
    () async {
      final store = ProductionFlowStore(seedOrders: [order()]);
      await prepare(store, 's', '06', 10);
      await expectLater(
        event(store, 's', DispatchAction.receive, 1, support),
        throwsStateError,
      );
      await event(store, 's', DispatchAction.deliver, 4, prod, id: 'same');
      await event(store, 's', DispatchAction.deliver, 4, prod, id: 'same');
      expect(draft(store, 's').delivered, 4);
      await expectLater(
        event(store, 's', DispatchAction.deliver, 3, prod, id: 'same'),
        throwsStateError,
      );
      await expectLater(
        event(store, 's', DispatchAction.receive, 4, prod),
        throwsStateError,
      );
      await expectLater(
        event(store, 's', DispatchAction.repair, 1, support),
        throwsStateError,
      );
      await expectLater(
        event(store, 's', DispatchAction.receive, 5, support),
        throwsStateError,
      );
      await expectLater(
        store.cancelProductionDispatch(
          'OP-ROTA',
          operator: prod,
          entryId: 's',
          reason: 'Teste',
        ),
        throwsStateError,
      );
      await event(store, 's', DispatchAction.cancelRemaining, 6, prod);
      expect(store.orders.single.availableToPrepare, 6);
      await event(store, 's', DispatchAction.receive, 4, support);
      await event(store, 's', DispatchAction.repair, 1.5, support);
      await event(store, 's', DispatchAction.returnRepaired, 1.5, support);
      await expectLater(
        event(store, 's', DispatchAction.sendToExpedition, 1, support),
        throwsStateError,
      );
      await event(
        store,
        's',
        DispatchAction.receiveReturn,
        1.5,
        prod,
        stage: ProductionStage.testing,
      );
      expect(store.orders.single.productionQuantity, 7.5);
      expect(store.orders.single.availableToPrepare, 7.5);
      conserve(draft(store, 's'));
      for (final q in [0, -1, double.nan, double.infinity]) {
        await expectLater(
          event(store, 's', DispatchAction.returnUnrepaired, q, support),
          throwsStateError,
        );
      }
      store.dispose();
    },
  );

  test(
    'expedição aguarda fim da sequência; falha ao salvar não consome saldo',
    () async {
      final memory = Memory();
      final store = ProductionFlowStore(
        seedOrders: [
          order(
            stage: ProductionStage.testing,
            route: [ProductionStage.testing],
          ),
        ],
        persistence: memory,
      );
      await prepare(store, 'e', '10', 10);
      await expectLater(
        event(store, 'e', DispatchAction.deliver, 10, prod),
        throwsStateError,
      );
      await store.completeTesting('OP-ROTA', defects: const []);
      memory.fail = true;
      await expectLater(
        event(store, 'e', DispatchAction.deliver, 10, prod, id: 'retry'),
        throwsStateError,
      );
      expect(draft(store, 'e').events, isEmpty);
      expect(store.orders.single.productionQuantity, 10);
      memory.fail = false;
      await event(store, 'e', DispatchAction.deliver, 10, prod, id: 'retry');
      await event(store, 'e', DispatchAction.receive, 10, expedition);
      await expectLater(
        store.recordDispatchEvent(
          'OP-ROTA',
          draftId: 'e',
          eventId: 'ship',
          action: DispatchAction.ship,
          quantity: 1,
          note: 'Teste',
          operator: expedition,
        ),
        throwsStateError,
      );
      await event(store, 'e', DispatchAction.ship, 10, expedition);
      expect(draft(store, 'e').isFinished, isTrue);
      conserve(draft(store, 'e'));
      store.dispose();
    },
  );

  test(
    'materiais: recebimento, uso, devolução e cancelamento sem refazer entrega',
    () {
      final store = WarehouseRequestStore(seedRequests: [material()]);
      store.confirm('MAT', warehouse);
      store.separate('MAT', warehouse, 6);
      store.deliver('MAT', warehouse, 6);
      void record(WarehouseMaterialAction a, num q, Operator who, String id) =>
          store.recordMaterialEvent(
            'MAT',
            who,
            q,
            a,
            eventId: id,
            note: 'Conferido',
          );
      expect(
        () => record(WarehouseMaterialAction.received, 7, prod, 'bad'),
        throwsStateError,
      );
      record(WarehouseMaterialAction.received, 4, prod, 'receive');
      record(WarehouseMaterialAction.received, 4, prod, 'receive');
      record(WarehouseMaterialAction.used, 1, prod, 'use');
      record(WarehouseMaterialAction.returnSent, 2, prod, 'return');
      expect(store.requests.single.availableAtDestination, 1);
      record(
        WarehouseMaterialAction.returnReceived,
        2,
        warehouse,
        'return-receive',
      );
      expect(store.requests.single.returnedQuantity, 2);
      expect(
        () => record(WarehouseMaterialAction.returnSent, 2, prod, 'excess'),
        throwsStateError,
      );
      expect(
        () => record(WarehouseMaterialAction.received, 1, warehouse, 'wrong'),
        throwsStateError,
      );
      store.separate('MAT', warehouse, 2);
      record(WarehouseMaterialAction.unseparated, 2, warehouse, 'undo');
      record(WarehouseMaterialAction.cancelled, 4, warehouse, 'cancel');
      expect(store.requests.single.remainingQuantity, 0);
      expect(store.requests.single.toReceive, 2);
      expect(store.canReceiveAt('03', smd), isFalse);
      final restored = WarehouseConfirmationRequest.fromJson(
        store.requests.single.toJson(),
      );
      expect(restored.returnedQuantity, 2);
      expect(restored.events.last.id, 'cancel');
      store.dispose();
    },
  );

  testWidgets(
    'suporte recebe parcial pela tela; expedição vê o envio vindo do suporte',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = ProductionFlowStore(seedOrders: [order()]);
      await prepare(store, 's', '07', 3);
      await event(store, 's', DispatchAction.deliver, 3, prod);
      final actor = Operator.all.firstWhere(
        (o) => o.area == WorkArea.support && o.stage == WorkStage.support,
      );
      final assignments = OperatorAssignmentStore()
        ..authenticate(actor.username, actor.password);
      Widget app(String sector) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: assignments),
        ],
        child: MaterialApp(
          home: ProductionWorkPage(
            key: ValueKey(sector),
            destinationSector: sector,
          ),
        ),
      );
      await tester.pumpWidget(app('support'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar recebimento'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantidade'),
        '2',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo / conferência'),
        'Conferência parcial',
      );
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(draft(store, 's').received, 2);
      expect(find.text('No suporte · a reparar: 2 PC'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await event(store, 's', DispatchAction.repair, 1, support);
      await event(store, 's', DispatchAction.sendToExpedition, 1, support);
      final exp = Operator.all.firstWhere(
        (o) => o.stage == WorkStage.expedition,
      );
      assignments.authenticate(exp.username, exp.password);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(app('expedition'));
      await tester.pumpAndSettle();
      expect(find.text('OP-ROTA · Suporte · 07'), findsOneWidget);
      expect(find.text('Receber do suporte'), findsOneWidget);
      expect(find.text('Concluir reparo'), findsNothing);
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
    if (fail) throw StateError('Falha local');
    payload = value;
  }
}
