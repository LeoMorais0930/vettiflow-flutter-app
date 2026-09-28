import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:flutter/foundation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_request.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_database.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';

class WarehouseRequestStore extends ChangeNotifier {
  WarehouseRequestStore({
    this.database = const EmptyWarehouseRequestDatabase(),
    List<WarehouseConfirmationRequest> seedRequests = const [],
  }) {
    _requests.addAll(seedRequests);
    _loadFromDatabase();
  }

  final WarehouseRequestDatabase database;
  final _requests = <WarehouseConfirmationRequest>[];
  String? persistenceError;
  final _unsaved = <String, WarehouseConfirmationRequest>{};
  bool _loadFailed = false;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool canHandle(WarehouseConfirmationRequest request, Operator? operator) =>
      canReceiveAt(request.requestedWarehouse, operator);

  bool canReceiveAt(String warehouse, Operator? operator) {
    if (operator == null) return false;
    if (operator.area == WorkArea.system && operator.canManageAssignments) {
      return true;
    }
    return switch (warehouse) {
      '01' => operator.area == WorkArea.warehouse,
      '05' =>
        operator.area == WorkArea.production &&
            operator.stage != WorkStage.expedition,
      '06' || '07' => operator.area == WorkArea.support,
      '10' => operator.canOperate(AppSector.expedition),
      // Paula continua no apontamento; a conferência de materiais do SMD é administrativa.
      _ => false,
    };
  }

  bool canRecordMaterial(
    WarehouseConfirmationRequest request,
    Operator? operator,
    WarehouseMaterialAction action,
  ) =>
      [
        WarehouseMaterialAction.received,
        WarehouseMaterialAction.used,
        WarehouseMaterialAction.returnSent,
      ].contains(action)
      ? canReceiveAt(request.orderWarehouse, operator)
      : canHandle(request, operator);

  void recordMaterialEvent(
    String id,
    Operator operator,
    num quantity,
    WarehouseMaterialAction action, {
    required String eventId,
    required String note,
  }) {
    if ([
          WarehouseMaterialAction.confirmed,
          WarehouseMaterialAction.rejected,
        ].contains(action) ||
        eventId.trim().isEmpty) {
      throw StateError('Ação de material inválida.');
    }
    _recordQuantity(
      id,
      operator,
      quantity,
      action,
      note: note,
      eventId: eventId,
    );
  }

  WarehouseConfirmationRequest createLinkedRequest({
    required ProductionOrderFlow order,
    required Operator operator,
    required String componentCode,
    required String description,
    required String unit,
    required num quantity,
    required String destination,
    required String requestId,
  }) {
    if (!canReceiveAt(destination, operator) ||
        componentCode.trim().isEmpty ||
        unit.trim().isEmpty ||
        requestId.trim().isEmpty) {
      throw StateError('Confira o setor, material e unidade da solicitação.');
    }
    final old = _requests.where((r) => r.id == requestId).firstOrNull;
    if (old != null) {
      if (old.orderNumber == order.number &&
          old.componentCode == componentCode &&
          old.quantity == quantity &&
          old.orderWarehouse == destination &&
          old.unit == unit) {
        return old;
      }
      throw StateError('Esta solicitação já existe com outros dados.');
    }
    return createManualRequest(
      productCode: order.productCode,
      productName: order.productName,
      componentCode: componentCode,
      componentDescription: description,
      unit: unit,
      quantity: quantity,
      filial: '04',
      orderWarehouse: destination,
      requestedWarehouse: '01',
      requestedBy: operator.name,
      orderNumber: order.number,
      requestId: requestId,
    );
  }

  List<WarehouseConfirmationRequest> get requests =>
      List.unmodifiable(_requests);

