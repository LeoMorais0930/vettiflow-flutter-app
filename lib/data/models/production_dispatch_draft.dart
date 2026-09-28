import 'dispatch_event.dart';
export 'dispatch_event.dart';

/// Preparo e circulação por quantidade no VettiFlow, sem escrita no ERP.
class ProductionDispatchDraft {
  const ProductionDispatchDraft({
    required this.id,
    required this.quantity,
    required this.destination,
    required this.createdAt,
    required this.operatorName,
    required this.operatorUsername,
    required this.stage,
    required this.reason,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
    this.events = const [],
  });

  static const destinations = {
    '06': 'Suporte · 06',
    '07': 'Suporte · 07',
    '10': 'Expedição · 10',
  };
  final String id;
  final num quantity;
  final String destination;
  final DateTime createdAt;
  final String operatorName;
  final String operatorUsername;
  final String stage;
  final String reason;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancellationReason;
  final List<DispatchEvent> events;
  bool get isCancelled => cancelledAt != null;
  String get destinationLabel => destinations[destination] ?? destination;
  bool get isSupport => destination == '06' || destination == '07';
  num total(DispatchAction action) => events
      .where((e) => e.action == action)
      .fold<num>(0, (sum, e) => sum + e.quantity);
  num get cancelledQuantity =>
      isCancelled ? quantity : total(DispatchAction.cancelRemaining);
  num get delivered => total(DispatchAction.deliver);
  num get received => total(DispatchAction.receive);
  num get pendingDelivery =>
      (quantity - cancelledQuantity - delivered).clamp(0, quantity);
  num get initialTransit => (delivered - received).clamp(0, quantity);
  num get supportPending => isSupport
      ? (received -
                total(DispatchAction.repair) -
                total(DispatchAction.returnUnrepaired))
            .clamp(0, quantity)
      : 0;
  num get supportRepaired =>
      (total(DispatchAction.repair) -
              total(DispatchAction.returnRepaired) -
              total(DispatchAction.sendToExpedition))
          .clamp(0, quantity);
  num get expeditionTransit =>
      (total(DispatchAction.sendToExpedition) -
              total(DispatchAction.receiveFromSupport))
          .clamp(0, quantity);
  num get expeditionReady =>
      ((destination == '10' ? received : 0) +
              total(DispatchAction.receiveFromSupport) +
              total(DispatchAction.receiveCustomerReturn) +
              total(DispatchAction.unstore) -
              total(DispatchAction.store) -
              total(DispatchAction.ship) -
              total(DispatchAction.returnFromExpedition))
          .clamp(0, quantity);
  num get stored =>
      (total(DispatchAction.store) - total(DispatchAction.unstore)).clamp(
        0,
        quantity,
      );
  num get shipped =>
      (total(DispatchAction.ship) - total(DispatchAction.customerReturn)).clamp(
        0,
        quantity,
      );
  num get customerReturnTransit =>
      (total(DispatchAction.customerReturn) -
              total(DispatchAction.receiveCustomerReturn))
          .clamp(0, quantity);
  num get returnTransit =>
      (total(DispatchAction.returnUnrepaired) +
              total(DispatchAction.returnRepaired) +
              total(DispatchAction.returnFromExpedition) -
              returned)
          .clamp(0, quantity);
  num get returned => total(DispatchAction.receiveReturn);
  num get allocated =>
      (quantity - cancelledQuantity - returned).clamp(0, quantity);
  num get outsideProduction => (delivered - returned).clamp(0, quantity);
  DateTime get lastActivity =>
      events.isNotEmpty ? events.last.at : cancelledAt ?? createdAt;
  bool get isFinished =>
      pendingDelivery +
          initialTransit +
          supportPending +
          supportRepaired +
          expeditionTransit +
          expeditionReady +
          stored +
          returnTransit +
          customerReturnTransit <
      1e-8;
  String get progressLabel => isCancelled
      ? 'Cancelado'
      : events.isEmpty
      ? 'Preparado · entrega pendente'
      : isFinished
      ? 'Concluído'
      : 'Em circulação';

  num limitFor(DispatchAction action) => switch (action) {
    DispatchAction.deliver || DispatchAction.cancelRemaining => pendingDelivery,
    DispatchAction.receive => initialTransit,
    DispatchAction.diagnose => supportPending + supportRepaired,
    DispatchAction.repair || DispatchAction.returnUnrepaired => supportPending,
    DispatchAction.returnRepaired ||
    DispatchAction.sendToExpedition => supportRepaired,
    DispatchAction.receiveFromSupport => expeditionTransit,
    DispatchAction.store ||
    DispatchAction.ship ||
    DispatchAction.returnFromExpedition => expeditionReady,
    DispatchAction.unstore => stored,
    DispatchAction.customerReturn => shipped,
    DispatchAction.receiveCustomerReturn => customerReturnTransit,
    DispatchAction.receiveReturn => returnTransit,
  };

  ProductionDispatchDraft addEvent(DispatchEvent event) =>
      ProductionDispatchDraft(
        id: id,
        quantity: quantity,
        destination: destination,
        createdAt: createdAt,
        operatorName: operatorName,
        operatorUsername: operatorUsername,
        stage: stage,
        reason: reason,
        cancelledAt: cancelledAt,
        cancelledBy: cancelledBy,
        cancellationReason: cancellationReason,
        events: List.unmodifiable([...events, event]),
      );

  ProductionDispatchDraft cancel(DateTime at, String by, String reason) =>
      ProductionDispatchDraft(
        id: id,
        quantity: quantity,
        destination: destination,
        createdAt: createdAt,
        operatorName: operatorName,
        operatorUsername: operatorUsername,
        stage: stage,
        reason: this.reason,
        cancelledAt: at,
        cancelledBy: by,
        cancellationReason: reason,
        events: events,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'quantity': quantity,
    'destination': destination,
    'createdAt': createdAt.toIso8601String(),
    'operatorName': operatorName,
    'operatorUsername': operatorUsername,
    'stage': stage,
    'reason': reason,
    'cancelledAt': cancelledAt?.toIso8601String(),
    'cancelledBy': cancelledBy,
    'cancellationReason': cancellationReason,
    'events': events.map((e) => e.toJson()).toList(),
  };

  factory ProductionDispatchDraft.fromJson(Map<String, dynamic> json) =>
      ProductionDispatchDraft(
        id: json['id'] as String,
        quantity: json['quantity'] as num,
        destination: json['destination'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        operatorName: json['operatorName'] as String,
        operatorUsername: json['operatorUsername'] as String,
        stage: json['stage'] as String,
        reason: json['reason'] as String,
        cancelledAt: json['cancelledAt'] == null
            ? null
            : DateTime.parse(json['cancelledAt'] as String),
        cancelledBy: json['cancelledBy'] as String?,
        cancellationReason: json['cancellationReason'] as String?,
        events: List.unmodifiable(
          (json['events'] as List? ?? []).map(
            (e) => DispatchEvent.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        ),
      );
}
