import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/shared/models/finished_goods_routing.dart';

class ProtheusProductionOrder {
  const ProtheusProductionOrder({
    required this.orderNumber,
    required this.productCode,
    required this.quantity,
    required this.unit,
    required this.filial,
    required this.warehouse,
    required this.emissionDate,
    required this.startDate,
    required this.dueDate,
    required this.operatorName,
    required this.operatorPin,
  });

  final String orderNumber;
  final String productCode;
  final int quantity;
  final String unit;
  final String filial;
  final String warehouse;
  final String emissionDate;
  final String startDate;
  final String dueDate;
  final String operatorName;
  final String operatorPin;

  factory ProtheusProductionOrder.fromOrder(
    ProductionOrderFlow order, {
    String filial = '04',
    String unit = 'PC',
  }) {
    final date = ProtheusStockMovement._yyyymmdd(order.createdAt);
    final dueDate = _ptBrDateToYyyymmdd(order.prazo) ?? date;
    return ProtheusProductionOrder(
      orderNumber: order.number,
      productCode: order.productCode,
      quantity: order.quantity,
      unit: unit.trim().isEmpty ? 'PC' : unit.trim(),
      filial: filial,
      warehouse: order.orderWarehouse.trim().isEmpty
          ? '05'
          : order.orderWarehouse.trim(),
      emissionDate: date,
      startDate: date,
      dueDate: dueDate,
      operatorName: ProtheusStockMovementPlan._operatorName(order.operatorName),
      operatorPin: ProtheusStockMovementPlan._operatorPin(order.operatorPin),
    );
  }

  Map<String, dynamic> get sc2Payload {
    final key = _protheusOpKey(orderNumber);
    final protheusOp = _protheusOpCode(orderNumber);
    return {
      ..._sc2Defaults,
      'c2_filial': filial,
      'c2_num': key.numero,
      'c2_item': key.item,
      'c2_sequen': key.sequencia,
      'c2_op': protheusOp,
      'c2_produto': productCode,
      'c2_quant': quantity,
      'c2_quje': 0,
      'c2_qtsegum': quantity,
      'c2_um': unit,
      'c2_local': warehouse,
      'c2_emissao': emissionDate,
      'c2_datpri': startDate,
      'c2_datprf': dueDate,
      'c2_status': 'N',
      'c2_tpop': 'F',
      'c2_tppr': 'I',
      'c2_prior': '500',
      'c2_blqapon': '2',
      'c2_prodaut': '2',
      'c2_opterce': '2',
      'c2_diasoci': 99,
      'c2_obs': 'Criada pelo VettiFlow',
      'd_e_l_e_t_': '',
      'r_e_c_d_e_l_': 0,
      'vettiflow_origin': 'op_creation',
      'vettiflow_order_number': orderNumber,
      'vettiflow_operator_name': operatorName,
      'vettiflow_operator_pin': operatorPin,
    };
  }

  static ({String numero, String item, String sequencia}) _protheusOpKey(
    String orderNumber,
  ) {
    final match = RegExp(r'(\d+)$').firstMatch(orderNumber);
    final raw = match?.group(1) ?? orderNumber.replaceAll(RegExp(r'\D'), '');
    final normalized = raw.isEmpty ? '0' : raw;
    final numero = normalized.length > 6
        ? normalized.substring(normalized.length - 6)
        : normalized.padLeft(6, '0');
    return (numero: numero, item: '01', sequencia: '001');
  }

  static String _protheusOpCode(String orderNumber) {
    final key = _protheusOpKey(orderNumber);
    return '${key.numero}${key.item}${key.sequencia}';
  }

  static String? _ptBrDateToYyyymmdd(String? value) {
    if (value == null) return null;
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return [
      year.toString().padLeft(4, '0'),
      month.toString().padLeft(2, '0'),
      day.toString().padLeft(2, '0'),
    ].join();
  }