  List<WarehouseConfirmationRequest> pendingForArea(WorkArea? area) {
    final values =
        _requests
            .where((request) => request.isPending)
            .where((request) => area == null || request.area == area)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  bool canCreateManualRequest(WorkArea? area) {
    return area == WorkArea.warehouse || area == WorkArea.smd;
  }

  List<WarehouseConfirmationRequest> createForOrder({
    required ProductionOrderFlow order,
    required ProductionCatalogItem catalogItem,
    required String orderWarehouse,
    required String requestedBy,
  }) {
    final normalizedOrderWarehouse = WarehouseRouting.normalizeCode(
      orderWarehouse,
    );
    final now = DateTime.now();
    final created = <WarehouseConfirmationRequest>[];
    final grouped = <String, WarehouseConfirmationRequest>{};
    for (final component in catalogItem.components) {
      if (component.code.trim().toUpperCase().startsWith('MOD')) continue;
      if (component.armazem.trim().isEmpty) continue;
      final componentWarehouse = WarehouseRouting.normalizeCode(
        component.armazem,
      );
      if (!WarehouseRouting.operationalCodes.contains(componentWarehouse) ||
          (componentWarehouse == normalizedOrderWarehouse &&
              componentWarehouse != '01')) {
        continue;
      }
      final quantity = component.quantity * order.quantity;
      if (!quantity.isFinite || quantity <= 0) continue;
      final filial = component.filial.trim().isEmpty
          ? '04'
          : component.filial.trim();
      final unit = component.unit.trim().toUpperCase();
      final id =
          '${_idFor(order.number, component.code, componentWarehouse)}-$filial-$unit';
      final request = WarehouseConfirmationRequest(
        id: id,
        orderNumber: order.number,
        productCode: order.productCode,
        productName: order.productName,
        componentCode: component.code,
        componentDescription: component.description,
        quantity: quantity + (grouped[id]?.quantity ?? 0),
        unit: unit,
        filial: filial,
        orderWarehouse: normalizedOrderWarehouse,
        requestedWarehouse: componentWarehouse,
        requestedBy: requestedBy.trim(),
        createdAt: now,
        updatedAt: now,
      );
      grouped[id] = request;
    }
    for (final request in grouped.values) {
      // Repetir a criação não apaga confirmações nem entregas anteriores.
      if (_requests.any((item) => item.id == request.id)) continue;
      _upsertLocal(request);
      created.add(request);
    }
    if (created.isNotEmpty) {
      notifyListeners();
      for (final request in created) {
        _save(request);
      }
    }
    return created;
  }

  WarehouseConfirmationRequest createManualRequest({
    String orderNumber = 'Manual',
    String? requestId,
    required String productCode,
    required String productName,
    required String componentCode,
    required String componentDescription,
    required num quantity,
    String unit = '',
    required String filial,
    required String orderWarehouse,
    required String requestedWarehouse,
    required String requestedBy,
  }) {
    if (!quantity.isFinite || quantity <= 0) {
      throw StateError('Informe uma quantidade maior que zero.');
    }
    if (!WarehouseRouting.operationalCodes.contains(
          WarehouseRouting.normalizeCode(requestedWarehouse),
        ) ||
        !WarehouseRouting.operationalCodes.contains(
          WarehouseRouting.normalizeCode(orderWarehouse),
        )) {
      throw StateError('Escolha um armazém da operação.');
    }
    final now = DateTime.now();
    final request = WarehouseConfirmationRequest(
      id:
          requestId ??
          'REQ-${now.microsecondsSinceEpoch}-${componentCode.trim().replaceAll(' ', '_')}',
      orderNumber: orderNumber,
      productCode: productCode,
      productName: productName,
      componentCode: componentCode,
      componentDescription: componentDescription,
      quantity: quantity,
      unit: unit.trim(),
      filial: filial.trim().isEmpty ? '04' : filial.trim(),
      orderWarehouse: WarehouseRouting.normalizeCode(orderWarehouse),
      requestedWarehouse: WarehouseRouting.normalizeCode(requestedWarehouse),
      requestedBy: requestedBy.trim(),
      createdAt: now,
      updatedAt: now,
      manual: true,
    );
    _upsertLocal(request);
    notifyListeners();
    _save(request);
    return request;
  }

  void confirm(String id, Operator operator) {
    _respond(
      id,
      WarehouseRequestStatus.confirmed,
      operator: operator,
      note: null,
    );
  }

  void reject(String id, Operator operator, String note) {
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      throw StateError('Explique por que o saldo não existe no armazém.');
    }
    _respond(
      id,
      WarehouseRequestStatus.rejected,
      operator: operator,
      note: trimmed,
    );
  }

  void _respond(
    String id,
    WarehouseRequestStatus status, {
    required Operator operator,
    required String? note,
  }) {
    final index = _requests.indexWhere((request) => request.id == id);
    if (index == -1) throw StateError('Pedido não encontrado.');
    final request = _requests[index];
    _requireAccess(request, operator);
    if (request.remainingQuantity <= 0) {
      throw StateError('Este pedido não tem quantidade pendente.');
    }
    if (request.status == WarehouseRequestStatus.confirmed) {
      throw StateError('Este pedido já foi confirmado.');
    }
    final now = DateTime.now();
    final updated = _requests[index].copyWith(
      status: status,
      responseBy: () => operator.name,
      responsePin: () => null,
      responseNote: () => note,
      updatedAt: now,
      events: [
        ...request.events,
        WarehouseMaterialEvent(
          action: status == WarehouseRequestStatus.confirmed
              ? WarehouseMaterialAction.confirmed
              : WarehouseMaterialAction.rejected,
          at: now,
          operatorName: operator.name,
          note: note ?? '',
        ),
      ],
    );
    _requests[index] = updated;
    notifyListeners();
    _save(updated);
  }

