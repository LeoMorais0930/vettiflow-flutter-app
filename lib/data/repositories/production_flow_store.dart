import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_request.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_database.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_persistence.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_publisher.dart';
import 'package:vetti_flow_1_0/shared/models/finished_goods_routing.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';

class ProductionFlowStore extends ChangeNotifier {
  ProductionFlowStore({
    this.database = const EmptyProductionFlowDatabase(),
    this.protheusPublisher,
    this.filial = '04',
    ProductionFlowPersistence? persistence,
    List<ProductionOrderFlow> seedOrders = const [],
  }) : _persistence = persistence ?? ProductionFlowPersistence() {
    if (!_restore(_persistence.read())) {
      _orders.addAll(seedOrders);
      _persist();
    }
    _loadFromDatabase();
    _persistence.listen((payload) {
      if (_restore(payload)) notifyListeners();
    });
  }

  final ProductionFlowDatabase database;

  /// Quem transforma a abertura de OP em rascunho local Protheus.
  /// Nulo desliga qualquer publicacao e e o padrao seguro do app.
  final ProtheusOrderPublisher? protheusPublisher;
  final String filial;

  final ProductionFlowPersistence _persistence;
  final _smdBusy = <String>{};
  final _mutationBusy = <String>{};
  final _orders = <ProductionOrderFlow>[];
  final _catalogOverrides = <String, ProductionCatalogItem>{};
  final _protheusOutcomes = <String, ProtheusPublishOutcome>{};
  var _nextSequence = 564351;

  /// Como ficou o rascunho Protheus da OP. `null` quando nao houve tentativa.
  ///
  /// Vale ler logo depois de [createOrder]: ele so retorna depois de tentar.
  ProtheusPublishOutcome? protheusOutcome(String number) =>
      _protheusOutcomes[number];

  /// OPs criadas com rascunho local que nao chegou ao Protheus.
  List<String> get ordersNotInProtheus => [
    for (final entry in _protheusOutcomes.entries)
      if (!entry.value.gravouNoProtheus) entry.key,
  ];

  static const catalog = <ProductionCatalogItem>[];

  List<ProductionOrderFlow> get orders => List.unmodifiable(_orders);

  List<ProductionOrderFlow> ordersAtStage(ProductionStage stage) {
    return _orders.where((order) => order.currentStage == stage).toList()
      ..sort(_sortOrders);
  }

  List<ProductionOrderFlow> get activeOrders {
    return _orders.where((order) => !order.isDone).toList()..sort(_sortOrders);
  }

