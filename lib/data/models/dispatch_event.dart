enum DispatchAction {
  deliver('Registrar entrega', 'Entrega registrada', 'production'),
  receive('Confirmar recebimento', 'Recebimento confirmado', 'destination'),
  diagnose('Registrar diagnóstico', 'Diagnóstico registrado', 'support'),
  repair('Concluir reparo', 'Reparo concluído', 'support'),
  returnUnrepaired(
    'Devolver sem reparo',
    'Devolução sem reparo enviada',
    'support',
  ),
  returnRepaired(
    'Devolver reparados',
    'Devolução de reparados enviada',
    'support',
  ),
  sendToExpedition(
    'Enviar à expedição',
    'Reparados enviados à expedição',
    'support',
  ),
  receiveFromSupport(
    'Receber do suporte',
    'Recebimento do suporte confirmado',
    'expedition',
  ),
  store('Armazenar', 'Armazenamento registrado', 'expedition'),
  unstore(
    'Retirar do armazenamento',
    'Retirada do armazenamento',
    'expedition',
  ),
  ship('Registrar despacho', 'Despacho registrado', 'expedition'),
  customerReturn(
    'Registrar retorno de cliente',
    'Retorno do cliente informado',
    'expedition',
  ),
  receiveCustomerReturn(
    'Receber retorno de cliente',
    'Retorno do cliente recebido',
    'expedition',
  ),
  returnFromExpedition(
    'Devolver à produção',
    'Devolução da expedição enviada',
    'expedition',
  ),
  receiveReturn(
    'Receber devolução',
    'Devolução recebida na produção',
    'production',
  ),
  cancelRemaining(
    'Cancelar restante do preparo',
    'Restante do preparo cancelado',
    'production',
  );

  const DispatchAction(this.label, this.historyLabel, this.sector);
  final String label, historyLabel, sector;
  bool get requiresQuantity => this != diagnose;
}

class DispatchEvent {
  const DispatchEvent({
    required this.id,
    required this.action,
    required this.quantity,
    required this.at,
    required this.operatorName,
    required this.operatorUsername,
    required this.note,
    this.stage = '',
    this.reference = '',
  });
  final String id, operatorName, operatorUsername, note, stage, reference;
  final DispatchAction action;
  final num quantity;
  final DateTime at;
  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action.name,
    'quantity': quantity,
    'at': at.toIso8601String(),
    'operatorName': operatorName,
    'operatorUsername': operatorUsername,
    'note': note,
    'stage': stage,
    'reference': reference,
  };
  factory DispatchEvent.fromJson(Map<String, dynamic> json) => DispatchEvent(
    id: json['id'] as String,
    action: DispatchAction.values.byName(json['action'] as String),
    quantity: json['quantity'] as num,
    at: DateTime.parse(json['at'] as String),
    operatorName: json['operatorName'] as String,
    operatorUsername: json['operatorUsername'] as String,
    note: json['note'] as String? ?? '',
    stage: json['stage'] as String? ?? '',
    reference: json['reference'] as String? ?? '',
  );
}