  static const _sc2Defaults = <String, dynamic>{
    'c2_3envio': '',
    'c2_3retorn': '',
    'c2_aglut': '',
    'c2_apfiff1': 0,
    'c2_apfiff2': 0,
    'c2_apfiff3': 0,
    'c2_apfiff4': 0,
    'c2_apfiff5': 0,
    'c2_apinff1': 0,
    'c2_apinff2': 0,
    'c2_apinff3': 0,
    'c2_apinff4': 0,
    'c2_apinff5': 0,
    'c2_apratu1': 0,
    'c2_apratu2': 0,
    'c2_apratu3': 0,
    'c2_apratu4': 0,
    'c2_apratu5': 0,
    'c2_aprfim1': 0,
    'c2_aprfim2': 0,
    'c2_aprfim3': 0,
    'c2_aprfim4': 0,
    'c2_aprfim5': 0,
    'c2_aprfrp1': 0,
    'c2_aprfrp2': 0,
    'c2_aprfrp3': 0,
    'c2_aprfrp4': 0,
    'c2_aprfrp5': 0,
    'c2_aprini1': 0,
    'c2_aprini2': 0,
    'c2_aprini3': 0,
    'c2_aprini4': 0,
    'c2_aprini5': 0,
    'c2_aprirp1': 0,
    'c2_aprirp2': 0,
    'c2_aprirp3': 0,
    'c2_aprirp4': 0,
    'c2_aprirp5': 0,
    'c2_batch': '',
    'c2_batorca': '',
    'c2_batrot': '',
    'c2_batusr': '',
    'c2_blqapon': '',
    'c2_cc': '',
    'c2_cerqua': '',
    'c2_chave': '',
    'c2_chvqip': '',
    'c2_clvl': '',
    'c2_codsaf': '',
    'c2_datajf': '',
    'c2_dataji': '',
    'c2_datprf': '',
    'c2_datpri': '',
    'c2_datrf': '',
    'c2_destina': '',
    'c2_diasoci': 0,
    'c2_dtuprog': '',
    'c2_emissao': '',
    'c2_filial': '',
    'c2_grade': '',
    'c2_grupo': '',
    'c2_horajf': '',
    'c2_horaji': '',
    'c2_idaps': '',
    'c2_ideinv': '',
    'c2_ident': '',
    'c2_item': '',
    'c2_itemcta': '',
    'c2_itemgrd': '',
    'c2_itempv': '',
    'c2_laudo': '',
    'c2_linha': '',
    'c2_loc3': '',
    'c2_local': '',
    'c2_memp': '',
    'c2_mopc': '',
    'c2_nivel': '',
    'c2_num': '',
    'c2_obs': '',
    'c2_ok': '',
    'c2_op': '',
    'c2_opc': '',
    'c2_operac': '',
    'c2_opterce': '',
    'c2_ordsep': '',
    'c2_pedido': '',
    'c2_perda': 0,
    'c2_pmacnut': 0,
    'c2_pmicnut': 0,
    'c2_prior': '',
    'c2_prodaut': '',
    'c2_produto': '',
    'c2_program': '',
    'c2_qtsegum': 0,
    'c2_qtuprog': 0,
    'c2_quant': 0,
    'c2_quje': 0,
    'c2_recurso': '',
    'c2_revi': '',
    'c2_revisao': '',
    'c2_roteiro': '',
    'c2_segum': '',
    'c2_seqmrp': '',
    'c2_seqpai': '',
    'c2_sequen': '',
    'c2_status': '',
    'c2_stterce': '',
    'c2_tpop': '',
    'c2_tppr': '',
    'c2_um': '',
    'c2_vatu1': 0,
    'c2_vatu2': 0,
    'c2_vatu3': 0,
    'c2_vatu4': 0,
    'c2_vatu5': 0,
    'c2_verifi': '',
    'c2_vfim1': 0,
    'c2_vfim2': 0,
    'c2_vfim3': 0,
    'c2_vfim4': 0,
    'c2_vfim5': 0,
    'c2_vfimff1': 0,
    'c2_vfimff2': 0,
    'c2_vfimff3': 0,
    'c2_vfimff4': 0,
    'c2_vfimff5': 0,
    'c2_vfimrp1': 0,
    'c2_vfimrp2': 0,
    'c2_vfimrp3': 0,
    'c2_vfimrp4': 0,
    'c2_vfimrp5': 0,
    'c2_vgru': 0,
    'c2_vini1': 0,
    'c2_vini2': 0,
    'c2_vini3': 0,
    'c2_vini4': 0,
    'c2_vini5': 0,
    'c2_viniff1': 0,
    'c2_viniff2': 0,
    'c2_viniff3': 0,
    'c2_viniff4': 0,
    'c2_viniff5': 0,
    'c2_vinirp1': 0,
    'c2_vinirp2': 0,
    'c2_vinirp3': 0,
    'c2_vinirp4': 0,
    'c2_vinirp5': 0,
    'c2_vop': 0,
    'd_e_l_e_t_': '',
    'r_e_c_d_e_l_': 0,
    'r_e_c_n_o_': 0,
  };
}