  List<ProductionOrderFlow> get recentCompleted {
    return _orders.where((order) => order.isDone).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<ProductionCatalogItem> get catalogItems {
    final items = <String, ProductionCatalogItem>{
      for (final item in catalog) item.code: item,
      ..._catalogOverrides,
    };
    return items.values.toList()..sort((a, b) => a.code.compareTo(b.code));
  }

  ProductionCatalogItem catalogItem(String code) {
    final normalizedCode = code.trim();
    final override = _catalogOverrides[normalizedCode];
    if (override != null) return override;
    return catalog.firstWhere(
      (item) => item.code == code,
      orElse: () => ProductionCatalogItem(
        code: normalizedCode,
        name: normalizedCode,
        defaultQuantity: 1,
        components: const [],
      ),
    );
  }

  Future<ProductionOrderFlow> createOrder({
    required String productCode,
    String? productName,
    String? productUnit,
    List<ProductionComponent> components = const [],
    required int quantity,
    required String priority,
    required String operatorName,
    String? responsavel,
    String? prazo,
    String orderWarehouse = '',
    ProductionStage initialStage = ProductionStage.warehouse,
    List<ProductionStage> plannedStages = const [],
    String? operatorPin,
  }) async {
    if (plannedStages.any((stage) => !_isRoutableStage(stage)) ||
        plannedStages.toSet().length != plannedStages.length) {
      throw ArgumentError('Escolha etapas válidas, sem repetição.');
    }
    final route = plannedStages.isNotEmpty
        ? [...plannedStages]
        : ProductionStage.productionFlow
              .where((s) => s.progressIndex >= initialStage.progressIndex)
              .toList();
    final now = DateTime.now();
    final existing = catalogItem(productCode);
    final product = ProductionCatalogItem(
      code: productCode,
      name: productName?.trim().isNotEmpty == true
          ? productName!.trim()
          : existing.name,
      defaultQuantity: quantity,
      components: components.isNotEmpty ? components : existing.components,
      unit: productUnit?.trim().isNotEmpty == true
          ? productUnit!.trim()
          : existing.unit,
    );
    if (_requiresProtheusSignature(product.components) &&
        !_hasPin(operatorPin)) {
      throw StateError('Informe o PIN para movimentar o Protheus.');
    }
    _catalogOverrides[product.code] = product;
    final number = 'OP-${now.year}-${await _reserveSequence()}';
    final order = ProductionOrderFlow(
      number: number,
      productCode: product.code,
      productName: product.name,
      quantity: quantity,
      unit: product.unit,
      currentStage: route.isEmpty ? initialStage : route.first,
      plannedStages: route,
      status: ProductionRunStatus.waiting,
      priority: priority,
      createdAt: now,
      updatedAt: now,
      operatorName: operatorName,
      operatorPin: operatorPin,
      responsavel: responsavel,
      prazo: prazo,
      orderWarehouse: orderWarehouse,
    );
    _orders.insert(0, order);
    _persist();
    notifyListeners();
    await _syncOrder(order, 'created');
    await _publishToProtheus(order, product);
    return order;
  }

  /// Tenta registrar a OP como rascunho local Protheus e guarda o resultado.
  ///
  /// Nao propaga excecao de proposito: a OP ja existe no fluxo do app e nao
  /// pode sumir porque a API caiu. O que nao pode acontecer e ficar em
  /// silencio - por isso o resultado fica em [protheusOutcome] para a tela
  /// avisar.
  Future<void> _publishToProtheus(
    ProductionOrderFlow order,
    ProductionCatalogItem product,
  ) async {
    final publisher = protheusPublisher;
    if (publisher == null) return;

    ProtheusPublishOutcome outcome;
    try {
      outcome = await publisher.publishOrder(
        order: order,
        product: product,
        filial: filial,
      );
    } catch (error, stackTrace) {
      debugPrint('Erro no rascunho Protheus ${order.number}: $error');
      debugPrintStack(stackTrace: stackTrace);
      outcome = ProtheusPublishOutcome.naFila(mutationId: '', motivo: '$error');
    }

    _protheusOutcomes[order.number] = outcome;
    notifyListeners();
  }

  Future<void> startStage(
    String number, {
    String? operatorName,
    String? operatorPin,
  }) {
    return _mutate(number, (order, now) {
      if (ProductionOrderFlow.internalProductionStages.contains(
            order.currentStage,
          ) &&
          order.productionQuantity <= 0) {
        throw StateError(
          'Não há quantidade na produção. Confira os envios e devoluções.',
        );
      }
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final current =
          timings[order.currentStage] ?? const ProductionStageTiming();
      timings[order.currentStage] = current.pausedAt == null
          ? current.start(now)
          : current.resume(now);

      final sessions = [...order.operatorSessions];
      final pauseEvents = [...order.pauseEvents];
      final signature = _signatureKey(operatorName, operatorPin);
      if (signature != null) {
        final index = _sessionIndex(
          sessions,
          order.currentStage,
          operatorName,
          operatorPin,
        );
        if (index == -1) {
          sessions.add(
            ProductionOperatorSession(
              stage: order.currentStage,
              operatorName: operatorName ?? 'Operador',
              operatorPin: operatorPin ?? signature,
              startedAt: now,
            ),
          );
        } else {
          sessions[index] = sessions[index].resume(now);
        }
        _closeLatestPauseEvent(
          pauseEvents,
          order.currentStage,
          operatorName,
          operatorPin,
          now,
        );
      }

      return order.copyWith(
        status: ProductionRunStatus.active,
        updatedAt: now,
        operatorName: () => operatorName ?? order.operatorName,
        responsavel: () {
          final name = operatorName?.trim();
          return name == null || name.isEmpty ? order.responsavel : name;
        },
        timings: timings,
        operatorSessions: sessions,
        pauseEvents: pauseEvents,
      );
    });
  }

  Future<void> pauseStage(
    String number, {
    String? operatorName,
    String? operatorPin,
    PauseReason reason = PauseReason.outro,
    String? customReason,
    int producedQuantity = 0,
  }) {
    return _mutate(number, (order, now) {
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final current =
          timings[order.currentStage] ?? const ProductionStageTiming();
      final sessions = [...order.operatorSessions];
      final signature = _signatureKey(operatorName, operatorPin);
      if (signature != null) {
        final index = _sessionIndex(
          sessions,
          order.currentStage,
          operatorName,
          operatorPin,
        );
        final safeQuantity = producedQuantity.clamp(0, order.quantity).toInt();
        if (index == -1) {
          sessions.add(
            ProductionOperatorSession(
              stage: order.currentStage,
              operatorName: operatorName ?? 'Operador',
              operatorPin: operatorPin ?? signature,
              startedAt: now,
            ).pause(now, producedQuantity: safeQuantity),
          );
        } else {
          sessions[index] = sessions[index].pause(
            now,
            producedQuantity: safeQuantity,
          );
        }
      }
      final hasRunning = _hasRunningSession(sessions, order.currentStage);
      timings[order.currentStage] = hasRunning ? current : current.pause(now);
      final pauseEvents = [
        ...order.pauseEvents,
        if (signature != null)
          ProductionPauseEvent(
            stage: order.currentStage,
            operatorName: operatorName ?? 'Operador',
            operatorPin: operatorPin ?? signature,
            reason: reason,
            customReason: customReason,
            producedQuantity: producedQuantity.clamp(0, order.quantity).toInt(),
            createdAt: now,
          ),
      ];
      return order.copyWith(
        status: hasRunning
            ? ProductionRunStatus.active
            : ProductionRunStatus.paused,
        updatedAt: now,
        timings: timings,
        operatorSessions: sessions,
        pauseEvents: pauseEvents,
      );
    });
  }

  Future<void> resetStage(String number) {
    return _mutate(number, (order, now) {
      return order.copyWith(
        status: ProductionRunStatus.waiting,
        updatedAt: now,
      );
    });
  }

  /// Volta a OP para a etapa anterior do fluxo (usado pelo dashboard).
  Future<void> regressStage(String number) {
    return _mutate(number, (order, now) {
      final routeIndex = order.plannedStages.indexOf(order.currentStage);
      final previous = order.plannedStages.isEmpty
          ? _previousStage(order.currentStage)
          : order.isDone
          ? order.plannedStages.last
          : routeIndex > 0
          ? order.plannedStages[routeIndex - 1]
          : order.currentStage;
      if (previous == ProductionStage.smd && order.smd.completedAt != null) {
        throw StateError(
          'O SMD já foi concluído. Retrabalho precisa de uma nova programação.',
        );
      }
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      )..remove(order.currentStage);
      return order.copyWith(
        currentStage: previous,
        status: ProductionRunStatus.waiting,
        updatedAt: now,
        responsavel: () => null,
        timings: timings,
      );
    });
  }

