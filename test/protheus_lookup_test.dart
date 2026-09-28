import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/nova_op_dialog.dart';
import 'package:vetti_flow_1_0/data/models/protheus_product_lookup.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/flow_op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_product_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';

void main() {
  test('product lookup keeps VT branch and selected warehouse balances', () {
    const component = ProtheusProductComponent(
      code: '575-0863',
      description: 'SUB MEC SMART ALARM MONITORADA CENTRAL',
      quantityPerUnit: 2,
      unit: 'PC',
      filial: '04',
      armazem: '01',
      requirementSource: 'SD4',
      sourceOrder: '01595601001',
      originalQuantity: 20,
      commitmentQuantity: 10,
      stockAvailable: 8,
      warehouseBalances: [
        ProtheusWarehouseBalance(
          filial: '04',
          armazem: '01',
          currentStock: 20,
          committedQuantity: 6,
          reservedQuantity: 6,
          availableQuantity: 8,
        ),
        ProtheusWarehouseBalance(
          filial: '04',
          armazem: '02',
          currentStock: 50,
          committedQuantity: 5,
          reservedQuantity: 0,
          availableQuantity: 45,
        ),
      ],
    );

    final selected = component.selectWarehouse('02');

    expect(component.availableWarehouses, ['01', '02']);
    expect(selected.filial, '04');
    expect(selected.armazem, '02');
    expect(selected.stockAvailable, 45);
    expect(selected.requiredQuantityFor(12), 24);
    expect(selected.requirementSource, 'SD4');
    expect(selected.sourceOrder, '01595601001');
    expect(selected.originalQuantity, 20);
    expect(selected.commitmentQuantity, 10);
    expect(selected.toProductionComponent().armazem, '02');
    expect(selected.toProductionComponent().filial, '04');
    expect(selected.toProductionComponent().sourceOrder, '01595601001');
  });

  test(
    'component defaults to warehouse with real stock when preferred is zero',
    () {
      const balances = [
        ProtheusWarehouseBalance(
          filial: '04',
          armazem: '01',
          currentStock: 0,
          committedQuantity: 0,
          reservedQuantity: 0,
          availableQuantity: 0,
        ),
        ProtheusWarehouseBalance(
          filial: '04',
          armazem: '03',
          currentStock: 3796,
          committedQuantity: 1700,
          reservedQuantity: 0,
          availableQuantity: 3796,
        ),
      ];

      final selected = ProtheusProductComponent.selectBestWarehouseBalance(
        balances,
        '01',
      );

      expect(selected?.armazem, '03');
      expect(selected?.currentStock, 3796);
    },
  );

  test('support warehouses are never material source options', () {
    const component = ProtheusProductComponent(
      filial: '04',
      armazem: '05',
      code: '100-010',
      description: 'PARAFUSO',
      quantityPerUnit: 1,
      unit: 'PC',
      stockAvailable: 0,
      warehouseBalances: [
        ProtheusWarehouseBalance(
          filial: '04',
          armazem: '06',
          currentStock: 900,
          committedQuantity: 0,
          reservedQuantity: 0,
          availableQuantity: 900,
        ),
        ProtheusWarehouseBalance(
          filial: '04',
          armazem: '07',
          currentStock: 700,
          committedQuantity: 0,
          reservedQuantity: 0,
          availableQuantity: 700,
        ),
        ProtheusWarehouseBalance(
          filial: '04',
          armazem: '01',
          currentStock: 50,
          committedQuantity: 0,
          reservedQuantity: 0,
          availableQuantity: 50,
        ),
      ],
    );

    expect(WarehouseRouting.canSourceMaterialFromWarehouse('06'), isFalse);
    expect(WarehouseRouting.canSourceMaterialFromWarehouse('07'), isFalse);
    expect(
      component.warehousesThatCanCover(10).map((balance) => balance.armazem),
      ['01'],
    );
    expect(
      ProtheusProductComponent.selectBestWarehouseBalance(
        component.warehouseBalances,
        '06',
      )?.armazem,
      '01',
    );
  });

  test('MOD components can have negative stock without creating shortage', () {
    const component = ProtheusProductComponent(
      code: 'MOD-0001',
      description: 'MAO DE OBRA',
      quantityPerUnit: 1,
      unit: 'HR',
      stockAvailable: -999,
      currentStock: -999,
    );

    const lookup = ProtheusProductLookup(
      product: ProtheusProduct(
        code: '730-0863',
        description: 'SMART ALARM - MONITORADA CENTRAL',
        type: 'PA',
        unit: 'PC',
        group: '730',
      ),
      components: [component],
    );

    expect(component.shouldValidateStock, isFalse);
    expect(component.hasEnoughStockFor(10), isTrue);
    expect(component.missingQuantityFor(10), 0);
    expect(lookup.stockShortagesFor(10), isEmpty);
  });

  test('blocked SB1 products are hidden from final app repository', () async {
    final store = ProductionFlowStore();
    final repository = FlowOpRepository(
      store,
      protheusProducts: const _BlockedProductProtheusRepository(),
    );

    final products = await repository.searchProdutos('');
    final labels = await repository.fetchProdutos();
    final blockedLookup = await repository.lookupProdutoPorCodigo('730-BLOCK');
    final availableLookup = await repository.lookupProdutoPorCodigo('730-OK');

    expect(products.map((product) => product.code), ['730-OK']);
    expect(labels, ['730-OK - PRODUTO LIBERADO']);
    expect(blockedLookup, isNull);
    expect(availableLookup?.product.code, '730-OK');
  });

  test('Protheus product lookup does not read SD4 as component fallback', () {
    final source = File(
      'lib/data/repositories/protheus_product_repository.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('vw_sd4_commitments')));
    expect(source, isNot(contains('_commitmentsFor')));
    expect(source, isNot(contains("'SD4' AS requirement_source")));
  });

  test('API repository decodes product lookup from FastAPI', () async {
    final repository = ApiProtheusProductRepository(
      baseUrl: 'http://api.local',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/produtos/730-0863');
        return http.Response(
          jsonEncode({
            'filial': '04',
            'armazem': '05',
            'product': {
              'filial': '04',
              'code': '730-0863',
              'description': 'SMART ALARM - MONITORADA CENTRAL',
              'type': 'PA',
              'unit': 'PC',
              'group': '730',
              'screenBlock': '2',
            },
            'components': [
              {
                'filial': '04',
                'armazem': '01',
                'code': '100-010',
                'description': 'PARAFUSO',
                'quantityPerUnit': 2,
                'unit': 'PC',
                'stockAvailable': 7514,
                'currentStock': 7514,
                'committedQuantity': 100,
                'reservedQuantity': 0,
                'requirementSource': 'SG1',
                'structureSequence': '010',
                'warehouseBalances': [
                  {
                    'filial': '04',
                    'armazem': '01',
                    'currentStock': 7514,
                    'committedQuantity': 100,
                    'reservedQuantity': 0,
                    'availableQuantity': 7514,
                  },
                  {
                    'filial': '04',
                    'armazem': '05',
                    'currentStock': 3803,
                    'committedQuantity': 5484,
                    'reservedQuantity': 0,
                    'availableQuantity': 3803,
                  },
                ],
                'childOrders': [
                  {
                    'number': '01595801001',
                    'productCode': '575-0863',
                    'productDescription': 'SUB MEC',
                    'plannedQuantity': 10,
                    'producedQuantity': 0,
                    'status': 'N',
                  },
                ],
              },
            ],
            'smdReleaseOrders': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final lookup = await repository.lookupByCode('730-0863');

    expect(lookup?.product.code, '730-0863');
    expect(lookup?.defaultWarehouse, '05');
    expect(lookup?.components.single.code, '100-010');
    expect(lookup?.components.single.currentStock, 7514);
    expect(lookup?.components.single.structureSequence, '010');
    expect(lookup?.components.single.warehouseBalances.last.armazem, '05');
    expect(lookup?.components.single.childOrders.single.number, '01595801001');
  });

  test('API repository sends configured token header', () async {
    final repository = ApiProtheusProductRepository(
      baseUrl: 'http://api.local',
      apiToken: 'segredo-teste',
      httpClient: MockClient((request) async {
        expect(request.headers['X-API-Token'], 'segredo-teste');
        return http.Response(
          jsonEncode({
            'filial': '04',
            'armazem': '05',
            'product': {
              'filial': '04',
              'code': '730-0863',
              'description': 'SMART ALARM',
              'type': 'PA',
              'unit': 'PC',
              'group': '730',
            },
            'components': [],
            'smdReleaseOrders': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await repository.lookupByCode('730-0863');
  });

  test('product lookup exposes components and child OPs for a code', () {
    const lookup = ProtheusProductLookup(
      product: ProtheusProduct(
        code: '730-0863',
        description: 'SMART ALARM - MONITORADA CENTRAL',
        type: 'PA',
        unit: 'PC',
        group: '730',
      ),
      components: [
        ProtheusProductComponent(
          code: '575-0863',
          description: 'SUB MEC SMART ALARM MONITORADA CENTRAL',
          quantityPerUnit: 1,
          unit: 'PC',
          stockAvailable: 10,
          childOrders: [
            ProtheusChildOrder(
              number: '015958-01-001',
              productCode: '575-0863',
              productDescription: 'SUB MEC SMART ALARM MONITORADA CENTRAL',
              plannedQuantity: 10,
              producedQuantity: 0,
              status: 'N',
            ),
          ],
        ),
      ],
    );

    expect(lookup.label, '730-0863 - SMART ALARM - MONITORADA CENTRAL');
    expect(lookup.hasRamifications, isTrue);
    expect(lookup.components.single.hasChildOrders, isTrue);
    expect(lookup.toProductionComponents().single.code, '575-0863');
  });

  test(
    'flow repository creates a local OP using a Protheus product lookup',
    () async {
      final store = ProductionFlowStore();
      final repository = FlowOpRepository(
        store,
        protheusProducts: const _FakeProtheusProductRepository(),
      );

      final created = await repository.criarOrdem(
        const NovaOrdemDTO(
          produto: '730-0863',
          productCode: '730-0863',
          productName: 'SMART ALARM - MONITORADA CENTRAL',
          operatorPin: '2001',
          components: [
            ProtheusProductComponent(
              code: '575-0863',
              description: 'SUB MEC SMART ALARM MONITORADA CENTRAL',
              quantityPerUnit: 1,
              unit: 'PC',
              stockAvailable: 20,
            ),
          ],
          smdReleaseOrders: [
            ProtheusChildOrder(
              number: '015957-01-001',
              productCode: '500-0863',
              productDescription: 'SUB SMD SMART ALARM MONITORADA CENTRAL',
              plannedQuantity: 10,
              producedQuantity: 10,
              status: 'N',
            ),
          ],
          qtd: 12,
          responsavel: 'Tatiane',
          prazo: '31/07/2026',
        ),
      );

      final flowOrder = store.orders.firstWhere(
        (order) => order.number == created.numero,
      );

      expect(flowOrder.productCode, '730-0863');
      expect(flowOrder.productName, 'SMART ALARM - MONITORADA CENTRAL');
      expect(store.catalogItem('730-0863').components.single.code, '575-0863');
      expect(
        created.materiais.single.$1,
        'SUB MEC SMART ALARM MONITORADA CENTRAL',
      );
    },
  );

  test('flow repository requires PIN for Protheus stock movements', () async {
    final store = ProductionFlowStore();
    final repository = FlowOpRepository(
      store,
      protheusProducts: const _FakeProtheusProductRepository(),
    );

    expect(
      () => repository.criarOrdem(
        const NovaOrdemDTO(
          produto: '730-0863',
          productCode: '730-0863',
          productName: 'SMART ALARM - MONITORADA CENTRAL',
          components: [
            ProtheusProductComponent(
              code: '575-0863',
              description: 'SUB MEC SMART ALARM MONITORADA CENTRAL',
              quantityPerUnit: 1,
              unit: 'PC',
              stockAvailable: 20,
            ),
          ],
          qtd: 12,
          responsavel: 'Tatiane',
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  testWidgets('new OP dialog auto-fills product from Protheus code', (
    tester,
  ) async {
    NovaOrdemDTO? created;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NovaOpDialog(
            produtos: const ['CR4 - Modulo de 4 zonas com fio'],
            responsaveis: const ['Tatiane'],
            onLookupProduto:
                const _FakeProtheusProductRepository().lookupByCode,
            onSearchProdutos:
                const _FakeProtheusProductRepository().searchProducts,
            onCreate: (dto) => created = dto,
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('nova-op-product-code')),
      '730-0863',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(
      find.text('730-0863 - SMART ALARM - MONITORADA CENTRAL'),
      findsWidgets,
    );
    expect(find.textContaining('1 componente'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('nova-op-due-date')),
      '31/07/2026',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Estoque insuficiente'), findsNothing);
    expect(find.textContaining('Produto sem OP SMD'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('nova-op-operator-pin')));
    await tester.enterText(
      find.byKey(const Key('nova-op-operator-pin')),
      '2001',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Criar OP'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Criar OP'));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.productCode, '730-0863');
    expect(created!.productName, 'SMART ALARM - MONITORADA CENTRAL');
    expect(created!.components.single.code, '575-0863');
  });

  test('flow repository creates Protheus OP without SMD release', () async {
    final store = ProductionFlowStore();
    final repository = FlowOpRepository(
      store,
      protheusProducts: const _FakeProtheusProductRepository(),
    );

    final created = await repository.criarOrdem(
      const NovaOrdemDTO(
        produto: '730-0863',
        productCode: '730-0863',
        productName: 'SMART ALARM - MONITORADA CENTRAL',
        operatorPin: '2001',
        components: [
          ProtheusProductComponent(
            code: '575-0863',
            description: 'SUB MEC SMART ALARM MONITORADA CENTRAL',
            quantityPerUnit: 1,
            unit: 'PC',
            stockAvailable: 20,
          ),
        ],
        qtd: 12,
        responsavel: 'Tatiane',
        prazo: '31/07/2026',
      ),
    );

    expect(created.numero, startsWith('OP-'));
  });

  test(
    'flow repository lets any operator create OP in any warehouse',
    () async {
      final store = ProductionFlowStore();
      final repository = FlowOpRepository(
        store,
        protheusProducts: const _FakeProtheusProductRepository(),
      );

      final createdByVera = await repository.criarOrdem(
        const NovaOrdemDTO(
          produto: '730-0863',
          productCode: '730-0863',
          productName: 'SMART ALARM - MONITORADA CENTRAL',
          openedBy: 'Vera',
          operatorPin: '4003',
          armazem: '05',
          components: [
            ProtheusProductComponent(
              code: '575-0863',
              description: 'SUB MEC SMART ALARM MONITORADA CENTRAL',
              quantityPerUnit: 1,
              unit: 'PC',
              filial: '04',
              armazem: '05',
              stockAvailable: 20,
            ),
          ],
          smdReleaseOrders: [
            ProtheusChildOrder(
              number: '015957-01-001',
              productCode: '500-0863',
              productDescription: 'SUB SMD SMART ALARM MONITORADA CENTRAL',
              plannedQuantity: 10,
              producedQuantity: 10,
              status: 'N',
            ),
          ],
          qtd: 12,
          responsavel: 'Vera',
          prazo: '31/07/2026',
        ),
      );

      expect(createdByVera.numero, startsWith('OP-'));
      expect(createdByVera.armazem, '05');

      final created = await repository.criarOrdem(
        const NovaOrdemDTO(
          produto: '730-0863',
          productCode: '730-0863',
          productName: 'SMART ALARM - MONITORADA CENTRAL',
          openedBy: 'Tatiane',
          operatorPin: '2001',
          armazem: '05',
          components: [
            ProtheusProductComponent(
              code: '575-0863',
              description: 'SUB MEC SMART ALARM MONITORADA CENTRAL',
              quantityPerUnit: 1,
              unit: 'PC',
              filial: '04',
              armazem: '05',
              stockAvailable: 20,
            ),
          ],
          smdReleaseOrders: [
            ProtheusChildOrder(
              number: '015957-01-001',
              productCode: '500-0863',
              productDescription: 'SUB SMD SMART ALARM MONITORADA CENTRAL',
              plannedQuantity: 10,
              producedQuantity: 10,
              status: 'N',
            ),
          ],
          qtd: 12,
          responsavel: 'Tatiane',
          prazo: '31/07/2026',
        ),
      );

      expect(created.responsavel, '—');
      expect(created.stage, ProductionStage.firmware);
    },
  );

  test(
    'flow repository creates warehouse confirmation for external component',
    () async {
      final store = ProductionFlowStore();
      final requests = WarehouseRequestStore();
      final repository = FlowOpRepository(
        store,
        protheusProducts: const _FakeProtheusProductRepository(),
        warehouseRequests: requests,
      );

      final created = await repository.criarOrdem(
        const NovaOrdemDTO(
          produto: '730-0863',
          productCode: '730-0863',
          productName: 'SMART ALARM - MONITORADA CENTRAL',
          openedBy: 'Tatiane',
          operatorPin: '2001',
          armazem: '05',
          components: [
            ProtheusProductComponent(
              code: '575-0863',
              description: 'SUB MEC SMART ALARM MONITORADA CENTRAL',
              quantityPerUnit: 2,
              unit: 'PC',
              filial: '04',
              armazem: '01',
              stockAvailable: 80,
            ),
            ProtheusProductComponent(
              code: 'MOD-001',
              description: 'MAO DE OBRA SMD',
              quantityPerUnit: 1,
              unit: 'HR',
              filial: '04',
              armazem: '01',
              stockAvailable: -999,
            ),
          ],
          smdReleaseOrders: [
            ProtheusChildOrder(
              number: '015957-01-001',
              productCode: '500-0863',
              productDescription: 'SUB SMD SMART ALARM MONITORADA CENTRAL',
              plannedQuantity: 10,
              producedQuantity: 10,
              status: 'N',
            ),
          ],
          qtd: 12,
          responsavel: 'Tatiane',
          prazo: '31/07/2026',
        ),
      );

      expect(created.stage, ProductionStage.firmware);
      expect(requests.requests, hasLength(1));
      expect(requests.requests.single.orderNumber, created.numero);
      expect(requests.requests.single.componentCode, '575-0863');
      expect(requests.requests.single.requestedWarehouse, '01');
      expect(requests.requests.single.orderWarehouse, '05');
      expect(requests.requests.single.quantity, 24);
    },
  );

  test('flow repository lets Paula create SMD orders', () async {
    final store = ProductionFlowStore();
    final repository = FlowOpRepository(
      store,
      protheusProducts: const _FakeProtheusProductRepository(),
    );

    final created = await repository.criarOrdem(
      const NovaOrdemDTO(
        produto: '730-0863',
        productCode: '730-0863',
        productName: 'SMART ALARM - MONITORADA CENTRAL',
        openedBy: 'Paula',
        operatorPin: '4001',
        armazem: '03',
        components: [
          ProtheusProductComponent(
            code: '575-0863',
            description: 'SUB MEC SMART ALARM MONITORADA CENTRAL',
            quantityPerUnit: 1,
            unit: 'PC',
            filial: '04',
            armazem: '03',
            stockAvailable: 20,
          ),
        ],
        smdReleaseOrders: [
          ProtheusChildOrder(
            number: '015957-01-001',
            productCode: '500-0863',
            productDescription: 'SUB SMD SMART ALARM MONITORADA CENTRAL',
            plannedQuantity: 10,
            producedQuantity: 10,
            status: 'N',
          ),
        ],
        qtd: 12,
        responsavel: 'Paula',
        prazo: '31/07/2026',
      ),
    );

    expect(created.armazem, '03');
    expect(created.numero, startsWith('OP-'));
  });

  test('flow repository creates Protheus OP above stock', () async {
    final store = ProductionFlowStore();
    final repository = FlowOpRepository(
      store,
      protheusProducts: const _FakeProtheusProductRepository(),
    );

    final created = await repository.criarOrdem(
      const NovaOrdemDTO(
        produto: '730-0863',
        productCode: '730-0863',
        productName: 'SMART ALARM - MONITORADA CENTRAL',
        operatorPin: '2001',
        components: [
          ProtheusProductComponent(
            code: '575-0863',
            description: 'SUB MEC SMART ALARM MONITORADA CENTRAL',
            quantityPerUnit: 1,
            unit: 'PC',
            stockAvailable: 5,
          ),
        ],
        smdReleaseOrders: [
          ProtheusChildOrder(
            number: '015957-01-001',
            productCode: '500-0863',
            productDescription: 'SUB SMD SMART ALARM MONITORADA CENTRAL',
            plannedQuantity: 10,
            producedQuantity: 10,
            status: 'N',
          ),
        ],
        qtd: 12,
        responsavel: 'Tatiane',
        prazo: '31/07/2026',
      ),
    );

    expect(created.numero, startsWith('OP-'));
  });

  testWidgets('new OP dialog offers autocomplete by product description', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NovaOpDialog(
            produtos: const [],
            responsaveis: const ['Tatiane'],
            onLookupProduto:
                const _FakeProtheusProductRepository().lookupByCode,
            onSearchProdutos:
                const _FakeProtheusProductRepository().searchProducts,
            onCreate: (_) {},
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('nova-op-product-code')),
      'central',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('730-0863'), findsOneWidget);
    expect(find.text('SMART ALARM - MONITORADA CENTRAL'), findsOneWidget);

    await tester.tap(find.text('SMART ALARM - MONITORADA CENTRAL'));
    await tester.pumpAndSettle();

    expect(
      find.text('730-0863 - SMART ALARM - MONITORADA CENTRAL'),
      findsWidgets,
    );
  });

  testWidgets('new OP dialog shows all commitments and lets warehouse change', (
    tester,
  ) async {
    NovaOrdemDTO? created;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NovaOpDialog(
            produtos: const [],
            responsaveis: const ['Tatiane'],
            onLookupProduto:
                const _WarehouseProtheusProductRepository().lookupByCode,
            onSearchProdutos:
                const _WarehouseProtheusProductRepository().searchProducts,
            onCreate: (dto) => created = dto,
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('nova-op-product-code')),
      '730-0863',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Filial 04 - VT'), findsWidgets);
    expect(find.text('Armazém'), findsOneWidget);
    expect(find.text('Empenhos da OP'), findsOneWidget);
    expect(find.textContaining('COMP-005'), findsNothing);
    expect(find.textContaining('Sem escolhas pendentes'), findsWidgets);
    await tester.ensureVisible(find.textContaining('Detalhar'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Detalhar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('COMP-005'), findsWidgets);

    expect(find.textContaining('emp.'), findsNothing);
    expect(find.textContaining('res.'), findsNothing);
    expect(find.textContaining('disp.'), findsNothing);
    expect(find.textContaining('arm.'), findsNothing);

    await tester.enterText(find.byKey(const Key('nova-op-quantity')), '5');
    await tester.pumpAndSettle();
    expect(find.textContaining('disponível 45'), findsWidgets);
    await tester.ensureVisible(
      find.byKey(const Key('nova-op-component-warehouse-option-COMP-001-02')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('nova-op-component-warehouse-option-COMP-001-02')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('nova-op-operator-pin')));
    await tester.enterText(
      find.byKey(const Key('nova-op-operator-pin')),
      '2001',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Criar OP'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Criar OP'));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.filial, '04');
    expect(created!.armazem, '01');
    expect(created!.prazo, isNull);
    expect(created!.components, hasLength(5));
    expect(created!.components.first.armazem, '02');
  });

  testWidgets(
    'new OP dialog lets Tatiane create product stocked only in warehouse 01',
    (tester) async {
      NovaOrdemDTO? created;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: NovaOpDialog(
              produtos: const [],
              responsaveis: const ['Tatiane'],
              currentOperatorName: 'Tatiane',
              onLookupProduto:
                  const _OnlyWarehouseOneProtheusProductRepository()
                      .lookupByCode,
              onSearchProdutos:
                  const _OnlyWarehouseOneProtheusProductRepository()
                      .searchProducts,
              onCreate: (dto) => created = dto,
              onClose: () {},
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('nova-op-product-code')),
        '730-0779S',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('não tem armazém liberado'), findsNothing);
      expect(find.textContaining('Armazém 01 - Almoxarifado'), findsWidgets);
      expect(find.textContaining('Aviso:'), findsWidgets);

      await tester.ensureVisible(find.byKey(const Key('nova-op-operator-pin')));
      await tester.enterText(
        find.byKey(const Key('nova-op-operator-pin')),
        '2001',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Criar OP'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Criar OP'));
      await tester.pumpAndSettle();

      expect(created, isNotNull);
      expect(created!.armazem, '01');
      expect(created!.components.single.armazem, '01');
    },
  );

  testWidgets(
    'new OP dialog allows any operator to choose any order warehouse',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: NovaOpDialog(
              produtos: const [],
              responsaveis: const ['Tatiane'],
              currentOperatorName: 'Tatiane',
              onLookupProduto:
                  const _RestrictedWarehouseProtheusProductRepository()
                      .lookupByCode,
              onSearchProdutos:
                  const _RestrictedWarehouseProtheusProductRepository()
                      .searchProducts,
              onCreate: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('nova-op-product-code')),
        '730-0863',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Armazém 01 - Almoxarifado'), findsWidgets);
      expect(find.textContaining('Sem escolhas pendentes'), findsWidgets);

      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('nova-op-warehouse')));
      await tester.tap(find.byKey(const Key('nova-op-warehouse')));
      await tester.pumpAndSettle();

      expect(find.text('Armazém 03 - SMD'), findsOneWidget);
      expect(find.text('Armazém 05 - Produção'), findsOneWidget);
      expect(find.text('Armazém 10 - Expedição'), findsOneWidget);
    },
  );

  testWidgets('new OP dialog opens a future-only calendar for due date', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NovaOpDialog(
            produtos: const [],
            responsaveis: const ['Tatiane'],
            onLookupProduto:
                const _WarehouseProtheusProductRepository().lookupByCode,
            onSearchProdutos:
                const _WarehouseProtheusProductRepository().searchProducts,
            onCreate: (_) {},
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('nova-op-due-date')));
    await tester.tap(find.byKey(const Key('nova-op-due-date')));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarDatePicker), findsOneWidget);
  });

  testWidgets('new OP dialog lets a missing component use another warehouse', (
    tester,
  ) async {
    NovaOrdemDTO? created;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NovaOpDialog(
            produtos: const [],
            responsaveis: const ['Tatiane'],
            onLookupProduto:
                const _WarehouseProtheusProductRepository().lookupByCode,
            onSearchProdutos:
                const _WarehouseProtheusProductRepository().searchProducts,
            onCreate: (dto) => created = dto,
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('nova-op-product-code')),
      '730-0863',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nova-op-quantity')), '5');
    await tester.pumpAndSettle();

    expect(find.textContaining('precisa completar'), findsWidgets);
    await tester.ensureVisible(find.textContaining('Detalhar'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Detalhar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Almox. 01 tem'), findsWidgets);
    expect(find.text('Solicitar transferência'), findsOneWidget);
    expect(find.text('Escolha obrigatória'), findsOneWidget);
    expect(find.textContaining('02'), findsWidgets);
    expect(find.textContaining('disponível 45'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('nova-op-component-warehouse-option-COMP-001-02')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('nova-op-component-warehouse-option-COMP-001-02')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Selecionado: Armazém 02'), findsOneWidget);
    expect(find.text('Usa outro armazém'), findsOneWidget);
    expect(find.textContaining('02'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('nova-op-operator-pin')));
    await tester.enterText(
      find.byKey(const Key('nova-op-operator-pin')),
      '2001',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Criar OP'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Criar OP'));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.components.first.armazem, '02');
    expect(created!.components[1].armazem, '01');
  });

  testWidgets(
    'new OP dialog blocks creation until external warehouses are confirmed',
    (tester) async {
      NovaOrdemDTO? created;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: NovaOpDialog(
              produtos: const [],
              responsaveis: const ['Tatiane'],
              currentOperatorName: 'Tatiane',
              onLookupProduto:
                  const _MissClickWarehouseProtheusProductRepository()
                      .lookupByCode,
              onSearchProdutos:
                  const _MissClickWarehouseProtheusProductRepository()
                      .searchProducts,
              onCreate: (dto) => created = dto,
              onClose: () {},
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('nova-op-product-code')),
        '730-0863',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('precisa completar'), findsWidgets);
      await tester.ensureVisible(find.byKey(const Key('nova-op-operator-pin')));
      await tester.enterText(
        find.byKey(const Key('nova-op-operator-pin')),
        '2001',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Criar OP'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Criar OP'),
            )
            .onPressed,
        isNull,
      );
      expect(created, isNull);
      expect(find.textContaining('Confirme o armazém de origem'), findsWidgets);

      await tester.ensureVisible(find.textContaining('Detalhar'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Detalhar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Almox. 05 tem 0 disponível'), findsWidgets);
      await tester.ensureVisible(
        find.byKey(
          const Key('nova-op-component-warehouse-option-COMP-MISS-10'),
        ),
      );
      await tester.tap(
        find.byKey(
          const Key('nova-op-component-warehouse-option-COMP-MISS-10'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Criar OP'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Criar OP'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Criar OP'));
      await tester.pumpAndSettle();

      expect(created, isNotNull);
      expect(created!.components.single.armazem, '10');
    },
  );

  testWidgets('new OP dialog keeps component warehouse picker open after tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NovaOpDialog(
            produtos: const [],
            responsaveis: const ['Tatiane'],
            currentOperatorName: 'Tatiane',
            onLookupProduto:
                const _MissClickWarehouseProtheusProductRepository()
                    .lookupByCode,
            onSearchProdutos:
                const _MissClickWarehouseProtheusProductRepository()
                    .searchProducts,
            onCreate: (_) {},
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('nova-op-product-code')),
      '730-0863',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('precisa completar'), findsWidgets);
    await tester.ensureVisible(find.textContaining('Detalhar'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Detalhar'));
    await tester.pumpAndSettle();
    expect(find.text('Solicitar transferência'), findsOneWidget);
    expect(find.textContaining('10'), findsWidgets);

    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('nova-op-component-warehouse-option-COMP-MISS-10')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('nova-op-component-warehouse-option-COMP-MISS-10')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Selecionado: Armazém 10'), findsOneWidget);
    expect(find.textContaining('disponível 80'), findsWidgets);
  });

  testWidgets(
    'new OP dialog opens component warehouse menu with readable width',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: NovaOpDialog(
              produtos: const [],
              responsaveis: const ['Tatiane'],
              currentOperatorName: 'Tatiane',
              onLookupProduto:
                  const _MissClickWarehouseProtheusProductRepository()
                      .lookupByCode,
              onSearchProdutos:
                  const _MissClickWarehouseProtheusProductRepository()
                      .searchProducts,
              onCreate: (_) {},
              onClose: () {},
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('nova-op-product-code')),
        '730-0863',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Detalhar'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Detalhar'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('component-warehouse-COMP-MISS-05')),
      );
      await tester.tap(
        find.byKey(const ValueKey('component-warehouse-COMP-MISS-05')),
      );
      await tester.pumpAndSettle();

      final productionOption = find.text('Armazém 05 - Produção').last;
      expect(productionOption, findsOneWidget);
      expect(tester.getSize(productionOption).width, greaterThan(130));
      expect(find.text('Armazém 06 - Suporte'), findsNothing);
      expect(find.text('Armazém 07 - Suporte'), findsNothing);
    },
  );

  testWidgets('new OP dialog hides physical availability for MOD components', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NovaOpDialog(
            produtos: const [],
            responsaveis: const ['Tatiane'],
            onLookupProduto:
                const _ModOnlyProtheusProductRepository().lookupByCode,
            onSearchProdutos:
                const _ModOnlyProtheusProductRepository().searchProducts,
            onCreate: (_) {},
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('nova-op-product-code')),
      '900-MOD',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('MOD está como custo/mão de obra'),
      findsOneWidget,
    );
    expect(find.textContaining('Disponível:'), findsNothing);

    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Detalhar'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Detalhar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('MOD: custo/mão de obra'), findsOneWidget);
    expect(find.textContaining('Disponível:'), findsNothing);
  });
}

class _ModOnlyProtheusProductRepository implements ProtheusProductRepository {
  const _ModOnlyProtheusProductRepository();

  @override
  Future<List<String>> fetchProductLabels({int limit = 250}) async {
    return const ['900-MOD - PRODUTO COM MOD'];
  }

  @override
  Future<List<ProtheusProduct>> searchProducts(
    String query, {
    int limit = 12,
  }) async {
    return const [
      ProtheusProduct(
        filial: '04',
        code: '900-MOD',
        description: 'PRODUTO COM MOD',
        type: 'PA',
        unit: 'PC',
        group: '900',
      ),
    ];
  }

  @override
  Future<ProtheusProductLookup?> lookupByCode(String code) async {
    if (code != '900-MOD') return null;
    return const ProtheusProductLookup(
      filial: '04',
      armazem: '05',
      product: ProtheusProduct(
        filial: '04',
        code: '900-MOD',
        description: 'PRODUTO COM MOD',
        type: 'PA',
        unit: 'PC',
        group: '900',
      ),
      components: [
        ProtheusProductComponent(
          filial: '04',
          armazem: '05',
          code: 'MOD900',
          description: 'MAO DE OBRA PRODUCAO',
          quantityPerUnit: 1,
          unit: 'HR',
          stockAvailable: -999,
        ),
      ],
    );
  }
}

class _MissClickWarehouseProtheusProductRepository
    implements ProtheusProductRepository {
  const _MissClickWarehouseProtheusProductRepository();

  @override
  Future<List<String>> fetchProductLabels({int limit = 250}) async {
    return const ['730-0863 - SMART ALARM - MONITORADA CENTRAL'];
  }

  @override
  Future<List<ProtheusProduct>> searchProducts(
    String query, {
    int limit = 12,
  }) async {
    return const [
      ProtheusProduct(
        filial: '04',
        code: '730-0863',
        description: 'SMART ALARM - MONITORADA CENTRAL',
        type: 'PA',
        unit: 'PC',
        group: '730',
      ),
    ];
  }

  @override
  Future<ProtheusProductLookup?> lookupByCode(String code) async {
    if (code != '730-0863') return null;
    return const ProtheusProductLookup(
      filial: '04',
      armazem: '05',
      product: ProtheusProduct(
        filial: '04',
        code: '730-0863',
        description: 'SMART ALARM - MONITORADA CENTRAL',
        type: 'PA',
        unit: 'PC',
        group: '730',
      ),
      components: [
        ProtheusProductComponent(
          filial: '04',
          armazem: '01',
          code: 'COMP-MISS',
          description: 'Componente com opcao de retorno',
          quantityPerUnit: 1,
          unit: 'PC',
          stockAvailable: 0,
          warehouseBalances: [
            ProtheusWarehouseBalance(
              filial: '04',
              armazem: '01',
              currentStock: 100,
              committedQuantity: 0,
              reservedQuantity: 0,
              availableQuantity: 100,
            ),
            ProtheusWarehouseBalance(
              filial: '04',
              armazem: '05',
              currentStock: 0,
              committedQuantity: 0,
              reservedQuantity: 0,
              availableQuantity: 0,
            ),
            ProtheusWarehouseBalance(
              filial: '04',
              armazem: '10',
              currentStock: 80,
              committedQuantity: 0,
              reservedQuantity: 0,
              availableQuantity: 80,
            ),
            ProtheusWarehouseBalance(
              filial: '04',
              armazem: '06',
              currentStock: 900,
              committedQuantity: 0,
              reservedQuantity: 0,
              availableQuantity: 900,
            ),
            ProtheusWarehouseBalance(
              filial: '04',
              armazem: '07',
              currentStock: 700,
              committedQuantity: 0,
              reservedQuantity: 0,
              availableQuantity: 700,
            ),
          ],
        ),
      ],
    );
  }
}

class _RestrictedWarehouseProtheusProductRepository
    implements ProtheusProductRepository {
  const _RestrictedWarehouseProtheusProductRepository();

  @override
  Future<List<String>> fetchProductLabels({int limit = 250}) async {
    return const ['730-0863 - SMART ALARM - MONITORADA CENTRAL'];
  }

  @override
  Future<List<ProtheusProduct>> searchProducts(
    String query, {
    int limit = 12,
  }) async {
    return const [
      ProtheusProduct(
        filial: '04',
        code: '730-0863',
        description: 'SMART ALARM - MONITORADA CENTRAL',
        type: 'PA',
        unit: 'PC',
        group: '730',
      ),
    ];
  }

  @override
  Future<ProtheusProductLookup?> lookupByCode(String code) async {
    if (code != '730-0863') return null;
    return const ProtheusProductLookup(
      filial: '04',
      armazem: '01',
      product: ProtheusProduct(
        filial: '04',
        code: '730-0863',
        description: 'SMART ALARM - MONITORADA CENTRAL',
        type: 'PA',
        unit: 'PC',
        group: '730',
      ),
      components: [
        ProtheusProductComponent(
          filial: '04',
          armazem: '01',
          code: 'COMP-RESTRITO',
          description: 'Componente com varios armazens',
          quantityPerUnit: 1,
          unit: 'PC',
          stockAvailable: 20,
          warehouseBalances: [
            ProtheusWarehouseBalance(
              filial: '04',
              armazem: '01',
              currentStock: 20,
              committedQuantity: 0,
              reservedQuantity: 0,
              availableQuantity: 20,
            ),
            ProtheusWarehouseBalance(
              filial: '04',
              armazem: '05',
              currentStock: 30,
              committedQuantity: 0,
              reservedQuantity: 0,
              availableQuantity: 30,
            ),
            ProtheusWarehouseBalance(
              filial: '04',
              armazem: '10',
              currentStock: 40,
              committedQuantity: 0,
              reservedQuantity: 0,
              availableQuantity: 40,
            ),
          ],
        ),
      ],
      smdReleaseOrders: [
        ProtheusChildOrder(
          number: '015957-01-001',
          productCode: '500-0863',
          productDescription: 'SUB SMD SMART ALARM MONITORADA CENTRAL',
          plannedQuantity: 10,
          producedQuantity: 10,
          status: 'N',
        ),
      ],
    );
  }
}

class _OnlyWarehouseOneProtheusProductRepository
    implements ProtheusProductRepository {
  const _OnlyWarehouseOneProtheusProductRepository();

  @override
  Future<List<String>> fetchProductLabels({int limit = 250}) async {
    return const ['730-0779S - SMART SENSOR ABERTURA LR SHOX PRO S'];
  }

  @override
  Future<List<ProtheusProduct>> searchProducts(
    String query, {
    int limit = 12,
  }) async {
    return const [
      ProtheusProduct(
        filial: '04',
        code: '730-0779S',
        description: 'SMART SENSOR ABERTURA LR SHOX PRO S',
        type: 'PA',
        unit: 'PC',
        group: '730',
      ),
    ];
  }

  @override
  Future<ProtheusProductLookup?> lookupByCode(String code) async {
    if (code != '730-0779S') return null;
    return const ProtheusProductLookup(
      filial: '04',
      armazem: '01',
      product: ProtheusProduct(
        filial: '04',
        code: '730-0779S',
        description: 'SMART SENSOR ABERTURA LR SHOX PRO S',
        type: 'PA',
        unit: 'PC',
        group: '730',
      ),
      components: [
        ProtheusProductComponent(
          filial: '04',
          armazem: '01',
          code: '100-010',
          description: 'PARAFUSO 2,9 X 6,5 MM ZI',
          quantityPerUnit: 1,
          unit: 'PC',
          stockAvailable: 0,
          warehouseBalances: [
            ProtheusWarehouseBalance(
              filial: '04',
              armazem: '01',
              currentStock: 0,
              committedQuantity: 0,
              reservedQuantity: 0,
              availableQuantity: 0,
            ),
          ],
        ),
      ],
    );
  }
}

class _BlockedProductProtheusRepository implements ProtheusProductRepository {
  const _BlockedProductProtheusRepository();

  @override
  Future<List<String>> fetchProductLabels({int limit = 250}) async {
    return const ['730-BLOCK - PRODUTO BLOQUEADO', '730-OK - PRODUTO LIBERADO'];
  }

  @override
  Future<List<ProtheusProduct>> searchProducts(
    String query, {
    int limit = 12,
  }) async {
    return const [
      ProtheusProduct(
        filial: '04',
        code: '730-BLOCK',
        description: 'PRODUTO BLOQUEADO',
        type: 'PA',
        unit: 'PC',
        group: '730',
        screenBlock: '1',
      ),
      ProtheusProduct(
        filial: '04',
        code: '730-OK',
        description: 'PRODUTO LIBERADO',
        type: 'PA',
        unit: 'PC',
        group: '730',
        screenBlock: '2',
      ),
    ];
  }

  @override
  Future<ProtheusProductLookup?> lookupByCode(String code) async {
    if (code == '730-BLOCK') {
      return const ProtheusProductLookup(
        product: ProtheusProduct(
          filial: '04',
          code: '730-BLOCK',
          description: 'PRODUTO BLOQUEADO',
          type: 'PA',
          unit: 'PC',
          group: '730',
          screenBlock: '1',
        ),
      );
    }
    if (code == '730-OK') {
      return const ProtheusProductLookup(
        product: ProtheusProduct(
          filial: '04',
          code: '730-OK',
          description: 'PRODUTO LIBERADO',
          type: 'PA',
          unit: 'PC',
          group: '730',
          screenBlock: '2',
        ),
      );
    }
    return null;
  }
}

class _FakeProtheusProductRepository implements ProtheusProductRepository {
  const _FakeProtheusProductRepository();

  @override
  Future<List<String>> fetchProductLabels({int limit = 250}) async {
    return const ['730-0863 - SMART ALARM - MONITORADA CENTRAL'];
  }

  @override
  Future<List<ProtheusProduct>> searchProducts(
    String query, {
    int limit = 12,
  }) async {
    if (!'730-0863 SMART ALARM - MONITORADA CENTRAL'.toLowerCase().contains(
      query.toLowerCase(),
    )) {
      return const [];
    }
    return const [
      ProtheusProduct(
        code: '730-0863',
        description: 'SMART ALARM - MONITORADA CENTRAL',
        type: 'PA',
        unit: 'PC',
        group: '730',
      ),
    ];
  }

  @override
  Future<ProtheusProductLookup?> lookupByCode(String code) async {
    if (code != '730-0863') return null;
    return const ProtheusProductLookup(
      product: ProtheusProduct(
        code: '730-0863',
        description: 'SMART ALARM - MONITORADA CENTRAL',
        type: 'PA',
        unit: 'PC',
        group: '730',
      ),
      components: [
        ProtheusProductComponent(
          code: '575-0863',
          description: 'SUB MEC SMART ALARM MONITORADA CENTRAL',
          quantityPerUnit: 1,
          unit: 'PC',
          stockAvailable: 80,
        ),
      ],
      smdReleaseOrders: [
        ProtheusChildOrder(
          number: '015957-01-001',
          productCode: '500-0863',
          productDescription: 'SUB SMD SMART ALARM MONITORADA CENTRAL',
          plannedQuantity: 10,
          producedQuantity: 10,
          status: 'N',
        ),
      ],
    );
  }
}

class _WarehouseProtheusProductRepository implements ProtheusProductRepository {
  const _WarehouseProtheusProductRepository();

  @override
  Future<List<String>> fetchProductLabels({int limit = 250}) async {
    return const ['730-0863 - SMART ALARM - MONITORADA CENTRAL'];
  }

  @override
  Future<List<ProtheusProduct>> searchProducts(
    String query, {
    int limit = 12,
  }) async {
    return const [
      ProtheusProduct(
        filial: '04',
        code: '730-0863',
        description: 'SMART ALARM - MONITORADA CENTRAL',
        type: 'PA',
        unit: 'PC',
        group: '730',
      ),
    ];
  }

  @override
  Future<ProtheusProductLookup?> lookupByCode(String code) async {
    if (code != '730-0863') return null;
    return const ProtheusProductLookup(
      filial: '04',
      armazem: '01',
      product: ProtheusProduct(
        filial: '04',
        code: '730-0863',
        description: 'SMART ALARM - MONITORADA CENTRAL',
        type: 'PA',
        unit: 'PC',
        group: '730',
      ),
      components: [
        ProtheusProductComponent(
          filial: '04',
          armazem: '01',
          code: 'COMP-001',
          description: 'Empenho 1',
          quantityPerUnit: 2,
          unit: 'PC',
          stockAvailable: 8,
          warehouseBalances: [
            ProtheusWarehouseBalance(
              filial: '04',
              armazem: '01',
              currentStock: 20,
              committedQuantity: 6,
              reservedQuantity: 6,
              availableQuantity: 8,
            ),
            ProtheusWarehouseBalance(
              filial: '04',
              armazem: '02',
              currentStock: 50,
              committedQuantity: 5,
              reservedQuantity: 0,
              availableQuantity: 45,
            ),
          ],
        ),
        ProtheusProductComponent(
          filial: '04',
          armazem: '01',
          code: 'COMP-002',
          description: 'Empenho 2',
          quantityPerUnit: 1,
          unit: 'PC',
          stockAvailable: 8,
        ),
        ProtheusProductComponent(
          filial: '04',
          armazem: '01',
          code: 'COMP-003',
          description: 'Empenho 3',
          quantityPerUnit: 1,
          unit: 'PC',
          stockAvailable: 8,
        ),
        ProtheusProductComponent(
          filial: '04',
          armazem: '01',
          code: 'COMP-004',
          description: 'Empenho 4',
          quantityPerUnit: 1,
          unit: 'PC',
          stockAvailable: 8,
        ),
        ProtheusProductComponent(
          filial: '04',
          armazem: '01',
          code: 'COMP-005',
          description: 'Empenho 5',
          quantityPerUnit: 1,
          unit: 'PC',
          stockAvailable: 8,
        ),
      ],
      smdReleaseOrders: [
        ProtheusChildOrder(
          number: '015957-01-001',
          productCode: '500-0863',
          productDescription: 'SUB SMD SMART ALARM MONITORADA CENTRAL',
          plannedQuantity: 10,
          producedQuantity: 10,
          status: 'N',
        ),
      ],
    );
  }
}