class ProtheusStockMovementPlan {
  const ProtheusStockMovementPlan({required this.movements});

  final List<ProtheusStockMovement> movements;

  Map<(String filial, String componentCode, String armazem), num>
  get totalCommittedByBalanceKey {
    final totals = <(String, String, String), num>{};
    for (final movement in movements) {
      if (!movement.affectsStockBalance) continue;
      final key = (movement.filial, movement.componentCode, movement.armazem);
      totals[key] = (totals[key] ?? 0) + movement.quantity;
    }
    return totals;
  }

  static ProtheusStockMovementPlan fromOrder(
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem,
  ) {
    final operatorName = _operatorName(order.operatorName);
    final operatorPin = _operatorPin(order.operatorPin);
    return ProtheusStockMovementPlan(
      movements: [
        for (var index = 0; index < catalogItem.components.length; index++)
          if (_shouldMove(catalogItem.components[index]))
            ProtheusStockMovement.fromComponent(
              order: order,
              component: catalogItem.components[index],
              structureSequence: _structureSequence(
                catalogItem.components[index],
              ),
              operatorName: operatorName,
              operatorPin: operatorPin,
            ),
      ],
    );
  }

  static bool _shouldMove(ProductionComponent component) {
    if (component.code.trim().isEmpty) return false;
    if (component.armazem.trim().isEmpty) return false;
    return component.quantity > 0;
  }

  static String _structureSequence(ProductionComponent component) {
    final sequence = component.structureSequence.trim();
    if (sequence.isNotEmpty) return sequence;
    return '';
  }

  static String _operatorName(String? value) {
    final name = value?.trim();
    return name == null || name.isEmpty ? 'VettiFlow' : name;
  }

  static String _operatorPin(String? value) {
    return value?.trim() ?? '';
  }
}

class ProtheusStockCancelationPlan {
  const ProtheusStockCancelationPlan({required this.movements});

  final List<ProtheusStockCancelationMovement> movements;

  Map<(String filial, String componentCode, String armazem), num>
  get totalReleasedByBalanceKey {
    final totals = <(String, String, String), num>{};
    for (final movement in movements) {
      if (!movement.affectsStockBalance) continue;
      final key = (movement.filial, movement.componentCode, movement.armazem);
      totals[key] = (totals[key] ?? 0) + movement.quantity;
    }
    return totals;
  }

  static ProtheusStockCancelationPlan fromOrder(
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem, {
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) {
    final signerName = ProtheusStockMovementPlan._operatorName(
      operatorName ?? order.operatorName,
    );
    final signerPin = ProtheusStockMovementPlan._operatorPin(
      operatorPin ?? order.operatorPin,
    );
    return ProtheusStockCancelationPlan(
      movements: [
        for (var index = 0; index < catalogItem.components.length; index++)
          if (ProtheusStockMovementPlan._shouldMove(
            catalogItem.components[index],
          ))
            ProtheusStockCancelationMovement.fromComponent(
              order: order,
              component: catalogItem.components[index],
              structureSequence: ProtheusStockMovementPlan._structureSequence(
                catalogItem.components[index],
              ),
              returnWarehouse:
                  returnWarehouses[catalogItem.components[index].code],
              operatorName: signerName,
              operatorPin: signerPin,
            ),
      ],
    );
  }
}

class ProtheusProductionCompletionPlan {
  const ProtheusProductionCompletionPlan({
    required this.finishedProduct,
    required this.consumptions,
  });