  /// Remove a OP do fluxo (cancelamento pelo dashboard).
  Future<void> cancelOrder(
    String number, {
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) async {
    if (_smdBusy.contains(number) || _mutationBusy.contains(number)) {
      throw StateError('Aguarde o registro anterior desta OP terminar.');
    }
    final index = _orders.indexWhere((order) => order.number == number);
    if (index == -1) return;
    final order = _orders[index];
    if (order.dispatchDrafts.isNotEmpty) {
      throw StateError(
        'Esta OP tem histórico de preparos de envio e não pode ser excluída.',
      );
    }
    final item = catalogItem(order.productCode);
    if (_requiresProtheusSignature(item.components) && !_hasPin(operatorPin)) {
      throw StateError('Informe o PIN para cancelar e devolver no Protheus.');
    }
    _mutationBusy.add(number);
    try {
      await database.deleteOrder(
        number,
        order: order.copyWith(updatedAt: DateTime.now()),
        catalogItem: item,
        returnWarehouses: returnWarehouses,
        operatorName: operatorName,
        operatorPin: operatorPin,
      );
      _orders.removeWhere((o) => o.number == number);
      _persist();
      notifyListeners();
    } finally {
      _mutationBusy.remove(number);
    }
  }

  Future<void> updatePlannedStages(
    String number,
    List<ProductionStage> stages,
  ) {
    return _mutate(number, (order, now) {
      final validStages = _sanitizePlannedStages(order.currentStage, stages);
      final currentIndex = validStages.indexOf(order.currentStage);
      if (order.smd.completedAt != null &&
          currentIndex >= 0 &&
          validStages.indexOf(ProductionStage.smd) > currentIndex) {
        throw StateError(
          'O SMD já foi concluído. Retrabalho precisa de uma nova programação.',
        );
      }
      return order.copyWith(plannedStages: validStages, updatedAt: now);
    });
  }

  bool canPointSmd(Operator? operator) =>
      operator != null &&
      (operator.area == WorkArea.smd ||
          (operator.area == WorkArea.system && operator.canManageAssignments));

  Future<void> releaseWarehouseOrder(
    String number, {
    required Operator operator,
    required List<WarehouseConfirmationRequest> requests,
  }) async {
    if (!_orders.any((o) => o.number == number)) {
      throw StateError('OP não encontrada.');
    }
    if (!(operator.area == WorkArea.warehouse ||
        operator.area == WorkArea.system && operator.canManageAssignments)) {
      throw StateError(
        'Somente o almoxarifado ou a administração pode liberar.',
      );
    }
    await _mutate(number, (order, now) {
      if (order.currentStage != ProductionStage.warehouse) {
        throw StateError('Esta OP já saiu do almoxarifado.');
      }
      if (requests.any(
        (r) =>
            r.orderNumber == number && !r.manual && r.remainingQuantity > 1e-8,
      )) {
        throw StateError(
          'Conclua a entrega dos materiais ou cancele o saldo não utilizado antes de liberar.',
        );
      }
      return order.copyWith(
        currentStage: order.nextStage,
        status: order.nextStage == ProductionStage.completed
            ? ProductionRunStatus.completed
            : ProductionRunStatus.waiting,
        updatedAt: now,
        responsavel: () => null,
        lastObservation: () => 'Liberação do almoxarifado por ${operator.name}',
        warehouseReleases: List.unmodifiable([
          ...order.warehouseReleases,
          WarehouseRelease(
            at: now,
            operatorName: operator.name,
            operatorUsername: operator.username,
            destination: order.nextStage,
          ),
        ]),
      );
    }, localOnly: true);
  }

  bool canPrepareProductionDispatch(Operator? operator) =>
      operator != null &&
      (operator.area == WorkArea.production &&
              operator.stage != WorkStage.expedition ||
          operator.area == WorkArea.system && operator.canManageAssignments);

  Future<void> prepareProductionDispatch(
    String number, {
    required Operator operator,
    required String entryId,
    required String destination,
    required num quantity,
    required String reason,
  }) async {
    if (!canPrepareProductionDispatch(operator)) {
      throw StateError(
        'Somente a produção ou a administração pode preparar envios.',
      );
    }
    if (!_orders.any((o) => o.number == number)) {
      throw StateError('OP não encontrada.');
    }
    await _mutate(number, (order, now) {
      final previous = order.dispatchDrafts
          .where((d) => d.id == entryId)
          .firstOrNull;
      if (previous != null) {
        if (previous.quantity == quantity &&
            previous.destination == destination &&
            previous.reason == reason.trim() &&
            previous.operatorUsername == operator.username) {
          return order;
        }
        throw StateError('Este preparo já foi registrado com outros dados.');
      }
      if (entryId.trim().isEmpty ||
          reason.trim().isEmpty ||
          reason.trim().length > 300 ||
          !ProductionDispatchDraft.destinations.containsKey(destination)) {
        throw StateError('Informe destino e motivo válidos.');
      }
      if (!order.canPrepareDispatch) {
        throw StateError(
          'Confira etapa, armazém 05, unidade e quantidade disponível da OP.',
        );
      }
      final available = order.availableToPrepare;
      if (!quantity.isFinite || quantity <= 0 || quantity > available) {
        throw StateError(
          'A quantidade não pode ultrapassar o disponível para preparar.',
        );
      }
      return order.copyWith(
        updatedAt: now,
        dispatchDrafts: List.unmodifiable([
          ...order.dispatchDrafts,
          ProductionDispatchDraft(
            id: entryId,
            quantity: quantity,
            destination: destination,
            createdAt: now,
            operatorName: operator.name,
            operatorUsername: operator.username,
            stage: order.currentStage.name,
            reason: reason.trim(),
          ),
        ]),
      );
    }, localOnly: true);
  }

  Future<void> cancelProductionDispatch(
    String number, {
    required Operator operator,
    required String entryId,
    required String reason,
  }) async {
    if (!canPrepareProductionDispatch(operator)) {
      throw StateError(
        'Somente a produção ou a administração pode cancelar preparos.',
      );
    }
    if (!_orders.any((o) => o.number == number)) {
      throw StateError('OP não encontrada.');
    }
    await _mutate(number, (order, now) {
      if (reason.trim().isEmpty || reason.trim().length > 300) {
        throw StateError(
          'Informe o motivo do cancelamento, com até 300 caracteres.',
        );
      }
      final draft = order.dispatchDrafts
          .where((d) => d.id == entryId)
          .firstOrNull;
      if (draft == null) throw StateError('Preparo não encontrado.');
      if (draft.isCancelled) return order;
      if (draft.delivered > 0) {
        throw StateError(
          'Já houve entrega. Cancele somente o restante do preparo.',
        );
      }
      return order.copyWith(
        updatedAt: now,
        dispatchDrafts: List.unmodifiable([
          for (final d in order.dispatchDrafts)
            if (d.id == entryId)
              d.cancel(now, operator.name, reason.trim())
            else
              d,
        ]),
      );
    }, localOnly: true);
  }

  bool canRecordDispatch(
    Operator? operator,
    ProductionDispatchDraft draft,
    DispatchAction action,
  ) {
    if (operator == null) return false;
    if (operator.area == WorkArea.system && operator.canManageAssignments) {
      return true;
    }
    final sector = action.sector == 'destination'
        ? (draft.isSupport ? 'support' : 'expedition')
        : action.sector;
    return switch (sector) {
      'production' => canPrepareProductionDispatch(operator),
      'support' => operator.area == WorkArea.support,
      'expedition' => operator.canOperate(AppSector.expedition),
      _ => false,
    };
  }

  Future<void> recordDispatchEvent(
    String number, {
    required String draftId,
    required String eventId,
    required DispatchAction action,
    required num quantity,
    required String note,
    required Operator operator,
    ProductionStage? returnStage,
    String reference = '',
  }) async {
    if (!_orders.any((o) => o.number == number)) {
      throw StateError('OP não encontrada.');
    }
    await _mutate(number, (order, now) {
      final draft = order.dispatchDrafts
          .where((d) => d.id == draftId)
          .firstOrNull;
      if (draft == null || !canRecordDispatch(operator, draft, action)) {
        throw StateError(
          'Esta ação pertence ao setor responsável pela movimentação.',
        );
      }
      final existing = draft.events.where((e) => e.id == eventId).firstOrNull;
      if (existing != null) {
        if (existing.action == action &&
            existing.quantity == quantity &&
            existing.note == note.trim() &&
            existing.operatorUsername == operator.username &&
            existing.stage == (returnStage?.name ?? '') &&
            existing.reference == reference.trim()) {
          return order;
        }
        throw StateError('Este registro já existe com outros dados.');
      }
      if (eventId.trim().isEmpty ||
          note.trim().isEmpty ||
          note.trim().length > 500 ||
          reference.length > 120) {
        throw StateError('Informe o motivo ou resultado (até 500 caracteres).');
      }
      final limit = draft.limitFor(action);
      if (draft.isCancelled ||
          limit <= 0 ||
          !quantity.isFinite ||
          (action.requiresQuantity
              ? quantity <= 0 || quantity > limit
              : quantity != 0)) {
        throw StateError('Confira a quantidade disponível para esta ação.');
      }
      if (action.sector == 'support' && !draft.isSupport) {
        throw StateError('Este envio não pertence ao suporte.');
      }
      if (action == DispatchAction.deliver &&
          draft.destination == '10' &&
          !order.readyForExpedition) {
        throw StateError(
          'Conclua a sequência da produção antes de entregar à expedição.',
        );
      }
      if (action == DispatchAction.ship && reference.trim().isEmpty) {
        throw StateError(
          'Informe a referência do despacho (pedido, documento ou identificação local).',
        );
      }
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final history = Map<ProductionStage, List<ProductionStageTiming>>.from(
        order.timingHistory,
      );
      var stage = order.currentStage;
      var status = order.status;
      if (action == DispatchAction.receiveReturn) {
        final route = order.plannedStages.isEmpty
            ? ProductionStage.productionFlow
            : order.plannedStages;
        if (returnStage == null ||
            !ProductionOrderFlow.internalProductionStages.contains(
              returnStage,
            ) ||
            !route.contains(returnStage)) {
          throw StateError(
            'Escolha uma etapa de produção da sequência desta OP.',
          );
        }
        if (ProductionOrderFlow.internalProductionStages.contains(stage)) {
          if (returnStage != stage) {
            throw StateError(
              'A OP está em ${stage.label}. Receba nessa etapa para manter a sequência em andamento.',
            );
          }
        } else {
          if (order.smd.completedAt != null &&
              route
                  .skip(route.indexOf(returnStage))
                  .contains(ProductionStage.smd)) {
            throw StateError(
              'Esta volta passaria por um SMD já concluído. Ajuste a programação do retrabalho antes de receber.',
            );
          }
          if (order.activeSessionsAt(stage).isNotEmpty) {
            throw StateError(
              'Encerre as sessões da etapa atual antes de receber a devolução.',
            );
          }
          stage = returnStage;
          status = ProductionRunStatus.waiting;
          // A retomada reabre as etapas seguintes, preservando cada visita anterior.
          for (final s in route.skip(route.indexOf(stage))) {
            final old = timings.remove(s);
            if (old != null) {
              history[s] = List.unmodifiable([...(history[s] ?? []), old]);
            }
          }
        }
      } else if (returnStage != null) {
        throw StateError(
          'A etapa de retorno só se aplica ao recebimento na produção.',
        );
      }
      final updatedDraft = draft.addEvent(
        DispatchEvent(
          id: eventId,
          action: action,
          quantity: quantity,
          at: now,
          operatorName: operator.name,
          operatorUsername: operator.username,
          note: note.trim(),
          stage: returnStage?.name ?? '',
          reference: reference.trim(),
        ),
      );
      final drafts = List<ProductionDispatchDraft>.unmodifiable([
        for (final d in order.dispatchDrafts)
          if (d.id == draftId) updatedDraft else d,
      ]);
      final accounted =
          order.storedQuantity +
          order.dispatchedQuantity +
          drafts.fold<num>(0, (sum, d) => sum + d.stored + d.shipped);
      if (stage == ProductionStage.expedition &&
          order.nextStage == ProductionStage.completed &&
          accounted >= order.quantity &&
          order.activeSessionsAt(stage).isEmpty) {
        stage = ProductionStage.completed;
        status = ProductionRunStatus.completed;
      }
      return order.copyWith(
        updatedAt: now,
        currentStage: stage,
        status: status,
        timings: timings,
        timingHistory: history,
        dispatchDrafts: drafts,
      );
    }, localOnly: true);
  }

  Future<void> _changeSmd(
    String number,
    Operator operator,
    ProductionOrderFlow Function(ProductionOrderFlow, DateTime) change,
  ) async {
    if (!canPointSmd(operator)) {
      throw StateError('Somente o SMD ou a administração pode apontar.');
    }
    if (!_orders.any((o) => o.number == number)) {
      throw StateError('OP não encontrada no VettiFlow.');
    }
    if (!_smdBusy.add(number)) {
      throw StateError('Aguarde o registro anterior terminar.');
    }
    try {
      await _mutate(number, change, smdOperation: true);
    } finally {
      _smdBusy.remove(number);
    }
  }

  void _requireSmd(ProductionOrderFlow order) {
    if (order.currentStage != ProductionStage.smd ||
        order.smd.completedAt != null ||
        (order.plannedStages.isNotEmpty &&
            !order.plannedStages.contains(ProductionStage.smd))) {
      throw StateError('Esta OP não está disponível para apontamento no SMD.');
    }
  }

  Future<void> pointSmd(
    String number, {
    required Operator operator,
    required String entryId,
    required num quantity,
    String note = '',
  }) => _changeSmd(number, operator, (order, now) {
    if (entryId.trim().isEmpty) {
      throw StateError('Identificação do apontamento inválida.');
    }
    final previous = order.smd.entries
        .where((e) => e.id == entryId)
        .firstOrNull;
    if (previous != null) {
      if (!previous.isReversal &&
          previous.quantity == quantity &&
          previous.operatorName == operator.name &&
          previous.note == note.trim()) {
        return order;
      }
      throw StateError('Este apontamento já foi registrado com outros dados.');
    }
    _requireSmd(order);
    final remaining = order.smd.remaining(order.quantity);
    if (!quantity.isFinite ||
        quantity <= 0 ||
        remaining <= 0 ||
        quantity > remaining + remaining.abs() * 1e-10) {
      throw StateError(
        'A quantidade deve ser maior que zero e não pode ultrapassar o restante.',
      );
    }
    return order.copyWith(
      updatedAt: now,
      smd: SmdProgress(
        entries: List.unmodifiable([
          ...order.smd.entries,
          SmdPointing(
            id: entryId,
            quantity: quantity.clamp(0, remaining),
            at: now,
            operatorName: operator.name,
            note: note.trim(),
          ),
        ]),
      ),
    );
  });

  Future<void> reverseSmdPointing(
    String number, {
    required Operator operator,
    required String pointingId,
    required String reason,
  }) => _changeSmd(number, operator, (order, now) {
    _requireSmd(order);
    if (reason.trim().isEmpty) {
      throw StateError('Informe o motivo da correção.');
    }
    final entry = order.smd.entries
        .where((e) => e.id == pointingId && !e.isReversal)
        .firstOrNull;
    if (entry == null) throw StateError('Apontamento não encontrado.');
    if (order.smd.isReversed(pointingId)) return order;
    return order.copyWith(
      updatedAt: now,
      smd: SmdProgress(
        entries: List.unmodifiable([
          ...order.smd.entries,
          SmdPointing(
            id: 'reverse:$pointingId',
            reversalOf: pointingId,
            quantity: entry.quantity,
            at: now,
            operatorName: operator.name,
            note: reason.trim(),
          ),
        ]),
      ),
    );
  });

  Future<void> completeSmd(
    String number, {
    required Operator operator,
  }) => _changeSmd(number, operator, (order, now) {
    _requireSmd(order);
    if (order.quantity <= 0 || order.smd.remaining(order.quantity) > 1e-8) {
      throw StateError('Aponte a quantidade restante antes de concluir o SMD.');
    }
    final timings = Map<ProductionStage, ProductionStageTiming>.from(
      order.timings,
    );
    final timing = timings[ProductionStage.smd];
    // Finaliza somente tempos já medidos; um apontamento não cria horas trabalhadas.
    if (timing?.startedAt != null) {
      timings[ProductionStage.smd] = timing!.complete(now);
    }
    return order.copyWith(
      currentStage: order.nextStage,
      status: order.nextStage == ProductionStage.completed
          ? ProductionRunStatus.completed
          : ProductionRunStatus.waiting,
      updatedAt: now,
      responsavel: () => null,
      timings: timings,
      operatorSessions: order.operatorSessions
          .map(
            (s) => s.stage == ProductionStage.smd && !s.isCompleted
                ? s.complete(now)
                : s,
          )
          .toList(),
      smd: SmdProgress(
        entries: order.smd.entries,
        completedAt: now,
        completedBy: operator.name,
      ),
    );
  });

  Future<void> completeStage(
    String number, {
    String? observation,
    String? operatorName,
    String? operatorPin,
    List<DefectRecord> defects = const [],
    ProductionStage? expectedStage,
  }) {
    return _mutate(number, (order, now) {
      if (expectedStage != null && order.currentStage != expectedStage) {
        throw StateError(
          'A etapa desta OP mudou. Atualize a fila antes de concluir.',
        );
      }
      if (order.currentStage == ProductionStage.smd) {
        throw StateError('Conclua esta etapa em SMD → Apontar no VettiFlow.');
      }
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final current =
          timings[order.currentStage] ??
          const ProductionStageTiming(startedAt: null);
      final sessions = [...order.operatorSessions];
      final pauseEvents = [...order.pauseEvents];
      final signature = _signatureKey(operatorName, operatorPin);
      if (signature != null) {
        _closeLatestPauseEvent(
          pauseEvents,
          order.currentStage,
          operatorName,
          operatorPin,
          now,
        );
        final index = _sessionIndex(
          sessions,
          order.currentStage,
          operatorName,
          operatorPin,
        );
        if (index == -1) {
          sessions.add(
            ProductionOperatorSession(
              stage: order.currentStage,
              operatorName: operatorName ?? 'Operador',
              operatorPin: operatorPin ?? signature,
              startedAt: now,
              completedAt: now,
            ),
          );
        } else {
          sessions[index] = sessions[index].complete(now);
        }
        final remaining = _activeSessions(sessions, order.currentStage);
        if (remaining.isNotEmpty) {
          final status = remaining.any((session) => session.isRunning)
              ? ProductionRunStatus.active
              : ProductionRunStatus.paused;
          return order.copyWith(
            status: status,
            updatedAt: now,
            lastObservation: () {
              final note = observation?.trim();
              return note == null || note.isEmpty ? null : note;
            },
            operatorSessions: sessions,
            testDefects: [...order.testDefects, ...defects],
            pauseEvents: pauseEvents,
          );
        }
      }
      timings[order.currentStage] =
          (current.startedAt == null ? current.start(now) : current).complete(
            now,
          );
      return order.copyWith(
        currentStage: order.nextStage,
        status: order.nextStage == ProductionStage.completed
            ? ProductionRunStatus.completed
            : ProductionRunStatus.waiting,
        updatedAt: now,
        responsavel: () => null,
        lastObservation: () {
          final note = observation?.trim();
          return note == null || note.isEmpty ? null : note;
        },
        timings: timings,
        operatorSessions: sessions,
        testDefects: defects.isEmpty
            ? order.testDefects
            : [...order.testDefects, ...defects],
        pauseEvents: pauseEvents,
      );
    });
  }

  /// Conclui o teste registrando os defeitos encontrados (tipo + quantidade)
  /// e avança a OP para a etapa seguinte.
  Future<void> completeTesting(
    String number, {
    required List<DefectRecord> defects,
    String? operatorName,
    String? operatorPin,
  }) => completeStage(
    number,
    defects: defects,
    operatorName: operatorName,
    operatorPin: operatorPin,
    expectedStage: ProductionStage.testing,
  );

  Future<void> completeClosing(String number, {required int closedQuantity}) {
    return _mutate(number, (order, now) {
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final current =
          timings[order.currentStage] ??
          const ProductionStageTiming(startedAt: null);
      timings[order.currentStage] = current
          .start(current.startedAt ?? now)
          .complete(now);
      final safeClosed = closedQuantity.clamp(0, order.quantity).toInt();
      return order.copyWith(
        currentStage: order.nextStage,
        status: order.nextStage == ProductionStage.completed
            ? ProductionRunStatus.completed
            : ProductionRunStatus.waiting,
        updatedAt: now,
        closedQuantity: safeClosed,
        timings: timings,
      );
    });
  }

  Future<void> completeExpedition(
    String number, {
    required int storedQuantity,
  }) {
    return _mutate(number, (order, now) {
      if (order.preparedQuantity > 0) {
        throw StateError(
          'Esta OP tem preparos por quantidade. Confira os preparos antes de finalizar o lote inteiro.',
        );
      }
      final item = catalogItem(order.productCode);
      final routing = FinishedGoodsRouting.suggest(
        productCode: order.productCode,
        orderWarehouse: order.orderWarehouse,
        componentWarehouses: item.components.map((component) {
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
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final current =
          timings[order.currentStage] ??
          const ProductionStageTiming(startedAt: null);
      timings[order.currentStage] = current
          .start(current.startedAt ?? now)
          .complete(now);
      final safeStored = storedQuantity.clamp(0, order.quantity).toInt();
      return order.copyWith(
        currentStage: safeStored > 0
            ? ProductionStage.storage
            : ProductionStage.completed,
        status: ProductionRunStatus.completed,
        updatedAt: now,
        componentConsumptionWarehouse: routing.componentConsumptionWarehouse,
        finishedGoodsWarehouse: routing.finishedGoodsWarehouse,
        routingWarnings: routing.warnings,
        storedQuantity: safeStored,
        dispatchedQuantity: order.quantity - safeStored,
        timings: timings,
      );
    });
  }

  Future<void> dispatchStored(String number, {required int quantity}) {
    return _mutate(number, (order, now) {
      if (order.currentStage != ProductionStage.storage) return order;
      final safeQuantity = quantity.clamp(0, order.storedQuantity).toInt();
      if (safeQuantity <= 0) return order;
      final remainingStored = order.storedQuantity - safeQuantity;
      return order.copyWith(
        currentStage: remainingStored == 0
            ? ProductionStage.completed
            : ProductionStage.storage,
        status: ProductionRunStatus.completed,
        updatedAt: now,
        storedQuantity: remainingStored,
        dispatchedQuantity: order.dispatchedQuantity + safeQuantity,
      );
    });
  }

  Future<void> _mutate(
    String number,
    ProductionOrderFlow Function(ProductionOrderFlow order, DateTime now)
    update, {
    bool smdOperation = false,
    bool localOnly = false,
  }) async {
    if (_smdBusy.contains(number) && !smdOperation) {
      throw StateError('Aguarde o registro do SMD terminar.');
    }
    final index = _orders.indexWhere((order) => order.number == number);
    if (index == -1) return;
    if (!_mutationBusy.add(number)) {
      throw StateError('Aguarde o registro anterior desta OP terminar.');
    }
    try {
      final previous = _orders[index];
      final updated = update(previous, DateTime.now());
      if (identical(previous, updated)) return;
      if (!localOnly) await _syncOrder(updated, 'updated');
      // Outra OP pode ter sido removida enquanto a persistência estava em curso.
      final currentIndex = _orders.indexWhere((o) => o.number == number);
      if (currentIndex == -1) {
        throw StateError('A OP não está mais disponível.');
      }
      _orders[currentIndex] = updated;
      try {
        _persist();
      } catch (_) {
        _orders[currentIndex] = previous;
        rethrow;
      }
      notifyListeners();
    } finally {
      _mutationBusy.remove(number);
    }
  }

  Future<void> _loadFromDatabase() async {
    try {
      final snapshot = await database.loadSnapshot();
      if (snapshot.orders.isEmpty) return;
      _orders
        ..clear()
        ..addAll(snapshot.orders);
      _catalogOverrides
        ..clear()
        ..addEntries(
          snapshot.catalogItems.map((item) => MapEntry(item.code, item)),
        );
      _nextSequence = _nextSequenceFrom(snapshot.orders);
      _persist();
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Erro ao carregar OPs do banco: $error');
      debugPrintStack(stackTrace: stackTrace);
      // O app continua pelo cache local quando a persistencia estiver indisponivel.
    }
  }

  Future<void> _syncOrder(ProductionOrderFlow order, String eventType) async {
    final product = catalogItem(order.productCode);
    try {
      await database.saveOrder(order, product, eventType: eventType);
    } catch (error, stackTrace) {
      debugPrint('Erro ao sincronizar OP ${order.number} no banco: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Reserva o numero da proxima OP.
  ///
  /// O banco e a fonte da verdade: a reserva e atomica, entao duas maquinas no
  /// mesmo ambiente nunca recebem o mesmo numero. O contador local so entra
  /// quando o banco esta fora do ar — e ai a OP fica no cache ate voltar.
  Future<int> _reserveSequence() async {
    try {
      final reserved = await database.nextOrderSequence();
      if (reserved != null) {
        if (reserved >= _nextSequence) _nextSequence = reserved + 1;
        return reserved;
      }
    } catch (error) {
      debugPrint('Erro ao reservar numero de OP no banco: $error');
    }
    return _nextSequence++;
  }

  int _nextSequenceFrom(List<ProductionOrderFlow> orders) {
    var next = _nextSequence;
    for (final order in orders) {
      final sequence = int.tryParse(order.number.split('-').last);
      if (sequence != null && sequence >= next) next = sequence + 1;
    }
    return next;
  }

  void _persist() {
    _persistence.write(
      jsonEncode({
        'nextSequence': _nextSequence,
        'catalogOverrides': _catalogOverrides.values
            .map(_catalogItemToJson)
            .toList(),
        'orders': _orders.map(_orderToJson).toList(),
      }),
    );
  }

  bool _restore(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final orders = decoded['orders'] as List<dynamic>;
      final catalogOverrides = decoded['catalogOverrides'] as List<dynamic>?;
      _catalogOverrides
        ..clear()
        ..addEntries(
          (catalogOverrides ?? const [])
              .map((item) => _catalogItemFromJson(item as Map<String, dynamic>))
              .map((item) => MapEntry(item.code, item)),
        );
      _orders
        ..clear()
        ..addAll(
          orders.map((order) => _orderFromJson(order as Map<String, dynamic>)),
        );
      _nextSequence =
          (decoded['nextSequence'] as num?)?.toInt() ?? _nextSequence;
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _catalogItemToJson(ProductionCatalogItem item) {
    return {
      'code': item.code,
      'name': item.name,
      'defaultQuantity': item.defaultQuantity,
      'unit': item.unit,
      'components': item.components.map(_componentToJson).toList(),
    };
  }

  ProductionCatalogItem _catalogItemFromJson(Map<String, dynamic> json) {
    return ProductionCatalogItem(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      defaultQuantity: (json['defaultQuantity'] as num?)?.toInt() ?? 1,
      unit: json['unit'] as String? ?? 'PC',
      components:
          (json['components'] as List<dynamic>?)
              ?.map(
                (component) =>
                    _componentFromJson(component as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> _componentToJson(ProductionComponent component) {
    return {
      'code': component.code,
      'unit': component.unit,
      'description': component.description,
      'quantity': component.quantity,
      'stock': component.stock,
      'filial': component.filial,
      'armazem': component.armazem,
      'currentStock': component.currentStock,
      'committedQuantity': component.committedQuantity,
      'reservedQuantity': component.reservedQuantity,
      'requirementSource': component.requirementSource,
      'sourceOrder': component.sourceOrder,
      'commitmentDate': component.commitmentDate,
      'originalQuantity': component.originalQuantity,
      'commitmentQuantity': component.commitmentQuantity,
      'structureSequence': component.structureSequence,
    };
  }

  ProductionComponent _componentFromJson(Map<String, dynamic> json) {
    return ProductionComponent(
      code: json['code'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      description: json['description'] as String? ?? '',
      quantity: (json['quantity'] as num?) ?? 0,
      stock: (json['stock'] as num?) ?? 0,
      filial: json['filial'] as String? ?? '',
      armazem: json['armazem'] as String? ?? '',
      currentStock: (json['currentStock'] as num?) ?? 0,
      committedQuantity: (json['committedQuantity'] as num?) ?? 0,
      reservedQuantity: (json['reservedQuantity'] as num?) ?? 0,
      requirementSource: json['requirementSource'] as String? ?? 'SG1',
      sourceOrder: json['sourceOrder'] as String? ?? '',
      commitmentDate: json['commitmentDate'] as String? ?? '',
      originalQuantity: (json['originalQuantity'] as num?) ?? 0,
      commitmentQuantity: (json['commitmentQuantity'] as num?) ?? 0,
      structureSequence: json['structureSequence'] as String? ?? '',
    );
  }

  Map<String, dynamic> _orderToJson(ProductionOrderFlow order) {
    return {
      'number': order.number,
      'productCode': order.productCode,
      'productName': order.productName,
      'quantity': order.quantity,
      'unit': order.unit,
      'smd': order.smd.toJson(),
      'dispatchDrafts': order.dispatchDrafts.map((d) => d.toJson()).toList(),
      'currentStage': order.currentStage.name,
      'status': order.status.name,
      'priority': order.priority,
      'createdAt': order.createdAt.toIso8601String(),
      'updatedAt': order.updatedAt.toIso8601String(),
      'operatorName': order.operatorName,
      'operatorPin': order.operatorPin,
      'responsavel': order.responsavel,
      'prazo': order.prazo,
      'orderWarehouse': order.orderWarehouse,
      'componentConsumptionWarehouse': order.componentConsumptionWarehouse,
      'finishedGoodsWarehouse': order.finishedGoodsWarehouse,
      'routingWarnings': order.routingWarnings,
      'closedQuantity': order.closedQuantity,
      'lastObservation': order.lastObservation,
      'storedQuantity': order.storedQuantity,
      'dispatchedQuantity': order.dispatchedQuantity,
      'timings': {
        for (final entry in order.timings.entries)
          entry.key.name: _timingToJson(entry.value),
      },
      'timingHistory': {
        for (final e in order.timingHistory.entries)
          e.key.name: e.value.map(_timingToJson).toList(),
      },
      'warehouseReleases': order.warehouseReleases
          .map((e) => e.toJson())
          .toList(),
      'testDefects': order.testDefects.map((d) => d.toJson()).toList(),
      'operatorSessions': order.operatorSessions
          .map((s) => s.toJson())
          .toList(),
      'pauseEvents': order.pauseEvents.map((p) => p.toJson()).toList(),
      'plannedStages': order.plannedStages.map((stage) => stage.name).toList(),
    };
  }

  ProductionOrderFlow _orderFromJson(Map<String, dynamic> json) {
    return ProductionOrderFlow(
      number: json['number'] as String,
      productCode: json['productCode'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      quantity: (json['quantity'] as num).toInt(),
      unit: json['unit'] as String? ?? '',
      dispatchDrafts: List.unmodifiable(
        (json['dispatchDrafts'] as List? ?? []).map(
          (d) => ProductionDispatchDraft.fromJson(
            Map<String, dynamic>.from(d as Map),
          ),
        ),
      ),
      smd: SmdProgress.fromJson(
        Map<String, dynamic>.from(json['smd'] as Map? ?? {}),
      ),
      currentStage: _stageFromName(json['currentStage'] as String?),
      status: _statusFromName(json['status'] as String?),
      priority: json['priority'] as String? ?? 'Media',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      operatorName: json['operatorName'] as String?,
      operatorPin: json['operatorPin'] as String?,
      responsavel: json['responsavel'] as String?,
      prazo: json['prazo'] as String?,
      orderWarehouse: json['orderWarehouse'] as String? ?? '',
      componentConsumptionWarehouse:
          json['componentConsumptionWarehouse'] as String? ?? '',
      finishedGoodsWarehouse: json['finishedGoodsWarehouse'] as String? ?? '',
      routingWarnings:
          (json['routingWarnings'] as List<dynamic>?)
              ?.map((item) => item as String)
              .toList() ??
          const [],
      closedQuantity: (json['closedQuantity'] as num?)?.toInt() ?? 0,
      lastObservation: json['lastObservation'] as String?,
      storedQuantity: (json['storedQuantity'] as num?)?.toInt() ?? 0,
      dispatchedQuantity: (json['dispatchedQuantity'] as num?)?.toInt() ?? 0,
      timings: _timingsFromJson(json['timings'] as Map<String, dynamic>?),
      warehouseReleases: List.unmodifiable(
        (json['warehouseReleases'] as List? ?? []).map(
          (e) => WarehouseRelease.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      ),
      timingHistory: {
        for (final e
            in (json['timingHistory'] as Map<String, dynamic>? ?? {}).entries)
          _stageFromName(e.key): (e.value as List)
              .map((v) => _timingFromJson(Map<String, dynamic>.from(v as Map)))
              .toList(),
      },
      testDefects:
          (json['testDefects'] as List<dynamic>?)
              ?.map((d) => DefectRecord.fromJson(d as Map<String, dynamic>))
              .toList() ??
          const [],
      operatorSessions:
          (json['operatorSessions'] as List<dynamic>?)
              ?.map(
                (s) => ProductionOperatorSession.fromJson(
                  s as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
      pauseEvents:
          (json['pauseEvents'] as List<dynamic>?)
              ?.map(
                (p) => ProductionPauseEvent.fromJson(p as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      plannedStages:
          (json['plannedStages'] as List<dynamic>?)
              ?.map((stage) => _stageFromName(stage as String?))
              .where(_isRoutableStage)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> _timingToJson(ProductionStageTiming timing) {
    return {
      'startedAt': timing.startedAt?.toIso8601String(),
      'completedAt': timing.completedAt?.toIso8601String(),
      'pausedAt': timing.pausedAt?.toIso8601String(),
      'pausedDurationMs': timing.pausedDuration.inMilliseconds,
    };
  }

  Map<ProductionStage, ProductionStageTiming> _timingsFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) return const {};
    return {
      for (final entry in json.entries)
        _stageFromName(entry.key): _timingFromJson(
          entry.value as Map<String, dynamic>,
        ),
    };
  }

  ProductionStageTiming _timingFromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) =>
        value is String ? DateTime.parse(value) : null;
    return ProductionStageTiming(
      startedAt: parseDate(json['startedAt']),
      completedAt: parseDate(json['completedAt']),
      pausedAt: parseDate(json['pausedAt']),
      pausedDuration: Duration(
        milliseconds: (json['pausedDurationMs'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  ProductionStage _stageFromName(String? name) {
    return ProductionStage.values.firstWhere(
      (stage) => stage.name == name,
      orElse: () => ProductionStage.warehouse,
    );
  }

  ProductionRunStatus _statusFromName(String? name) {
    return ProductionRunStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => ProductionRunStatus.waiting,
    );
  }

  List<ProductionStage> _sanitizePlannedStages(
    ProductionStage currentStage,
    List<ProductionStage> stages,
  ) {
    final route = <ProductionStage>[];
    for (final stage in stages) {
      if (!_isRoutableStage(stage)) continue;
      if (!route.contains(stage)) route.add(stage);
    }
    if (_isRoutableStage(currentStage) && !route.contains(currentStage)) {
      route.insert(0, currentStage);
    }
    return route;
  }

  bool _isRoutableStage(ProductionStage stage) =>
      ProductionStage.productionFlow.contains(stage);

  bool _requiresProtheusSignature(List<ProductionComponent> components) {
    return components.any(_movesProtheusStock);
  }

  bool _movesProtheusStock(ProductionComponent component) {
    return component.code.trim().isNotEmpty &&
        component.armazem.trim().isNotEmpty &&
        component.quantity > 0 &&
        !component.code.toUpperCase().startsWith('MOD');
  }

  bool _hasPin(String? operatorPin) => operatorPin?.trim().isNotEmpty ?? false;

  ProductionStage _previousStage(ProductionStage stage) {
    final flow = ProductionStage.productionFlow;
    final index = flow.indexOf(stage);
    if (index == -1) {
      return flow.last; // storage/completed -> volta p/ expedicao
    }
    if (index == 0) return flow.first;
    return flow[index - 1];
  }

  int _sortOrders(ProductionOrderFlow a, ProductionOrderFlow b) {
    if (a.isHighPriority != b.isHighPriority) {
      return a.isHighPriority ? -1 : 1;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  }

  String? _signatureKey(String? operatorName, String? operatorPin) {
    final pin = operatorPin?.trim();
    if (pin != null && pin.isNotEmpty) return pin;
    final name = operatorName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return null;
  }

  int _sessionIndex(
    List<ProductionOperatorSession> sessions,
    ProductionStage stage,
    String? operatorName,
    String? operatorPin,
  ) {
    final signature = _signatureKey(operatorName, operatorPin);
    if (signature == null) return -1;
    return sessions.indexWhere(
      (session) =>
          session.stage == stage &&
          !session.isCompleted &&
          (session.operatorPin == signature ||
              session.operatorName.toLowerCase() == signature.toLowerCase()),
    );
  }

  List<ProductionOperatorSession> _activeSessions(
    List<ProductionOperatorSession> sessions,
    ProductionStage stage,
  ) {
    return sessions
        .where((session) => session.stage == stage && !session.isCompleted)
        .toList();
  }

  bool _hasRunningSession(
    List<ProductionOperatorSession> sessions,
    ProductionStage stage,
  ) {
    return sessions.any(
      (session) => session.stage == stage && session.isRunning,
    );
  }

  void _closeLatestPauseEvent(
    List<ProductionPauseEvent> pauseEvents,
    ProductionStage stage,
    String? operatorName,
    String? operatorPin,
    DateTime now,
  ) {
    final signature = _signatureKey(operatorName, operatorPin);
    if (signature == null) return;
    for (var i = pauseEvents.length - 1; i >= 0; i--) {
      final event = pauseEvents[i];
      if (event.stage == stage &&
          event.resumedAt == null &&
          (event.operatorPin == signature ||
              event.operatorName.toLowerCase() == signature.toLowerCase())) {
        pauseEvents[i] = event.copyWith(resumedAt: () => now);
        return;
      }
    }
  }
}
