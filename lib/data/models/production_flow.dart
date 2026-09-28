import 'smd_pointing.dart';
import 'production_dispatch_draft.dart';
export 'production_dispatch_draft.dart';
export 'smd_pointing.dart';

enum ProductionStage {
  warehouse,
  smd,
  firmware,
  soldering,
  testing,
  closing,
  expedition,
  storage,
  completed;

  String get label => switch (this) {
    warehouse => 'Almoxarifado',
    smd => 'SMD',
    firmware => 'Gravacao',
    soldering => 'Soldagem',
    testing => 'Teste',
    closing => 'Fechamento',
    expedition => 'Expedicao',
    storage => 'Armazenada',
    completed => 'Finalizada',
  };

  String get route => switch (this) {
    warehouse => '/almoxarifado',
    smd => '/smd',
    firmware => '/firmware',
    soldering => '/soldagem',
    testing => '/teste',
    closing => '/fechamento',
    expedition => '/expedicao',
    storage => '/expedicao',
    completed => '/dashboard',
  };

  int get progressIndex => switch (this) {
    warehouse => 0,
    smd => 1,
    firmware => 2,
    soldering => 3,
    testing => 4,
    closing => 5,
    expedition => 6,
    storage || completed => 7,
  };

  static const productionFlow = [
    warehouse,
    smd,
    firmware,
    soldering,
    testing,
    closing,
    expedition,
  ];
}

enum ProductionRunStatus { waiting, active, paused, completed }

enum PauseReason {
  ginasticaLaboral('Ginastica laboral'),
  cafe('Cafe'),
  banheiro('Banheiro'),
  almoco('Almoco'),
  outro('Outro');

  const PauseReason(this.label);

  final String label;
}

/// Um defeito registrado no teste: tipo (código + título) e quantidade de
/// dispositivos afetados.
class DefectRecord {
  const DefectRecord({
    required this.code,
    required this.title,
    required this.quantity,
  });

  final String code;
  final String title;
  final int quantity;

  Map<String, dynamic> toJson() => {
    'code': code,
    'title': title,
    'quantity': quantity,
  };

  factory DefectRecord.fromJson(Map<String, dynamic> json) => DefectRecord(
    code: json['code'] as String? ?? '',
    title: json['title'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
  );
}

class ProductionPauseEvent {
  const ProductionPauseEvent({
    required this.stage,
    required this.operatorName,
    required this.operatorPin,
    required this.reason,
    required this.createdAt,
    this.resumedAt,
    this.customReason,
    this.producedQuantity = 0,
  });

  final ProductionStage stage;
  final String operatorName;
  final String operatorPin;
  final PauseReason reason;
  final DateTime createdAt;
  final DateTime? resumedAt;
  final String? customReason;
  final int producedQuantity;

  String get reasonLabel {
    if (reason != PauseReason.outro) return reason.label;
    final custom = customReason?.trim();
    return custom == null || custom.isEmpty ? reason.label : custom;
  }

  Duration pauseDuration(DateTime now) {
    final end = resumedAt ?? now;
    final duration = end.difference(createdAt);
    return duration.isNegative ? Duration.zero : duration;
  }

  ProductionPauseEvent copyWith({DateTime? Function()? resumedAt}) {
    return ProductionPauseEvent(
      stage: stage,
      operatorName: operatorName,
      operatorPin: operatorPin,
      reason: reason,
      createdAt: createdAt,
      resumedAt: resumedAt != null ? resumedAt() : this.resumedAt,
      customReason: customReason,
      producedQuantity: producedQuantity,
    );
  }

  Map<String, dynamic> toJson() => {
    'stage': stage.name,
    'operatorName': operatorName,
    'operatorPin': operatorPin,
    'reason': reason.name,
    'createdAt': createdAt.toIso8601String(),
    'resumedAt': resumedAt?.toIso8601String(),
    'customReason': customReason,
    'producedQuantity': producedQuantity,
  };