  final ProtheusFinishedProductMovement finishedProduct;
  final List<ProtheusComponentConsumptionMovement> consumptions;

  static ProtheusProductionCompletionPlan fromOrder(
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem,
  ) {
    final operatorName = ProtheusStockMovementPlan._operatorName(
      order.operatorName,
    );
    final operatorPin = ProtheusStockMovementPlan._operatorPin(
      order.operatorPin,
    );
    final producedQuantity = order.closedQuantity > 0
        ? order.closedQuantity
        : order.quantity;
    final routing = FinishedGoodsRouting.suggest(
      productCode: order.productCode,
      orderWarehouse: order.orderWarehouse,
      componentWarehouses: catalogItem.components.map((component) {
        return component.armazem;
      }),
    );
    if (!routing.canComplete) {
      throw StateError(
        routing.warnings.isEmpty
            ? 'Destino do acabado incerto.'
            : routing.warnings.first,
      );
    }
    return ProtheusProductionCompletionPlan(
      finishedProduct: ProtheusFinishedProductMovement.fromOrder(
        order: order,
        unit: catalogItem.unit,
        producedQuantity: producedQuantity,
        finishedGoodsWarehouse: routing.finishedGoodsWarehouse,
        operatorName: operatorName,
        operatorPin: operatorPin,
      ),
      consumptions: [
        for (var index = 0; index < catalogItem.components.length; index++)
          if (ProtheusStockMovementPlan._shouldMove(
            catalogItem.components[index],
          ))
            ProtheusComponentConsumptionMovement.fromComponent(
              order: order,
              component: catalogItem.components[index],
              producedQuantity: producedQuantity,
              structureSequence: ProtheusStockMovementPlan._structureSequence(
                catalogItem.components[index],
              ),
              operatorName: operatorName,
              operatorPin: operatorPin,
            ),
      ],
    );
  }
}

class ProtheusFinishedProductMovement {
  const ProtheusFinishedProductMovement({
    required this.orderNumber,
    required this.productCode,
    required this.filial,
    required this.warehouse,
    required this.quantity,
    required this.unit,
    required this.emissionDate,
    required this.operatorName,
    required this.operatorPin,
  });

  final String orderNumber;
  final String productCode;
  final String filial;
  final String warehouse;
  final int quantity;
  final String unit;
  final String emissionDate;
  final String operatorName;
  final String operatorPin;

  factory ProtheusFinishedProductMovement.fromOrder({
    required ProductionOrderFlow order,
    required String unit,
    required int producedQuantity,
    required String finishedGoodsWarehouse,
    required String operatorName,
    required String operatorPin,
  }) {
    return ProtheusFinishedProductMovement(
      orderNumber: order.number,
      productCode: order.productCode,
      filial: '04',
      warehouse: finishedGoodsWarehouse,
      quantity: producedQuantity,
      unit: unit.trim().isEmpty ? 'PC' : unit.trim(),
      emissionDate: ProtheusStockMovement._yyyymmdd(order.updatedAt),
      operatorName: operatorName,
      operatorPin: operatorPin,
    );
  }

  Map<String, dynamic> get sd3Payload => {
    'd3_filial': filial,
    'd3_cod': productCode,
    'd3_local': warehouse,
    'd3_quant': quantity,
    'd3_um': unit,
    'd3_cf': 'PR0',
    'd3_tm': 'PR0',
    'd3_op': ProtheusProductionOrder._protheusOpCode(orderNumber),
    'd3_doc': _movementDocument(orderNumber, 'PR0'),
    'd3_emissao': emissionDate,
    'd3_estorno': '',
    'd_e_l_e_t_': '',
    'r_e_c_d_e_l_': 0,
    'vettiflow_origin': 'op_completion',
    'vettiflow_movement_kind': 'finished_product',
    'vettiflow_order_number': orderNumber,
    'vettiflow_operator_name': operatorName,
    'vettiflow_operator_pin': operatorPin,
  };

