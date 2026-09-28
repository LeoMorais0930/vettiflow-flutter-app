import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/protheus_product_lookup.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_request.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_database.dart';
import 'package:vetti_flow_1_0/data/repositories/local_json_persistence.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_materials_page.dart';

const warehouse = Operator(
  name: 'Conferente',
  username: 'warehouse-test',
  password: '',
  pin: 'PIN-NAO-EXPORTAR',
  stage: WorkStage.warehouse,
  area: WorkArea.warehouse,
);
const production = Operator(
  name: 'Produção',
  username: 'production-test',
  password: '',
  pin: '',
  stage: WorkStage.testing,
  area: WorkArea.production,
);

WarehouseConfirmationRequest request() => WarehouseConfirmationRequest(
  id: 'test-01',
  orderNumber: 'OP-TESTE',
  productCode: 'PROD',
  productName: 'Produto',
  componentCode: 'MAT',
  componentDescription: 'Material',
  quantity: 2.5,
  unit: 'KG',
  filial: '04',
  orderWarehouse: '05',
  requestedWarehouse: '01',
  requestedBy: 'Produção',
  createdAt: DateTime(2026, 9, 25),
  updatedAt: DateTime(2026, 9, 25),
);

void main() {
  testWidgets(
    'pedido visível no desktop e celular com entrega parcial pela tela',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vera = Operator.all.firstWhere((o) => o.username == 'vera');
      final assignments = OperatorAssignmentStore()
        ..authenticate(vera.username, vera.password);
      final store = WarehouseRequestStore();
      final r = store.createManualRequest(
        productCode: 'PROD',
        productName: 'Produto',
        componentCode: 'MAT',
        componentDescription: 'Material',
        quantity: 2.5,
        unit: 'KG',
        filial: '04',
        orderWarehouse: '05',
        requestedWarehouse: '01',
        requestedBy: 'Produção',
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: assignments),
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider(create: (_) => ProductionFlowStore()),
          ],
          child: const MaterialApp(home: WarehouseMaterialsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar disponibilidade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar separação'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantidade desta vez'),
        '1,25',
      );
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar entrega'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantidade desta vez'),
        '0,5',
      );
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(store.requests.single.id, r.id);
      expect(store.requests.single.deliveredQuantity, 0.5);
      expect(find.text('Entrega parcial'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.text('Pedidos de materiais'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      assignments.dispose();
    },
  );
  test('entregas parciais respeitam o separado e preservam o histórico', () {
    final store = WarehouseRequestStore(seedRequests: [request()]);
    addTearDown(store.dispose);
    expect(() => store.deliver('test-01', warehouse, 1), throwsStateError);
    store.confirm('test-01', warehouse);
    store.separate('test-01', warehouse, 1.5);
    expect(() => store.deliver('test-01', warehouse, 2), throwsStateError);
    store.deliver('test-01', warehouse, 1, note: 'Recebido na produção');
    expect(store.requests.single.remainingQuantity, 1.5);
    expect(store.requests.single.readyToDeliver, 0.5);
    expect(store.requests.single.progressLabel, 'Entrega parcial');
    store.separate('test-01', warehouse, 1);
    store.deliver('test-01', warehouse, 1.5);
    expect(store.requests.single.isDelivered, isTrue);
    expect(store.requests.single.events, hasLength(5));
    expect(() => store.deliver('test-01', warehouse, 0.1), throwsStateError);
    expect(
      () => store.reject('test-01', warehouse, 'Não pode apagar entrega'),
      throwsStateError,
    );
  });

  test(
    'bloqueia outro setor, negativos, valores não finitos e falta sem motivo',
    () {
      final store = WarehouseRequestStore(seedRequests: [request()]);
      addTearDown(store.dispose);
      expect(() => store.confirm('test-01', production), throwsStateError);
      expect(() => store.reject('test-01', warehouse, ' '), throwsStateError);
      store.reject('test-01', warehouse, 'Aguardando reposição');
      store.confirm('test-01', warehouse);
      for (final value in [0, -1, double.nan, double.infinity, 3]) {
        expect(
          () => store.separate('test-01', warehouse, value),
          throwsStateError,
        );
      }
      expect(store.requests.single.events.first.note, 'Aguardando reposição');
      expect(store.requests.single.events, hasLength(2));
    },
  );

  test('salva e recupera entregas e unidade sem guardar PIN', () async {
    final storage = _MemoryStorage();
    final db = LocalWarehouseRequestDatabase(persistence: storage);
    final store = WarehouseRequestStore(
      database: db,
      seedRequests: [request()],
    );
    store.confirm('test-01', warehouse);
    store.separate('test-01', warehouse, 0.75);
    store.deliver('test-01', warehouse, 0.5);
    await Future<void>.delayed(Duration.zero);
    final restored = WarehouseRequestStore(database: db);
    await Future<void>.delayed(Duration.zero);
    expect(restored.requests.single.deliveredQuantity, 0.5);
    expect(restored.requests.single.readyToDeliver, 0.25);
    expect(restored.requests.single.unit, 'KG');
    expect(storage.payload, isNot(contains(warehouse.pin)));
    expect(
      (jsonDecode(storage.payload!) as List).single['events'],
      hasLength(3),
    );
    store.dispose();
    restored.dispose();
  });

  test('gera material fracionado sem obrigar SMD nem avançar a rota da OP', () {
    const component = ProtheusProductComponent(
      code: 'MAT',
      description: 'Material',
      quantityPerUnit: 0.125,
      stockAvailable: 10.75,
      unit: 'KG',
      filial: '04',
      armazem: '01',
    );
    final converted = component.toProductionComponent();
    expect(converted.quantity, 0.125);
    expect(converted.stock, 10.75);
    expect(converted.unit, 'KG');
    final store = WarehouseRequestStore();
    addTearDown(store.dispose);
    final order = ProductionOrderFlow(
      number: 'OP-ROTA',
      productCode: 'PROD',
      productName: 'Produto',
      quantity: 10,
      currentStage: ProductionStage.testing,
      status: ProductionRunStatus.waiting,
      priority: 'Normal',
      createdAt: DateTime(2026, 9, 25),
      updatedAt: DateTime(2026, 9, 25),
      orderWarehouse: '05',
      plannedStages: const [ProductionStage.testing, ProductionStage.closing],
    );
    final catalog = ProductionCatalogItem(
      code: 'PROD',
      name: 'Produto',
      defaultQuantity: 10,
      components: [
        converted,
        converted,
        const ProductionComponent(
          code: 'MOD-01',
          description: 'Mão de obra',
          quantity: 1,
          stock: 0,
          armazem: '01',
        ),
      ],
    );
    void create() => store.createForOrder(
      order: order,
      catalogItem: catalog,
      orderWarehouse: '05',
      requestedBy: 'Produção',
    );
    create();
    final id = store.requests.single.id;
    expect(store.requests.single.quantity, 2.5);
    store.confirm(id, warehouse);
    store.separate(id, warehouse, 2.5);
    store.deliver(id, warehouse, 2.5);
    create();
    expect(store.requests, hasLength(1));
    expect(store.requests.single.isDelivered, isTrue);
    expect(order.currentStage, ProductionStage.testing);
    expect(order.nextStage, ProductionStage.closing);
  });
}

class _MemoryStorage extends LocalJsonPersistence {
  _MemoryStorage() : super('warehouse-test');
  String? payload;
  @override
  String? read() => payload;
  @override
  void write(String value) {
    payload = value;
  }
}