  factory ProductionPauseEvent.fromJson(Map<String, dynamic> json) {
    return ProductionPauseEvent(
      stage: ProductionStage.values.firstWhere(
        (stage) => stage.name == json['stage'],
        orElse: () => ProductionStage.warehouse,
      ),
      operatorName: json['operatorName'] as String? ?? '',
      operatorPin: json['operatorPin'] as String? ?? '',
      reason: PauseReason.values.firstWhere(
        (reason) => reason.name == json['reason'],
        orElse: () => PauseReason.outro,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      resumedAt: json['resumedAt'] is String
          ? DateTime.parse(json['resumedAt'] as String)
          : null,
      customReason: json['customReason'] as String?,
      producedQuantity: (json['producedQuantity'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProductionOperatorSession {
  const ProductionOperatorSession({
    required this.stage,
    required this.operatorName,
    required this.operatorPin,
    required this.startedAt,
    this.completedAt,
    this.pausedAt,
    this.pausedDuration = Duration.zero,
    this.producedQuantity = 0,
  });

  final ProductionStage stage;
  final String operatorName;
  final String operatorPin;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? pausedAt;
  final Duration pausedDuration;
  final int producedQuantity;

  bool get isCompleted => completedAt != null;

  bool get isPaused => pausedAt != null && !isCompleted;

  bool get isRunning => pausedAt == null && !isCompleted;

  Duration elapsed(DateTime now) {
    final end = completedAt ?? pausedAt ?? now;
    final elapsed = end.difference(startedAt) - pausedDuration;
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Duration workedDuration(DateTime now) => elapsed(now);

  ProductionOperatorSession pause(DateTime now, {int producedQuantity = 0}) {
    return copyWith(
      pausedAt: () => pausedAt ?? now,
      producedQuantity: this.producedQuantity + producedQuantity,
    );
  }

  ProductionOperatorSession resume(DateTime now) {
    final paused = pausedAt;
    return copyWith(
      pausedAt: () => null,
      pausedDuration: paused == null
          ? pausedDuration
          : pausedDuration + now.difference(paused),
    );
  }

  ProductionOperatorSession complete(DateTime now) {
    final resumed = pausedAt == null ? this : resume(now);
    return resumed.copyWith(completedAt: () => now, pausedAt: () => null);
  }

  ProductionOperatorSession copyWith({
    DateTime? Function()? completedAt,
    DateTime? Function()? pausedAt,
    Duration? pausedDuration,
    int? producedQuantity,
  }) {
    return ProductionOperatorSession(
      stage: stage,
      operatorName: operatorName,
      operatorPin: operatorPin,
      startedAt: startedAt,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
      pausedAt: pausedAt != null ? pausedAt() : this.pausedAt,
      pausedDuration: pausedDuration ?? this.pausedDuration,
      producedQuantity: producedQuantity ?? this.producedQuantity,
    );
  }

  Map<String, dynamic> toJson() => {
    'stage': stage.name,
    'operatorName': operatorName,
    'operatorPin': operatorPin,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'pausedAt': pausedAt?.toIso8601String(),
    'pausedDurationMs': pausedDuration.inMilliseconds,
    'producedQuantity': producedQuantity,
  };

  factory ProductionOperatorSession.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) =>
        value is String ? DateTime.parse(value) : null;
    return ProductionOperatorSession(
      stage: ProductionStage.values.firstWhere(
        (stage) => stage.name == json['stage'],
        orElse: () => ProductionStage.warehouse,
      ),
      operatorName: json['operatorName'] as String? ?? '',
      operatorPin: json['operatorPin'] as String? ?? '',
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: parseDate(json['completedAt']),
      pausedAt: parseDate(json['pausedAt']),
      pausedDuration: Duration(
        milliseconds: (json['pausedDurationMs'] as num?)?.toInt() ?? 0,
      ),
      producedQuantity: (json['producedQuantity'] as num?)?.toInt() ?? 0,
    );
  }
}

String formatProductionDuration(Duration duration) {
  final normalized = duration.isNegative ? Duration.zero : duration;
  final hours = normalized.inHours;
  final minutes = normalized.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}min';
  if (minutes > 0) return '${minutes}min';
  return '${normalized.inSeconds}s';
}

String formatProductionQuantity(num quantity) {
  final normalized = quantity.toDouble();
  if (normalized == normalized.truncateToDouble()) {
    return normalized.toInt().toString();
  }
  return normalized
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

class ProductionStageTiming {
  const ProductionStageTiming({
    this.startedAt,
    this.completedAt,
    this.pausedAt,
    this.pausedDuration = Duration.zero,
  });

  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? pausedAt;
  final Duration pausedDuration;

  Duration elapsed(DateTime now) {
    final start = startedAt;
    if (start == null) return Duration.zero;
    final end = completedAt ?? pausedAt ?? now;
    return end.difference(start) - pausedDuration;
  }

  ProductionStageTiming start(DateTime now) {
    return copyWith(startedAt: () => startedAt ?? now, pausedAt: () => null);
  }

  ProductionStageTiming pause(DateTime now) {
    return copyWith(pausedAt: () => pausedAt ?? now);
  }

  ProductionStageTiming resume(DateTime now) {
    final paused = pausedAt;
    return copyWith(
      pausedAt: () => null,
      pausedDuration: paused == null
          ? pausedDuration
          : pausedDuration + now.difference(paused),
    );
  }

  ProductionStageTiming complete(DateTime now) {
    final resumed = pausedAt == null ? this : resume(now);
    return resumed.copyWith(completedAt: () => now, pausedAt: () => null);
  }

  ProductionStageTiming copyWith({
    DateTime? Function()? startedAt,
    DateTime? Function()? completedAt,
    DateTime? Function()? pausedAt,
    Duration? pausedDuration,
  }) {
    return ProductionStageTiming(
      startedAt: startedAt != null ? startedAt() : this.startedAt,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
      pausedAt: pausedAt != null ? pausedAt() : this.pausedAt,
      pausedDuration: pausedDuration ?? this.pausedDuration,
    );
  }
}

class WarehouseRelease {
  const WarehouseRelease({
    required this.at,
    required this.operatorName,
    required this.operatorUsername,
    required this.destination,
  });
  final DateTime at;
  final String operatorName, operatorUsername;
  final ProductionStage destination;
  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'operatorName': operatorName,
    'operatorUsername': operatorUsername,
    'destination': destination.name,
  };
  factory WarehouseRelease.fromJson(Map<String, dynamic> json) =>
      WarehouseRelease(
        at: DateTime.parse(json['at'] as String),
        operatorName: json['operatorName'] as String,
        operatorUsername: json['operatorUsername'] as String,
        destination: ProductionStage.values.byName(
          json['destination'] as String,
        ),
      );
}

class ProductionOrderFlow {
  const ProductionOrderFlow({
    required this.number,
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.currentStage,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.operatorName,
    this.operatorPin,
    this.responsavel,
    this.prazo,
    this.orderWarehouse = '',
    this.componentConsumptionWarehouse = '',
    this.finishedGoodsWarehouse = '',
    this.routingWarnings = const [],
    this.closedQuantity = 0,
    this.lastObservation,
    this.storedQuantity = 0,
    this.dispatchedQuantity = 0,
    this.timings = const {},
    this.timingHistory = const {},
    this.testDefects = const [],
    this.operatorSessions = const [],
    this.pauseEvents = const [],
    this.plannedStages = const [],
    this.smd = const SmdProgress(),
    this.dispatchDrafts = const [],
    this.warehouseReleases = const [],
    this.unit = '',
  });

  final String number;
  final String productCode;
  final String productName;
  final int quantity;
  final ProductionStage currentStage;
  final ProductionRunStatus status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? operatorName;
  final String? operatorPin;
  final String? responsavel;
  final String? prazo;
  final String orderWarehouse;
  final String componentConsumptionWarehouse;
  final String finishedGoodsWarehouse;
  final List<String> routingWarnings;
  final int closedQuantity;
  final String? lastObservation;
  final int storedQuantity;
  final int dispatchedQuantity;
  final Map<ProductionStage, ProductionStageTiming> timings;
  final Map<ProductionStage, List<ProductionStageTiming>> timingHistory;
  Iterable<MapEntry<ProductionStage, ProductionStageTiming>>
  get allTimings sync* {
    yield* timings.entries;
    for (final entry in timingHistory.entries) {
      for (final timing in entry.value) {
        yield MapEntry(entry.key, timing);
      }
    }
  }

  DateTime? latestCompletion(ProductionStage stage) {
    final dates =
        allTimings
            .where((e) => e.key == stage && e.value.completedAt != null)
            .map((e) => e.value.completedAt!)
            .toList()
          ..sort();
    return dates.lastOrNull;
  }

  final List<DefectRecord> testDefects;
  final List<ProductionOperatorSession> operatorSessions;
  final List<ProductionPauseEvent> pauseEvents;
  final List<ProductionStage> plannedStages;
  final SmdProgress smd;
  final List<ProductionDispatchDraft> dispatchDrafts;
  final List<WarehouseRelease> warehouseReleases;

  static const internalProductionStages = [
    ProductionStage.firmware,
    ProductionStage.soldering,
    ProductionStage.testing,
    ProductionStage.closing,
  ];

  bool get belongsToProduction =>
      orderWarehouse == '05' ||
      internalProductionStages.contains(currentStage) ||
      plannedStages.any(internalProductionStages.contains);

  num get preparedQuantity =>
      dispatchDrafts.fold<num>(0, (total, d) => total + d.allocated);
  num get totalStoredQuantity =>
      storedQuantity + dispatchDrafts.fold<num>(0, (sum, d) => sum + d.stored);
  num get totalDispatchedQuantity =>
      dispatchedQuantity +
      dispatchDrafts.fold<num>(0, (sum, d) => sum + d.shipped);
  num get productionQuantity =>
      (quantity -
              storedQuantity -
              dispatchedQuantity -
              dispatchDrafts.fold<num>(
                0,
                (sum, d) => sum + d.outsideProduction,
              ))
          .clamp(0, quantity);
  String get productionQuantityLabel =>
      '${formatProductionQuantity(productionQuantity)} ${unit.isEmpty ? 'un' : unit}';
  bool get readyForExpedition {
    if (currentStage == ProductionStage.completed) return true;
    if (currentStage != ProductionStage.expedition) return false;
    final route = plannedStages.isEmpty
        ? ProductionStage.productionFlow
        : plannedStages;
    return !route
        .skip(route.indexOf(currentStage) + 1)
        .any(internalProductionStages.contains);
  }

  num get availableToPrepare =>
      (quantity - storedQuantity - dispatchedQuantity - preparedQuantity).clamp(
        0,
        quantity,
      );

  /// Limite para planejar envios; não representa saldo de estoque ou peças boas.
  bool get canPrepareDispatch =>
      orderWarehouse == '05' &&
      unit.trim().isNotEmpty &&
      availableToPrepare > 0 &&
      (internalProductionStages.contains(currentStage) ||
          currentStage == ProductionStage.expedition ||
          (currentStage == ProductionStage.completed &&
              (plannedStages.any(internalProductionStages.contains) ||
                  timings.keys.any(internalProductionStages.contains))));
  final String unit;

  /// Total de dispositivos marcados como defeito no teste.
  int get totalDefects =>
      testDefects.fold(0, (sum, defect) => sum + defect.quantity);

  String get productLabel =>
      productCode.isEmpty ? productName : '$productCode - $productName';

  String get quantityLabel => '$quantity ${unit.isEmpty ? 'un' : unit}';

  bool get isHighPriority => priority == 'Alta';

  bool get isDone =>
      currentStage == ProductionStage.completed ||
      currentStage == ProductionStage.storage;

  /// The chosen route controls internal stages independently of ERP warehouses.
  ProductionStage get nextStage {
    final route = plannedStages
        .where(ProductionStage.productionFlow.contains)
        .toList();
    if (route.isNotEmpty) {
      final index = route.indexOf(currentStage);
      if (index < 0) return route.first;
      return index + 1 < route.length
          ? route[index + 1]
          : ProductionStage.completed;
    }
    final index = ProductionStage.productionFlow.indexOf(currentStage);
    return index >= 0 && index + 1 < ProductionStage.productionFlow.length
        ? ProductionStage.productionFlow[index + 1]
        : ProductionStage.completed;
  }

  String get previousStageLabel {
    final route = plannedStages.isEmpty
        ? ProductionStage.productionFlow
        : plannedStages;
    final index = route.indexOf(currentStage);
    return index > 0 ? route[index - 1].label : 'Programação';
  }

  String get nextStageLabel => nextStage == ProductionStage.completed
      ? 'Fim da sequência'
      : nextStage.label;

  Duration activeElapsed(DateTime now) =>
      timings[currentStage]?.elapsed(now) ?? Duration.zero;

  List<ProductionOperatorSession> sessionsAt(ProductionStage stage) =>
      operatorSessions.where((session) => session.stage == stage).toList();

  List<ProductionOperatorSession> activeSessionsAt(ProductionStage stage) =>
      sessionsAt(stage).where((session) => !session.isCompleted).toList();

  Duration totalElapsed(DateTime now) {
    return allTimings
        .map((e) => e.value)
        .fold<Duration>(
          Duration.zero,
          (total, timing) => total + timing.elapsed(now),
        );
  }

  ProductionOrderFlow copyWith({
    ProductionStage? currentStage,
    ProductionRunStatus? status,
    String? priority,
    DateTime? updatedAt,
    String? Function()? operatorName,
    String? Function()? operatorPin,
    String? Function()? responsavel,
    String? prazo,
    String? orderWarehouse,
    String? componentConsumptionWarehouse,
    String? finishedGoodsWarehouse,
    List<String>? routingWarnings,
    int? closedQuantity,
    String? Function()? lastObservation,
    int? storedQuantity,
    int? dispatchedQuantity,
    Map<ProductionStage, ProductionStageTiming>? timings,
    Map<ProductionStage, List<ProductionStageTiming>>? timingHistory,
    List<DefectRecord>? testDefects,
    List<ProductionOperatorSession>? operatorSessions,
    List<ProductionPauseEvent>? pauseEvents,
    List<ProductionStage>? plannedStages,
    SmdProgress? smd,
    List<ProductionDispatchDraft>? dispatchDrafts,
    List<WarehouseRelease>? warehouseReleases,
  }) {
    return ProductionOrderFlow(
      number: number,
      productCode: productCode,
      productName: productName,
      quantity: quantity,
      currentStage: currentStage ?? this.currentStage,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      operatorName: operatorName != null ? operatorName() : this.operatorName,
      operatorPin: operatorPin != null ? operatorPin() : this.operatorPin,
      responsavel: responsavel != null ? responsavel() : this.responsavel,
      prazo: prazo ?? this.prazo,
      orderWarehouse: orderWarehouse ?? this.orderWarehouse,
      componentConsumptionWarehouse:
          componentConsumptionWarehouse ?? this.componentConsumptionWarehouse,
      finishedGoodsWarehouse:
          finishedGoodsWarehouse ?? this.finishedGoodsWarehouse,
      routingWarnings: routingWarnings ?? this.routingWarnings,
      closedQuantity: closedQuantity ?? this.closedQuantity,
      lastObservation: lastObservation != null
          ? lastObservation()
          : this.lastObservation,
      storedQuantity: storedQuantity ?? this.storedQuantity,
      dispatchedQuantity: dispatchedQuantity ?? this.dispatchedQuantity,
      timings: timings ?? this.timings,
      timingHistory: timingHistory ?? this.timingHistory,
      testDefects: testDefects ?? this.testDefects,
      operatorSessions: operatorSessions ?? this.operatorSessions,
      pauseEvents: pauseEvents ?? this.pauseEvents,
      plannedStages: plannedStages ?? this.plannedStages,
      smd: smd ?? this.smd,
      dispatchDrafts: dispatchDrafts ?? this.dispatchDrafts,
      warehouseReleases: warehouseReleases ?? this.warehouseReleases,
      unit: unit,
    );
  }
}

class ProductionCatalogItem {
  const ProductionCatalogItem({
    required this.code,
    required this.name,
    required this.defaultQuantity,
    required this.components,
    this.unit = 'PC',
  });

  final String code;
  final String name;
  final int defaultQuantity;
  final List<ProductionComponent> components;
  final String unit;

  String get label => '$code - $name';
}

class ProductionComponent {
  const ProductionComponent({
    required this.code,
    required this.description,
    required this.quantity,
    required this.stock,
    this.unit = '',
    this.filial = '',
    this.armazem = '',
    this.currentStock = 0,
    this.committedQuantity = 0,
    this.reservedQuantity = 0,
    this.requirementSource = 'SG1',
    this.sourceOrder = '',
    this.commitmentDate = '',
    this.originalQuantity = 0,
    this.commitmentQuantity = 0,
    this.structureSequence = '',
  });

  final String unit;
  final String code;
  final String description;
  final num quantity;
  final num stock;
  final String filial;
  final String armazem;
  final num currentStock;
  final num committedQuantity;
  final num reservedQuantity;
  final String requirementSource;
  final String sourceOrder;
  final String commitmentDate;
  final num originalQuantity;
  final num commitmentQuantity;
  final String structureSequence;

  String get quantityLabel => '${formatProductionQuantity(quantity)} $unit';
  String get stockLabel => '${formatProductionQuantity(stock)} $unit';
}
