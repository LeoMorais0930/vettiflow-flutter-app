class ProtheusOpSnapshot {
  const ProtheusOpSnapshot({
    required this.op,
    required this.filial,
    required this.statusOficial,
    this.ordem,
    this.empenhos = const [],
    this.movimentos = const [],
    this.divergencias = const [],
  });

  final String op;
  final String filial;
  final String statusOficial;
  final ProtheusOfficialOrder? ordem;
  final List<ProtheusOpCommitment> empenhos;
  final List<ProtheusOpMovement> movimentos;
  final List<String> divergencias;

  factory ProtheusOpSnapshot.fromJson(Map<String, dynamic> json) {
    final ordemJson = _mapOrNull(json['ordem']);
    return ProtheusOpSnapshot(
      op: _text(json['op']),
      filial: _text(json['filial'], fallback: '04'),
      statusOficial: _text(json['statusOficial'], fallback: 'nao_encontrada'),
      ordem: ordemJson == null
          ? null
          : ProtheusOfficialOrder.fromJson(ordemJson),
      empenhos: _list(
        json['empenhos'],
      ).map(ProtheusOpCommitment.fromJson).toList(growable: false),
      movimentos: _list(
        json['movimentos'],
      ).map(ProtheusOpMovement.fromJson).toList(growable: false),
      divergencias: (json['divergencias'] as List<dynamic>? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }

  String get statusLabel => switch (statusOficial) {
    'aberta_com_empenho' => 'Aberta com empenho',
    'aberta_sem_empenho' => 'Aberta sem empenho',
    'apontada_parcial' => 'Apontada parcial',
    'apontada' => 'Apontada',
    'encerrada' => 'Encerrada',
    'com_estorno' => 'Com estorno',
    _ => 'Não encontrada',
  };

  num get totalProduzido => movimentos
      .where((item) => item.cf == 'PR0')
      .fold<num>(0, (sum, item) => sum + item.quantidade);

  num get totalConsumido => movimentos
      .where((item) => item.cf == 'RE1')
      .fold<num>(0, (sum, item) => sum + item.quantidade);

  bool get hasReversal =>
      movimentos.any((item) => item.cf == 'ER0' || item.cf == 'DE1');
}

class ProtheusOfficialOrder {
  const ProtheusOfficialOrder({
    required this.numero,
    required this.produto,
    required this.produtoDescricao,
    required this.quantidadePlanejada,
    required this.quantidadeProduzida,
    required this.local,
    required this.encerrada,
  });

  final String numero;
  final String produto;
  final String produtoDescricao;
  final num quantidadePlanejada;
  final num quantidadeProduzida;
  final String local;
  final bool encerrada;

  factory ProtheusOfficialOrder.fromJson(Map<String, dynamic> json) {
    return ProtheusOfficialOrder(
      numero: _text(json['numero']),
      produto: _text(json['produto']),
      produtoDescricao: _text(json['produtoDescricao']),
      quantidadePlanejada: _num(json['quantidadePlanejada']),
      quantidadeProduzida: _num(json['quantidadeProduzida']),
      local: _text(json['local']),
      encerrada: json['encerrada'] == true,
    );
  }
}

class ProtheusOpCommitment {
  const ProtheusOpCommitment({
    required this.produto,
    required this.local,
    required this.quantidadeOriginal,
    required this.quantidadeRestante,
  });

  final String produto;
  final String local;
  final num quantidadeOriginal;
  final num quantidadeRestante;

  factory ProtheusOpCommitment.fromJson(Map<String, dynamic> json) {
    return ProtheusOpCommitment(
      produto: _text(json['produto']),
      local: _text(json['local']),
      quantidadeOriginal: _num(json['quantidadeOriginal']),
      quantidadeRestante: _num(json['quantidadeRestante']),
    );
  }
}

class ProtheusOpMovement {
  const ProtheusOpMovement({
    required this.cf,
    required this.tm,
    required this.produto,
    required this.produtoDescricao,
    required this.local,
    required this.quantidade,
    required this.documento,
    required this.numSeq,
    required this.data,
    required this.perda,
    required this.ganho,
    required this.estorno,
  });

  final String cf;
  final String tm;
  final String produto;
  final String produtoDescricao;
  final String local;
  final num quantidade;
  final String documento;
  final String numSeq;
  final String data;
  final num perda;
  final num ganho;
  final bool estorno;

  String get label => '$cf/$tm';

  String get kindLabel => switch (cf) {
    'PR0' => 'Entrada acabado',
    'RE1' => 'Consumo componente',
    'ER0' => 'Reversão acabado',
    'DE1' => 'Retorno componente',
    _ => 'Movimento',
  };

  factory ProtheusOpMovement.fromJson(Map<String, dynamic> json) {
    return ProtheusOpMovement(
      cf: _text(json['cf']),
      tm: _text(json['tm']),
      produto: _text(json['produto']),
      produtoDescricao: _text(json['produtoDescricao']),
      local: _text(json['local']),
      quantidade: _num(json['quantidade']),
      documento: _text(json['documento']),
      numSeq: _text(json['numSeq']),
      data: _text(json['data']),
      perda: _num(json['perda']),
      ganho: _num(json['ganho']),
      estorno: json['estorno'] == true,
    );
  }
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
  }
  return const [];
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

num _num(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}