  Map<String, dynamic> get newSb2Payload => {
    'b2_filial': filial,
    'b2_cod': productCode,
    'b2_local': warehouse,
    'b2_qatu': quantity,
    'b2_qemp': 0,
    'b2_reserva': 0,
    'b2_qfim': quantity,
    'b2_dmov': emissionDate,
    'd_e_l_e_t_': '',
    'vettiflow_origin': 'op_completion',
  };
}

class ProtheusComponentConsumptionMovement {
  const ProtheusComponentConsumptionMovement({
    required this.orderNumber,
    required this.productCode,
    required this.componentCode,
    required this.filial,
    required this.armazem,
    required this.quantity,
    required this.emissionDate,
    required this.structureSequence,
    required this.operatorName,
    required this.operatorPin,
  });

  final String orderNumber;
  final String productCode;
  final String componentCode;
  final String filial;
  final String armazem;
  final num quantity;
  final String emissionDate;
  final String structureSequence;
  final String operatorName;
  final String operatorPin;

  bool get affectsStockBalance =>
      !componentCode.toUpperCase().startsWith('MOD');

  factory ProtheusComponentConsumptionMovement.fromComponent({
    required ProductionOrderFlow order,
    required ProductionComponent component,
    required int producedQuantity,
    required String structureSequence,
    required String operatorName,
    required String operatorPin,
  }) {
    return ProtheusComponentConsumptionMovement(
      orderNumber: order.number,
      productCode: order.productCode,
      componentCode: component.code,
      filial: component.filial.trim().isEmpty ? '04' : component.filial.trim(),
      armazem: component.armazem.trim(),
      quantity: component.quantity * producedQuantity,
      emissionDate: ProtheusStockMovement._yyyymmdd(order.updatedAt),
      structureSequence: structureSequence,
      operatorName: operatorName,
      operatorPin: operatorPin,
    );
  }

  Map<String, dynamic> get sd3Payload => {
    'd3_filial': filial,
    'd3_cod': componentCode,
    'd3_local': armazem,
    'd3_quant': quantity,
    'd3_cf': 'RE1',
    'd3_tm': 'RE1',
    'd3_op': ProtheusProductionOrder._protheusOpCode(orderNumber),
    'd3_doc': _movementDocument(orderNumber, 'RE1'),
    'd3_emissao': emissionDate,
    'd3_estorno': '',
    'd3_numseq': structureSequence,
    'd_e_l_e_t_': '',
    'r_e_c_d_e_l_': 0,
    'vettiflow_origin': 'op_completion',
    'vettiflow_movement_kind': 'component_consumption',
    'vettiflow_order_number': orderNumber,
    'vettiflow_operator_name': operatorName,
    'vettiflow_operator_pin': operatorPin,
  };
}

class ProtheusStockCancelationMovement {
  const ProtheusStockCancelationMovement({
    required this.orderNumber,
    required this.productCode,
    required this.componentCode,
    required this.filial,
    required this.armazem,
    required this.returnWarehouse,
    required this.quantity,
    required this.emissionDate,
    required this.structureSequence,
    required this.operatorName,
    required this.operatorPin,
  });

  final String orderNumber;
  final String productCode;
  final String componentCode;
  final String filial;
  final String armazem;
  final String returnWarehouse;
  final num quantity;
  final String emissionDate;
  final String structureSequence;
  final String operatorName;
  final String operatorPin;

  bool get affectsStockBalance =>
      !componentCode.toUpperCase().startsWith('MOD');

  factory ProtheusStockCancelationMovement.fromComponent({
    required ProductionOrderFlow order,
    required ProductionComponent component,
    required String structureSequence,
    String? returnWarehouse,
    required String operatorName,
    required String operatorPin,
  }) {
    final sourceWarehouse = component.armazem.trim();
    final destination = returnWarehouse?.trim();
    return ProtheusStockCancelationMovement(
      orderNumber: order.number,
      productCode: order.productCode,
      componentCode: component.code,
      filial: component.filial.trim().isEmpty ? '04' : component.filial.trim(),
      armazem: sourceWarehouse,
      returnWarehouse: destination == null || destination.isEmpty
          ? sourceWarehouse
          : destination,
      quantity: component.quantity * order.quantity,
      emissionDate: ProtheusStockMovement._yyyymmdd(order.updatedAt),
      structureSequence: structureSequence,
      operatorName: operatorName,
      operatorPin: operatorPin,
    );
  }

