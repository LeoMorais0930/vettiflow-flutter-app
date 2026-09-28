import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';

enum WarehouseRequestStatus { pending, confirmed, rejected }

enum WarehouseMaterialAction {
  confirmed,
  rejected,
  separated,
  delivered,
  received,
  used,
  returnSent,
  returnReceived,
  unseparated,
  cancelled,
}

class WarehouseMaterialEvent {
  const WarehouseMaterialEvent({
    required this.action,
    required this.at,
    required this.operatorName,
    this.quantity = 0,
    this.note = '',
    this.id = '',
  });
  final WarehouseMaterialAction action;
  final DateTime at;
  final String operatorName;
  final num quantity;
  final String note;
  final String id;

  String get label => switch (action) {
    WarehouseMaterialAction.confirmed => 'Disponibilidade confirmada',
    WarehouseMaterialAction.rejected => 'Indisponibilidade informada',
    WarehouseMaterialAction.separated => 'Material separado',
    WarehouseMaterialAction.delivered => 'Entrega registrada',
    WarehouseMaterialAction.received => 'Recebimento confirmado',
    WarehouseMaterialAction.used => 'Uso registrado',
    WarehouseMaterialAction.returnSent => 'Devolução enviada',
    WarehouseMaterialAction.returnReceived => 'Devolução recebida na origem',
    WarehouseMaterialAction.unseparated => 'Separação desfeita',
    WarehouseMaterialAction.cancelled => 'Restante do pedido cancelado',
  };
  Map<String, dynamic> toJson() => {
    'action': action.name,
    'at': at.toIso8601String(),
    'operatorName': operatorName,
    'quantity': quantity,
    'note': note,
    'id': id,
  };
  factory WarehouseMaterialEvent.fromJson(Map<String, dynamic> json) =>
      WarehouseMaterialEvent(
        action: WarehouseMaterialAction.values.byName(json['action'] as String),
        at: DateTime.parse(json['at'] as String),
        operatorName: json['operatorName'] as String,
        quantity: json['quantity'] as num? ?? 0,
        note: json['note'] as String? ?? '',
        id: json['id'] as String? ?? '',
      );
}

class WarehouseConfirmationRequest {
  const WarehouseConfirmationRequest({
    required this.id,
    required this.orderNumber,
    required this.productCode,
    required this.productName,
    required this.componentCode,
    required this.componentDescription,
    required this.quantity,
    required this.filial,
    required this.orderWarehouse,
    required this.requestedWarehouse,
    required this.requestedBy,
    required this.createdAt,
    required this.updatedAt,
    this.status = WarehouseRequestStatus.pending,
    this.responseBy,
    this.responsePin,
    this.responseNote,
    this.manual = false,
    this.unit = '',
    this.events = const [],
  });

  final String id;
  final String orderNumber;
  final String productCode;
  final String productName;
  final String componentCode;
  final String componentDescription;
  final num quantity;
  final String unit;
  final List<WarehouseMaterialEvent> events;
  final String filial;
  final String orderWarehouse;
  final String requestedWarehouse;
  final String requestedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final WarehouseRequestStatus status;
  final String? responseBy;
  final String? responsePin;
  final String? responseNote;
  final bool manual;

  String get warehouseLabel =>
      WarehouseRouting.labelForWarehouse(requestedWarehouse);

  String get orderWarehouseLabel =>
      WarehouseRouting.labelForWarehouse(orderWarehouse);

  WorkArea? get area => WarehouseRouting.byCode(requestedWarehouse)?.area;

  bool get isPending => status == WarehouseRequestStatus.pending;
  num total(WarehouseMaterialAction action) => events
      .where((e) => e.action == action)
      .fold<num>(0, (sum, e) => sum + e.quantity);
  num get cancelledQuantity => total(WarehouseMaterialAction.cancelled);
  num get receivedQuantity => total(WarehouseMaterialAction.received);
  num get usedQuantity => total(WarehouseMaterialAction.used);
  num get returnSentQuantity => total(WarehouseMaterialAction.returnSent);
  num get returnedQuantity => total(WarehouseMaterialAction.returnReceived);
  num get toReceive =>
      (deliveredQuantity - receivedQuantity).clamp(0, quantity);
  num get availableAtDestination =>
      (receivedQuantity - usedQuantity - returnSentQuantity).clamp(0, quantity);
  num get returnTransit =>
      (returnSentQuantity - returnedQuantity).clamp(0, quantity);
  num limitFor(WarehouseMaterialAction action) => switch (action) {
    WarehouseMaterialAction.separated ||
    WarehouseMaterialAction.cancelled => toSeparate,
    WarehouseMaterialAction.delivered ||
    WarehouseMaterialAction.unseparated => readyToDeliver,
    WarehouseMaterialAction.received => toReceive,
    WarehouseMaterialAction.used ||
    WarehouseMaterialAction.returnSent => availableAtDestination,
    WarehouseMaterialAction.returnReceived => returnTransit,
    _ => 0,
  };