  void separate(
    String id,
    Operator operator,
    num quantity, {
    String note = '',
  }) => _recordQuantity(
    id,
    operator,
    quantity,
    WarehouseMaterialAction.separated,
    note: note,
  );

  void deliver(
    String id,
    Operator operator,
    num quantity, {
    String note = '',
  }) => _recordQuantity(
    id,
    operator,
    quantity,
    WarehouseMaterialAction.delivered,
    note: note,
  );

  void _requireAccess(WarehouseConfirmationRequest request, Operator operator) {
    if (!canHandle(request, operator)) {
      throw StateError(
        'Somente o setor de origem ou a administração pode atender o pedido.',
      );
    }
  }

  void _recordQuantity(
    String id,
    Operator operator,
    num quantity,
    WarehouseMaterialAction action, {
    String note = '',
    String? eventId,
  }) {
    final index = _requests.indexWhere((request) => request.id == id);
    if (index < 0) throw StateError('Pedido não encontrado.');
    final request = _requests[index];
    if (!canRecordMaterial(request, operator, action)) {
      throw StateError('Ação reservada ao setor responsável.');
    }
    if (eventId != null) {
      final old = request.events.where((e) => e.id == eventId).firstOrNull;
      if (old != null) {
        if (old.action == action &&
            old.quantity == quantity &&
            old.note == note.trim() &&
            old.operatorName == operator.name) {
          return;
        }
        throw StateError('Este registro já existe com outros dados.');
      }
    }
    if ([
          WarehouseMaterialAction.returnSent,
          WarehouseMaterialAction.cancelled,
          WarehouseMaterialAction.unseparated,
        ].contains(action) &&
        note.trim().isEmpty) {
      throw StateError('Informe o motivo.');
    }
    if (action != WarehouseMaterialAction.cancelled &&
        request.status != WarehouseRequestStatus.confirmed) {
      throw StateError('Confirme a disponibilidade antes de separar.');
    }
    final limit = request.limitFor(action);
    if (!quantity.isFinite ||
        quantity <= 0 ||
        quantity > limit + limit.abs() * 1e-10 ||
        limit <= 0) {
      throw StateError(
        'Informe uma quantidade válida dentro do saldo do pedido.',
      );
    }
    final now = DateTime.now();
    final updated = request.copyWith(
      updatedAt: now,
      events: [
        ...request.events,
        WarehouseMaterialEvent(
          action: action,
          id: eventId ?? '',
          at: now,
          operatorName: operator.name,
          quantity: quantity.clamp(0, limit),
          note: note.trim(),
        ),
      ],
    );
    _requests[index] = updated;
    notifyListeners();
    _save(updated);
  }

  void _upsertLocal(WarehouseConfirmationRequest request) {
    final index = _requests.indexWhere((item) => item.id == request.id);
    if (index == -1) {
      _requests.insert(0, request);
    } else {
      _requests[index] = request;
    }
  }

  Future<void> _loadFromDatabase() async {
    try {
      final loaded = await database.loadRequests();
      if (loaded.isEmpty) return;
      for (final request in loaded) {
        final index = _requests.indexWhere((item) => item.id == request.id);
        if (index < 0 ||
            request.updatedAt.isAfter(_requests[index].updatedAt)) {
          _upsertLocal(request);
        }
      }
      _notify();
    } catch (error, stackTrace) {
      _loadFailed = true;
      persistenceError =
          'Não foi possível carregar os pedidos salvos neste dispositivo.';
      _notify();
      debugPrint('Erro ao carregar requisicoes de armazem: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _save(WarehouseConfirmationRequest request) async {
    _unsaved[request.id] = request;
    try {
      await database.saveRequest(request);
      if (identical(_unsaved[request.id], request)) _unsaved.remove(request.id);
      if (_unsaved.isEmpty && !_loadFailed && persistenceError != null) {
        persistenceError = null;
        _notify();
      }
    } catch (error, stackTrace) {
      persistenceError =
          'Há alterações sem salvar. Mantenha o app aberto e confira o armazenamento deste dispositivo.';
      _notify();
      debugPrint('Erro ao salvar requisicao ${request.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> retrySaving() async {
    if (_loadFailed) {
      _loadFailed = false;
      persistenceError = null;
      await _loadFromDatabase();
    }
    for (final request in _unsaved.values.toList()) {
      await _save(request);
    }
    _notify();
  }

  String _idFor(String orderNumber, String componentCode, String warehouse) {
    return '$orderNumber-${componentCode.trim()}-${warehouse.trim()}';
  }
}
