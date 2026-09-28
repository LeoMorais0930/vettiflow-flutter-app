import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/protheus_stock_movement.dart';

void main() {
  test(
    'plans SC2, SB2 and SD4 records for OP creation without SD3 consumption',
    () {
      final createdAt = DateTime(2026, 8, 3, 14, 30, 5);
      final order = ProductionOrderFlow(
        number: 'OP-2026-564351',
        productCode: '730-0863',
        productName: 'SMART ALARM - MONITORADA CENTRAL',
        quantity: 5,
        currentStage: ProductionStage.warehouse,
        status: ProductionRunStatus.waiting,
        priority: 'Media',
        createdAt: createdAt,
        updatedAt: createdAt,
        operatorName: 'Tatiane',
        operatorPin: '2001',
        responsavel: 'Tatiane',
        orderWarehouse: '05',
      );
      const catalogItem = ProductionCatalogItem(
        code: '730-0863',
        name: 'SMART ALARM - MONITORADA CENTRAL',
        defaultQuantity: 5,
        components: [
          ProductionComponent(
            code: '100-010',
            description: 'PARAFUSO 2,9 X 6,5 MM ZI',
            quantity: 2,
            stock: 3803,
            filial: '04',
            armazem: '05',
            currentStock: 3803,
            committedQuantity: 5284,
            requirementSource: 'SG1',
            structureSequence: '010',
          ),
          ProductionComponent(
            code: 'MOD-001',
            description: 'MAO DE OBRA',
            quantity: 1,
            stock: -999,
            filial: '04',
            armazem: '05',
          ),
        ],
      );

      final sc2 = ProtheusProductionOrder.fromOrder(order).sc2Payload;
      final plan = ProtheusStockMovementPlan.fromOrder(order, catalogItem);
      final sc2ProtheusColumns = sc2.keys.where(
        (key) =>
            key.startsWith('c2_') ||
            key == 'd_e_l_e_t_' ||
            key == 'r_e_c_d_e_l_' ||
            key == 'r_e_c_n_o_',
      );

      expect(sc2.keys.where((key) => key.startsWith('c2_')), hasLength(148));
      expect(sc2ProtheusColumns, hasLength(151));
      expect(sc2['c2_filial'], '04');
      expect(sc2['c2_num'], '564351');
      expect(sc2['c2_item'], '01');
      expect(sc2['c2_sequen'], '001');
      expect(sc2['c2_op'], '56435101001');
      expect(sc2['c2_produto'], '730-0863');
      expect(sc2['c2_quant'], 5);
      expect(sc2['c2_quje'], 0);
      expect(sc2['c2_um'], 'PC');
      expect(sc2['c2_local'], '05');
      expect(sc2['c2_status'], 'N');
      expect(sc2['c2_tpop'], 'F');
      expect(sc2['c2_tppr'], 'I');
      expect(sc2['c2_prior'], '500');
      expect(sc2['c2_blqapon'], '2');
      expect(sc2['c2_prodaut'], '2');
      expect(sc2['c2_opterce'], '2');
      expect(sc2['c2_diasoci'], 99);
      expect(sc2['c2_emissao'], '20260803');
      expect(sc2['c2_datpri'], '20260803');
      expect(sc2['c2_datprf'], '20260803');
      expect(sc2['vettiflow_order_number'], 'OP-2026-564351');
      expect(sc2['vettiflow_origin'], 'op_creation');

      expect(plan.movements, hasLength(2));
      expect(plan.totalCommittedByBalanceKey[('04', '100-010', '05')], 10);
      expect(
        plan.totalCommittedByBalanceKey.containsKey(('04', 'MOD-001', '05')),
        isFalse,
      );

      final movement = plan.movements.firstWhere(
        (item) => item.componentCode == '100-010',
      );
      expect(movement.quantity, 10);
      expect(movement.affectsStockBalance, isTrue);
      expect(movement.emissionDate, '20260803');

      expect(movement.sd4Payload['d4_filial'], '04');
      expect(movement.sd4Payload['d4_op'], '56435101001');
      expect(movement.sd4Payload['d4_produto'], '730-0863');
      expect(movement.sd4Payload['d4_cod'], '100-010');
      expect(movement.sd4Payload['d4_local'], '05');
      expect(movement.sd4Payload['d4_quant'], 10);
      expect(movement.sd4Payload['d4_qtdeori'], 10);
      expect(movement.sd4Payload['d4_sldemp'], 0);
      expect(movement.sd4Payload['d4_sldemp2'], 0);
      expect(movement.sd4Payload['d4_qtneces'], 0);
      expect(movement.sd4Payload['d4_roteiro'], '01');
      expect(movement.sd4Payload['d4_trt'], '010');
      expect(movement.sd4Payload['vettiflow_order_number'], 'OP-2026-564351');
      expect(movement.sd4Payload['vettiflow_operator_name'], 'Tatiane');
      expect(movement.sd4Payload['vettiflow_operator_pin'], '2001');

      final modMovement = plan.movements.firstWhere(
        (item) => item.componentCode == 'MOD-001',
      );
      expect(modMovement.quantity, 5);
      expect(modMovement.affectsStockBalance, isFalse);
      expect(modMovement.sd4Payload['d4_cod'], 'MOD-001');
      expect(modMovement.sd4Payload['d4_quant'], 5);
    },
  );

  test('uses the selected component warehouse in SB2 and SD4 commitments', () {
    final createdAt = DateTime(2026, 8, 4, 9, 10);
    final order = ProductionOrderFlow(
      number: 'OP-2026-564999',
      productCode: '730-0863',
      productName: 'SMART ALARM - MONITORADA CENTRAL',
      quantity: 4,
      currentStage: ProductionStage.warehouse,
      status: ProductionRunStatus.waiting,
      priority: 'Media',
      createdAt: createdAt,
      updatedAt: createdAt,
      responsavel: 'Tatiane',
    );
    const catalogItem = ProductionCatalogItem(
      code: '730-0863',
      name: 'SMART ALARM - MONITORADA CENTRAL',
      defaultQuantity: 4,
      components: [
        ProductionComponent(
          code: '100-010',
          description: 'PARAFUSO 2,9 X 6,5 MM ZI',
          quantity: 3,
          stock: 7514,
          filial: '04',
          armazem: '01',
          currentStock: 7514,
          requirementSource: 'SG1',
        ),
      ],
    );

    final plan = ProtheusStockMovementPlan.fromOrder(order, catalogItem);
    final movement = plan.movements.single;

    expect(plan.totalCommittedByBalanceKey[('04', '100-010', '01')], 12);
    expect(
      plan.totalCommittedByBalanceKey.containsKey(('04', '100-010', '05')),
      isFalse,
    );
    expect(movement.sd4Payload['d4_local'], '01');
    expect(movement.newSb2Payload['b2_local'], '01');
  });

  test('OP creation and stage advance do not write SD3 Protheus movements', () {
    final source = File(
      'lib/data/repositories/production_flow_database.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('await _insertSd3Movement(tx, movement);')));
    expect(
      source,
      isNot(contains('await _insertSd3StageTransfer(tx, order);')),
    );
  });

  test('fills SC2 product unit from the Protheus lookup', () {
    final createdAt = DateTime(2026, 8, 5, 8, 15);
    final order = ProductionOrderFlow(
      number: 'OP-2026-565010',
      productCode: '800-001',
      productName: 'PRODUTO EM METROS',
      quantity: 2,
      currentStage: ProductionStage.warehouse,
      status: ProductionRunStatus.waiting,
      priority: 'Media',
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final sc2 = ProtheusProductionOrder.fromOrder(order, unit: 'MT').sc2Payload;

    expect(sc2['c2_um'], 'MT');
  });

  test('plans SB2 and SD4 reversal records for OP cancelation', () {
    final createdAt = DateTime(2026, 8, 4, 9, 10);
    final canceledAt = DateTime(2026, 8, 4, 11, 20);
    final order = ProductionOrderFlow(
      number: 'OP-2026-565111',
      productCode: '730-0863',
      productName: 'SMART ALARM - MONITORADA CENTRAL',
      quantity: 4,
      currentStage: ProductionStage.warehouse,
      status: ProductionRunStatus.waiting,
      priority: 'Media',
      createdAt: createdAt,
      updatedAt: canceledAt,
      operatorName: 'Tatiane',
      operatorPin: '2001',
    );
    const catalogItem = ProductionCatalogItem(
      code: '730-0863',
      name: 'SMART ALARM - MONITORADA CENTRAL',
      defaultQuantity: 4,
      components: [
        ProductionComponent(
          code: '100-010',
          description: 'PARAFUSO 2,9 X 6,5 MM ZI',
          quantity: 3,
          stock: 7514,
          filial: '04',
          armazem: '01',
          currentStock: 7514,
          requirementSource: 'SG1',
        ),
        ProductionComponent(
          code: 'MOD-001',
          description: 'MAO DE OBRA',
          quantity: 1,
          stock: -999,
          filial: '04',
          armazem: '05',
        ),
      ],
    );

    final plan = ProtheusStockCancelationPlan.fromOrder(
      order,
      catalogItem,
      returnWarehouses: const {'100-010': '05'},
      operatorName: 'Vera',
      operatorPin: '4003',
    );

    expect(plan.movements, hasLength(2));
    expect(plan.totalReleasedByBalanceKey[('04', '100-010', '01')], 12);
    expect(
      plan.totalReleasedByBalanceKey.containsKey(('04', 'MOD-001', '05')),
      isFalse,
    );

    final movement = plan.movements.firstWhere(
      (item) => item.componentCode == '100-010',
    );
    expect(movement.quantity, 12);
    expect(movement.armazem, '01');
    expect(movement.returnWarehouse, '05');
    expect(movement.emissionDate, '20260804');
    expect(movement.sd4CancelPayload['d4_sldemp'], 0);
    expect(movement.sd4CancelPayload['d4_situaca'], 'D');
    expect(movement.sd4CancelPayload['d4_op'], '56511101001');
    expect(movement.sd4CancelPayload['d_e_l_e_t_'], '*');
    expect(movement.sd4CancelPayload['vettiflow_origin'], 'op_cancel');
    expect(movement.sd4CancelPayload['vettiflow_operator_name'], 'Vera');
    expect(movement.sd4CancelPayload['vettiflow_operator_pin'], '4003');
  });

  test('plans PR0 and RE1 only when production is completed', () {
    final createdAt = DateTime(2026, 8, 5, 8, 15);
    final completedAt = DateTime(2026, 8, 5, 16, 40);
    final order = ProductionOrderFlow(
      number: 'OP-2026-565222',
      productCode: '730-0863',
      productName: 'SMART ALARM - MONITORADA CENTRAL',
      quantity: 6,
      currentStage: ProductionStage.completed,
      status: ProductionRunStatus.completed,
      priority: 'Media',
      createdAt: createdAt,
      updatedAt: completedAt,
      operatorName: 'Tatiane',
      operatorPin: '2001',
      orderWarehouse: '05',
      closedQuantity: 4,
    );
    const catalogItem = ProductionCatalogItem(
      code: '730-0863',
      name: 'SMART ALARM - MONITORADA CENTRAL',
      defaultQuantity: 6,
      unit: 'PC',
      components: [
        ProductionComponent(
          code: '100-010',
          description: 'PARAFUSO 2,9 X 6,5 MM ZI',
          quantity: 2,
          stock: 3803,
          filial: '04',
          armazem: '01',
          structureSequence: '010',
        ),
        ProductionComponent(
          code: 'MOD-001',
          description: 'MAO DE OBRA',
          quantity: 1,
          stock: -999,
          filial: '04',
          armazem: '05',
        ),
      ],
    );

    final completion = ProtheusProductionCompletionPlan.fromOrder(
      order,
      catalogItem,
    );

    expect(completion.finishedProduct.quantity, 4);
    expect(completion.finishedProduct.sd3Payload['d3_cf'], 'PR0');
    expect(completion.finishedProduct.sd3Payload['d3_op'], '56522201001');
    expect(completion.finishedProduct.sd3Payload['d3_cod'], '730-0863');
    expect(completion.finishedProduct.sd3Payload['d3_local'], '05');
    expect(completion.consumptions, hasLength(2));

    final physicalConsumption = completion.consumptions.firstWhere(
      (item) => item.componentCode == '100-010',
    );
    expect(physicalConsumption.quantity, 8);
    expect(physicalConsumption.affectsStockBalance, isTrue);
    expect(physicalConsumption.sd3Payload['d3_cf'], 'RE1');
    expect(physicalConsumption.sd3Payload['d3_op'], '56522201001');
    expect(physicalConsumption.sd3Payload['d3_cod'], '100-010');
    expect(physicalConsumption.sd3Payload['d3_local'], '01');
    expect(physicalConsumption.sd3Payload['d3_numseq'], '010');

    final modConsumption = completion.consumptions.firstWhere(
      (item) => item.componentCode == 'MOD-001',
    );
    expect(modConsumption.quantity, 4);
    expect(modConsumption.affectsStockBalance, isFalse);
  });

  test('uses historical 05 -> 10 routing for finished-product PR0', () {
    final createdAt = DateTime(2026, 8, 5, 8, 15);
    final completedAt = DateTime(2026, 8, 5, 16, 40);
    final order = ProductionOrderFlow(
      number: 'OP-2026-565333',
      productCode: '575-0863',
      productName: 'PRODUTO COM HISTORICO 05 10',
      quantity: 6,
      currentStage: ProductionStage.completed,
      status: ProductionRunStatus.completed,
      priority: 'Media',
      createdAt: createdAt,
      updatedAt: completedAt,
      operatorName: 'Tatiane',
      operatorPin: '2001',
      orderWarehouse: '05',
      closedQuantity: 4,
    );
    const catalogItem = ProductionCatalogItem(
      code: '575-0863',
      name: 'PRODUTO COM HISTORICO 05 10',
      defaultQuantity: 6,
      unit: 'PC',
      components: [
        ProductionComponent(
          code: '100-010',
          description: 'PARAFUSO 2,9 X 6,5 MM ZI',
          quantity: 2,
          stock: 3803,
          filial: '04',
          armazem: '01',
          structureSequence: '010',
        ),
      ],
    );

    final completion = ProtheusProductionCompletionPlan.fromOrder(
      order,
      catalogItem,
    );

    expect(completion.finishedProduct.sd3Payload['d3_local'], '10');
    expect(completion.consumptions.single.sd3Payload['d3_local'], '01');
  });

  test(
    'blocks PR0 planning when finished-product destination is uncertain',
    () {
      final now = DateTime(2026, 8, 5, 16, 40);
      final order = ProductionOrderFlow(
        number: 'OP-2026-565334',
        productCode: '999-0000',
        productName: 'PRODUTO SEM HISTORICO',
        quantity: 6,
        currentStage: ProductionStage.completed,
        status: ProductionRunStatus.completed,
        priority: 'Media',
        createdAt: now,
        updatedAt: now,
        orderWarehouse: '02',
      );
      const catalogItem = ProductionCatalogItem(
        code: '999-0000',
        name: 'PRODUTO SEM HISTORICO',
        defaultQuantity: 6,
        unit: 'PC',
        components: [],
      );

      expect(
        () => ProtheusProductionCompletionPlan.fromOrder(order, catalogItem),
        throwsA(isA<StateError>()),
      );
    },
  );
}