  num get separatedQuantity =>
      events
          .where((e) => e.action == WarehouseMaterialAction.separated)
          .fold<num>(0, (a, e) => a + e.quantity) -
      total(WarehouseMaterialAction.unseparated);
  num get deliveredQuantity => events
      .where((e) => e.action == WarehouseMaterialAction.delivered)
      .fold<num>(0, (a, e) => a + e.quantity);
  num get remainingQuantity =>
      (quantity - cancelledQuantity - deliveredQuantity).clamp(0, quantity);
  num get toSeparate =>
      (quantity - cancelledQuantity - separatedQuantity).clamp(0, quantity);
  num get readyToDeliver =>
      (separatedQuantity - deliveredQuantity).clamp(0, quantity);
  bool get isDelivered =>
      quantity > 0 &&
      deliveredQuantity > 0 &&
      remainingQuantity <= quantity.abs() * 1e-10;
  String get progressLabel => cancelledQuantity >= quantity
      ? 'Cancelado'
      : returnTransit > 0
      ? 'Devolução a receber'
      : deliveredQuantity > 0 && !isDelivered
      ? 'Entrega parcial'
      : toReceive > 0
      ? 'A receber no destino'
      : isDelivered
      ? 'Entregue'
      : deliveredQuantity > 0
      ? 'Entrega parcial'
      : separatedQuantity > 0
      ? 'Em separação'
      : status == WarehouseRequestStatus.confirmed
      ? 'A separar'
      : status == WarehouseRequestStatus.rejected
      ? 'Indisponível'
      : 'A confirmar';

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderNumber': orderNumber,
    'productCode': productCode,
    'productName': productName,
    'componentCode': componentCode,
    'componentDescription': componentDescription,
    'quantity': quantity,
    'unit': unit,
    'filial': filial,
    'orderWarehouse': orderWarehouse,
    'requestedWarehouse': requestedWarehouse,
    'requestedBy': requestedBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'status': status.name,
    'responseBy': responseBy,
    'responseNote': responseNote,
    'manual': manual,
    'events': events.map((e) => e.toJson()).toList(),
  };

  factory WarehouseConfirmationRequest.fromJson(Map<String, dynamic> json) =>
      WarehouseConfirmationRequest(
        id: json['id'] as String,
        orderNumber: json['orderNumber'] as String,
        productCode: json['productCode'] as String,
        productName: json['productName'] as String,
        componentCode: json['componentCode'] as String,
        componentDescription: json['componentDescription'] as String,
        quantity: json['quantity'] as num,
        unit: json['unit'] as String? ?? '',
        filial: json['filial'] as String,
        orderWarehouse: json['orderWarehouse'] as String,
        requestedWarehouse: json['requestedWarehouse'] as String,
        requestedBy: json['requestedBy'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        status: WarehouseRequestStatus.values.byName(json['status'] as String),
        responseBy: json['responseBy'] as String?,
        responseNote: json['responseNote'] as String?,
        manual: json['manual'] as bool? ?? false,
        events: (json['events'] as List? ?? [])
            .map(
              (e) => WarehouseMaterialEvent.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );

  WarehouseConfirmationRequest copyWith({
    WarehouseRequestStatus? status,
    String? Function()? responseBy,
    String? Function()? responsePin,
    String? Function()? responseNote,
    DateTime? updatedAt,
    List<WarehouseMaterialEvent>? events,
  }) {
    return WarehouseConfirmationRequest(
      id: id,
      orderNumber: orderNumber,
      productCode: productCode,
      productName: productName,
      componentCode: componentCode,
      componentDescription: componentDescription,
      quantity: quantity,
      unit: unit,
      events: events ?? this.events,
      filial: filial,
      orderWarehouse: orderWarehouse,
      requestedWarehouse: requestedWarehouse,
      requestedBy: requestedBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      responseBy: responseBy != null ? responseBy() : this.responseBy,
      responsePin: responsePin != null ? responsePin() : this.responsePin,
      responseNote: responseNote != null ? responseNote() : this.responseNote,
      manual: manual,
    );
  }
}
