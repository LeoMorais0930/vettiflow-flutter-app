import 'package:vetti_flow_1_0/shared/models/operator.dart';

class WarehouseRouteTarget {
  const WarehouseRouteTarget({
    required this.code,
    required this.name,
    required this.area,
    required this.stages,
    required this.primaryStage,
    required this.responsibleName,
    this.hasDedicatedScreen = true,
    this.note = '',
  });

  final String code;
  final String name;
  final WorkArea area;
  final List<WorkStage> stages;
  final WorkStage primaryStage;
  final String responsibleName;
  final bool hasDedicatedScreen;
  final String note;

  String get route => primaryStage.route;

  String get destinationLabel {
    return name;
  }

  String get label => 'Armazém $code - $destinationLabel';
}

class WarehouseRouting {
  const WarehouseRouting._();

  // Locais utilizados pela operação. Outros códigos ficam apenas no histórico.
  static const operationalCodes = ['01', '03', '05', '06', '07', '10'];
  static List<WarehouseRouteTarget> get operational =>
      all.where((target) => operationalCodes.contains(target.code)).toList();

  static const _productionStages = [
    WorkStage.firmware,
    WorkStage.soldering,
    WorkStage.testing,
    WorkStage.closing,
  ];

  static const all = [
    WarehouseRouteTarget(
      code: '01',
      name: 'Almoxarifado',
      area: WorkArea.warehouse,
      stages: [WorkStage.warehouse],
      primaryStage: WorkStage.warehouse,
      responsibleName: 'Vera',
    ),
    WarehouseRouteTarget(
      code: '03',
      name: 'SMD',
      area: WorkArea.smd,
      stages: [WorkStage.smd],
      primaryStage: WorkStage.smd,
      responsibleName: 'Paula',
    ),
    WarehouseRouteTarget(
      code: '04',
      name: 'PTH',
      area: WorkArea.production,
      stages: _productionStages,
      primaryStage: WorkStage.firmware,
      responsibleName: 'Tatiane',
      hasDedicatedScreen: false,
      note: 'Local oficial PRODUCAO PTH; tela dedicada ainda pendente.',
    ),
    WarehouseRouteTarget(
      code: '05',
      name: 'Produção',
      area: WorkArea.production,
      stages: _productionStages,
      primaryStage: WorkStage.firmware,
      responsibleName: 'Tatiane',
    ),
    WarehouseRouteTarget(
      code: '06',
      name: 'Suporte',
      area: WorkArea.support,
      stages: [WorkStage.support],
      primaryStage: WorkStage.support,
      responsibleName: 'Bruno',
    ),
    WarehouseRouteTarget(
      code: '07',
      name: 'Suporte',
      area: WorkArea.support,
      stages: [WorkStage.support],
      primaryStage: WorkStage.support,
      responsibleName: 'Bruno',
    ),
    WarehouseRouteTarget(
      code: '10',
      name: 'Expedição',
      area: WorkArea.production,
      stages: [WorkStage.expedition],
      primaryStage: WorkStage.expedition,
      responsibleName: 'Rafaela',
    ),
    WarehouseRouteTarget(
      code: '02',
      name: 'USA',
      area: WorkArea.system,
      stages: [WorkStage.warehouse],
      primaryStage: WorkStage.warehouse,
      responsibleName: '',
      hasDedicatedScreen: false,
      note: 'Estoque especial oficial; regra operacional pendente.',
    ),
    WarehouseRouteTarget(
      code: '08',
      name: 'Itens obsoletos',
      area: WorkArea.system,
      stages: [WorkStage.warehouse],
      primaryStage: WorkStage.warehouse,
      responsibleName: '',
      hasDedicatedScreen: false,
      note: 'Estoque especial oficial; regra operacional pendente.',
    ),
    WarehouseRouteTarget(
      code: '11',
      name: 'Estoque Adrian',
      area: WorkArea.system,
      stages: [WorkStage.warehouse],
      primaryStage: WorkStage.warehouse,
      responsibleName: '',
      hasDedicatedScreen: false,
      note: 'Estoque especial oficial; regra operacional pendente.',
    ),
    WarehouseRouteTarget(
      code: '12',
      name: 'Entrega futura',
      area: WorkArea.system,
      stages: [WorkStage.warehouse],
      primaryStage: WorkStage.warehouse,
      responsibleName: '',
      hasDedicatedScreen: false,
      note: 'Estoque especial oficial; regra operacional pendente.',
    ),
    WarehouseRouteTarget(
      code: '70',
      name: 'Terceiros - Mauro',
      area: WorkArea.production,
      stages: [WorkStage.warehouse],
      primaryStage: WorkStage.warehouse,
      responsibleName: '',
      hasDedicatedScreen: false,
      note: 'Fluxo de terceiros pendente.',
    ),
    WarehouseRouteTarget(
      code: '71',
      name: 'Terceiros - Fenix Jundiai',
      area: WorkArea.production,
      stages: [WorkStage.warehouse],
      primaryStage: WorkStage.warehouse,
      responsibleName: '',
      hasDedicatedScreen: false,
      note: 'Fluxo de terceiros pendente.',
    ),
    WarehouseRouteTarget(
      code: '72',
      name: 'Terceiros - Gwands SP',
      area: WorkArea.production,
      stages: [WorkStage.warehouse],
      primaryStage: WorkStage.warehouse,
      responsibleName: '',
      hasDedicatedScreen: false,
      note: 'Fluxo de terceiros pendente.',
    ),
    WarehouseRouteTarget(
      code: '73',
      name: 'Terceiros - Trafo',
      area: WorkArea.production,
      stages: [WorkStage.warehouse],
      primaryStage: WorkStage.warehouse,
      responsibleName: '',
      hasDedicatedScreen: false,
      note: 'Fluxo de terceiros pendente.',
    ),
  ];

