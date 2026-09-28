class ProtheusWriteReadinessSnapshot {
  const ProtheusWriteReadinessSnapshot({
    required this.readOnly,
    required this.writeEnabled,
    required this.status,
    required this.database,
    this.writeAvailable = false,
    this.blockedOperations = const [],
    this.futureRequirements = const [],
    this.candidateRoutines = const [],
  });

  final bool readOnly;
  final bool writeEnabled;
  final bool writeAvailable;
  final String status;
  final String database;
  final List<String> blockedOperations;
  final List<String> futureRequirements;
  final List<String> candidateRoutines;

  String get statusLabel => switch (status) {
    'bloqueada_por_politica' => 'Escrita desabilitada',
    'conexao_pendente' => 'Escrita DEV · conexão pendente',
    'aguardando_autenticacao_protheus' =>
      'Escrita DEV · autenticação necessária',
    _ => writeEnabled ? 'Escrita habilitada' : 'Escrita desabilitada',
  };

  factory ProtheusWriteReadinessSnapshot.fromJson(Map<String, dynamic> json) {
    return ProtheusWriteReadinessSnapshot(
      readOnly: json['readOnly'] == true,
      writeEnabled: json['writeEnabled'] == true,
      writeAvailable: json['writeAvailable'] == true,
      status: _text(json['status'], fallback: 'bloqueada_por_politica'),
      database: _text(json['database']),
      blockedOperations: _stringList(json['blockedOperations']),
      futureRequirements: _stringList(json['futureRequirements']),
      candidateRoutines: _stringList(json['candidateRoutines']),
    );
  }
}

List<String> _stringList(Object? value) {
  return (value as List<dynamic>? ?? const [])
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}