  Map<String, dynamic> get sd4CancelPayload => {
    'd4_filial': filial,
    'd4_cod': componentCode,
    'd4_local': armazem,
    'd4_op': ProtheusProductionOrder._protheusOpCode(orderNumber),
    'd4_data': emissionDate,
    'd4_qsusp': 0,
    'd4_situaca': 'D',
    'd4_qtdeori': quantity,
    'd4_quant': quantity,
    'd4_trt': structureSequence,
    'd4_roteiro': '01',
    'd4_oporig': '',
    'd4_qtsegum': 0,
    'd4_sldemp': 0,
    'd4_sldemp2': 0,
    'd4_produto': productCode,
    'd4_qtneces': 0,
    'd_e_l_e_t_': '*',
    'r_e_c_d_e_l_': 0,
    'd4_ok': '',
    'vettiflow_origin': 'op_cancel',
    'vettiflow_order_number': orderNumber,
    'vettiflow_return_warehouse': returnWarehouse,
    'vettiflow_operator_name': operatorName,
    'vettiflow_operator_pin': operatorPin,
  };
}

class ProtheusStockMovement {
  const ProtheusStockMovement({
    required this.orderNumber,
    required this.productCode,
    required this.componentCode,
    required this.filial,
    required this.armazem,
    required this.quantity,
    required this.emissionDate,
    required this.structureSequence,
    required this.operatorName,
    required this.operatorPin,
  });

  final String orderNumber;
  final String productCode;
  final String componentCode;
  final String filial;
  final String armazem;
  final num quantity;
  final String emissionDate;
  final String structureSequence;
  final String operatorName;
  final String operatorPin;

  bool get affectsStockBalance =>
      !componentCode.toUpperCase().startsWith('MOD');

  factory ProtheusStockMovement.fromComponent({
    required ProductionOrderFlow order,
    required ProductionComponent component,
    required String structureSequence,
    required String operatorName,
    required String operatorPin,
  }) {
    return ProtheusStockMovement(
      orderNumber: order.number,
      productCode: order.productCode,
      componentCode: component.code,
      filial: component.filial.trim().isEmpty ? '04' : component.filial.trim(),
      armazem: component.armazem.trim(),
      quantity: component.quantity * order.quantity,
      emissionDate: _yyyymmdd(order.createdAt),
      structureSequence: structureSequence,
      operatorName: operatorName,
      operatorPin: operatorPin,
    );
  }

  Map<String, dynamic> get sd4Payload => {
    'd4_filial': filial,
    'd4_cod': componentCode,
    'd4_local': armazem,
    'd4_op': ProtheusProductionOrder._protheusOpCode(orderNumber),
    'd4_data': emissionDate,
    'd4_qsusp': 0,
    'd4_situaca': '',
    'd4_qtdeori': quantity,
    'd4_quant': quantity,
    'd4_trt': structureSequence,
    'd4_roteiro': '01',
    'd4_oporig': '',
    'd4_qtsegum': 0,
    'd4_sldemp': 0,
    'd4_sldemp2': 0,
    'd4_produto': productCode,
    'd4_qtneces': 0,
    'd_e_l_e_t_': '',
    'r_e_c_d_e_l_': 0,
    'd4_ok': '',
    'vettiflow_origin': 'op_creation',
    'vettiflow_order_number': orderNumber,
    'vettiflow_operator_name': operatorName,
    'vettiflow_operator_pin': operatorPin,
  };

  Map<String, dynamic> get newSb2Payload => {
    'b2_filial': filial,
    'b2_cod': componentCode,
    'b2_local': armazem,
    'b2_qatu': 0,
    'b2_qemp': quantity,
    'b2_reserva': 0,
    'b2_qfim': 0,
    'b2_dmov': emissionDate,
    'd_e_l_e_t_': '',
    'vettiflow_origin': 'op_creation',
  };

  static String _yyyymmdd(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }
}

String _movementDocument(String orderNumber, String movementType) {
  final suffix = orderNumber.replaceAll(RegExp(r'\W+'), '');
  final normalized = suffix.length > 6
      ? suffix.substring(suffix.length - 6)
      : suffix.padLeft(6, '0');
  return '$movementType$normalized';
}
