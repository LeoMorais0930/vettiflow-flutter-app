import 'dart:convert';
import 'ordem_producao.dart';
import 'production_flow.dart';

class FlowExecution {
  FlowExecution.fromJson(Map<String, dynamic> json)
    : key = Map<String, String>.from(json['key'] as Map),
      produto = json['produto'] as String,
      emissao = json['emissao'] as String,
      stage = ProductionStage.values.firstWhere((s) => s.name == json['stage']),
      status = json['status'] as String,
      actor = json['actor'] as String,
      note = json['note'] as String,
      updatedAt = DateTime.parse(json['updatedAt'] as String);

  final Map<String, String> key;
  final String produto, emissao, status, actor, note;
  final ProductionStage stage;
  final DateTime updatedAt;
  static String identity(Map<String, String> key) => jsonEncode([
    for (final field in ['filial', 'numero', 'item', 'sequencia', 'grade'])
      key[field] ?? '',
  ]);
  bool matches(OrdemProducao op) {
    final parts = op.dataAbertura.split('/');
    final date = parts.length == 3
        ? '${parts[2]}${parts[1]}${parts[0]}'
        : op.dataAbertura;
    return op.erpKey != null &&
        identity(key) == identity(op.erpKey!) &&
        produto.trim() == op.produto.trim() &&
        emissao.trim() == date;
  }

  String get statusLabel => switch (status) {
    'active' => 'Em execução',
    'paused' => 'Pausada',
    'completed' => 'Etapa concluída',
    _ => 'Estado não reconhecido',
  };
}