  static const _operatorWarehouseAccess = {
    'tatiane': ['05', '10'],
    'andressa': ['05'],
    'vera': ['01'],
    'luis': ['01'],
    'paula': ['03'],
    'bruno': ['06', '07'],
    'bruna': ['10'],
    'tamara': ['10'],
  };

  static const _blockedMaterialSourceWarehouses = {'06', '07'};

  static WarehouseRouteTarget? byCode(String code) {
    final normalized = normalizeCode(code);
    for (final target in all) {
      if (target.code == normalized) return target;
    }
    return null;
  }

  static String normalizeCode(String code) {
    final trimmed = code.trim();
    final numeric = int.tryParse(trimmed);
    if (numeric != null) return numeric.toString().padLeft(2, '0');
    return trimmed.padLeft(2, '0');
  }

  static WorkStage? stageForWarehouse(String code) =>
      byCode(code)?.primaryStage;

  static String? routeForWarehouse(String code) => byCode(code)?.route;

  static List<String> warehousesForOperator(String? operatorName) {
    final key = _normalizeOperatorName(operatorName);
    final warehouses = _operatorWarehouseAccess[key] ?? const <String>[];
    return [...warehouses]..sort();
  }

  static List<String> orderCreationWarehousesForOperator(String? operatorName) {
    return [...operationalCodes];
  }

  static bool canOperatorUseWarehouse(String? operatorName, String warehouse) {
    final key = _normalizeOperatorName(operatorName);
    if (key.isEmpty) return true;
    final allowed = _operatorWarehouseAccess[key];
    if (allowed == null) return false;
    return allowed.contains(normalizeCode(warehouse));
  }

  static bool canOperatorCreateOrder(String? operatorName, String warehouse) {
    return operationalCodes.contains(normalizeCode(warehouse));
  }

  static bool canSourceMaterialFromWarehouse(String warehouse) {
    return !_blockedMaterialSourceWarehouses.contains(normalizeCode(warehouse));
  }

  static List<String> filterWarehousesForOperator(
    Iterable<String> warehouses,
    String? operatorName,
  ) {
    final values = [
      for (final warehouse in warehouses)
        if (canOperatorUseWarehouse(operatorName, warehouse))
          normalizeCode(warehouse),
    ];
    return values.toSet().toList()..sort();
  }

  static String labelForWarehouse(String code) {
    final target = byCode(code);
    if (target != null) return target.label;
    return 'Armazém ${normalizeCode(code)}';
  }

  static String destinationForWarehouse(String code) {
    return byCode(code)?.destinationLabel ?? '';
  }

  static String _normalizeOperatorName(String? operatorName) {
    return operatorName?.trim().toLowerCase() ?? '';
  }
}
