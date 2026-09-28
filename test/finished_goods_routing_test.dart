import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/models/finished_goods_routing.dart';

void main() {
  group('FinishedGoodsRouting', () {
    test(
      'separates OP, consumption and finished-goods warehouses for 05 -> 10',
      () {
        final suggestion = FinishedGoodsRouting.suggest(
          productCode: '575-0863',
          orderWarehouse: '05',
          componentWarehouses: const ['05', '01'],
        );

        expect(suggestion.orderWarehouse, '05');
        expect(suggestion.componentConsumptionWarehouse, '05');
        expect(suggestion.finishedGoodsWarehouse, '10');
        expect(suggestion.confidence, FinishedGoodsRoutingConfidence.high);
        expect(suggestion.canComplete, isTrue);
        expect(suggestion.reason, contains('historica 05 -> 10'));
      },
    );

    test(
      'keeps direct finished-goods destination when history is explicit',
      () {
        final suggestion = FinishedGoodsRouting.suggest(
          productCode: '730-0863',
          orderWarehouse: '05',
          componentWarehouses: const ['01'],
        );

        expect(suggestion.orderWarehouse, '05');
        expect(suggestion.componentConsumptionWarehouse, '01');
        expect(suggestion.finishedGoodsWarehouse, '05');
        expect(suggestion.canComplete, isTrue);
      },
    );

    test(
      'blocks completion when the finished-goods destination is uncertain',
      () {
        final suggestion = FinishedGoodsRouting.suggest(
          productCode: '999-0000',
          orderWarehouse: '02',
        );

        expect(suggestion.finishedGoodsWarehouse, isEmpty);
        expect(suggestion.confidence, FinishedGoodsRoutingConfidence.uncertain);
        expect(suggestion.canComplete, isFalse);
        expect(
          suggestion.warnings.single,
          contains('Destino do acabado incerto'),
        );
      },
    );

    test('records divergence against official Protheus movement history', () {
      final suggestion = FinishedGoodsRouting.suggest(
        productCode: '575-0863',
        orderWarehouse: '05',
      );

      final warnings = suggestion.compareOfficialFinishedGoodsWarehouse('05');

      expect(warnings.single, contains('sugerido 10'));
      expect(warnings.single, contains('oficial PR0 05'));
    });
  });

  group('ProductionFlowStore expedition routing', () {
    test(
      'stores the resolved finished-goods warehouse on local completion',
      () async {
        final store = ProductionFlowStore(
          seedOrders: [
            ProductionOrderFlow(
              number: 'OP-2026-565700',
              productCode: '575-0863',
              productName: 'PRODUTO COM HISTORICO 05 10',
              quantity: 8,
              currentStage: ProductionStage.expedition,
              status: ProductionRunStatus.waiting,
              priority: 'Media',
              createdAt: DateTime(2026, 9, 9, 8),
              updatedAt: DateTime(2026, 9, 9, 10),
              orderWarehouse: '05',
            ),
          ],
        );

        await store.completeExpedition('OP-2026-565700', storedQuantity: 3);

        final completed = store.orders.single;
        expect(completed.currentStage, ProductionStage.storage);
        expect(completed.finishedGoodsWarehouse, '10');
        expect(completed.componentConsumptionWarehouse, '05');
        expect(
          completed.routingWarnings,
          contains(
            'Entrada do acabado sugerida pela regra historica 05 -> 10.',
          ),
        );
      },
    );

    test('does not complete locally when destination is uncertain', () async {
      final store = ProductionFlowStore(
        seedOrders: [
          ProductionOrderFlow(
            number: 'OP-2026-565701',
            productCode: '999-0000',
            productName: 'PRODUTO SEM HISTORICO',
            quantity: 8,
            currentStage: ProductionStage.expedition,
            status: ProductionRunStatus.waiting,
            priority: 'Media',
            createdAt: DateTime(2026, 9, 9, 8),
            updatedAt: DateTime(2026, 9, 9, 10),
            orderWarehouse: '02',
          ),
        ],
      );

      await expectLater(
        store.completeExpedition('OP-2026-565701', storedQuantity: 0),
        throwsA(isA<StateError>()),
      );

      expect(store.orders.single.currentStage, ProductionStage.expedition);
    });
  });
}
