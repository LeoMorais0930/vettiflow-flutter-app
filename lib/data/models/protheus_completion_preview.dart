class ProtheusCompletionPreviewSnapshot {
  const ProtheusCompletionPreviewSnapshot({
    required this.op,
    required this.filial,
    required this.readOnly,
    required this.rotinaStatus,
    this.rotinasCandidatas = const [],
    required this.quantidadeSolicitada,
    required this.quantidadeRestante,
    this.ordem,
    this.movimentosPrevistos = const [],
    this.saldosComponentes = const [],
    this.divergencias = const [],
    this.pendenciasPesquisa = const [],
  });

  final String op;
  final String filial;
  final bool readOnly;
  final String rotinaStatus;
  final List<String> rotinasCandidatas;
  final num quantidadeSolicitada;
  final num quantidadeRestante;
  final ProtheusCompletionOrder? ordem;
  final List<ProtheusCompletionMovementPreview> movimentosPrevistos;
  final List<ProtheusCompletionComponentBalance> saldosComponentes;
  final List<String> divergencias;
  final List<String> pendenciasPesquisa;

  factory ProtheusCompletionPreviewSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    final ordemJson = _mapOrNull(json['ordem']);
    return ProtheusCompletionPreviewSnapshot(
      op: _text(json['op']),
      filial: _text(json['filial'], fallback: '04'),
      readOnly: json['readOnly'] == true,
      rotinaStatus: _text(json['rotinaStatus'], fallback: 'pendente_pesquisa'),
      rotinasCandidatas:
          (json['rotinasCandidatas'] as List<dynamic>? ?? const [])
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
      quantidadeSolicitada: _num(json['quantidadeSolicitada']),
      quantidadeRestante: _num(json['quantidadeRestante']),
      ordem: ordemJson == null
          ? null
          : ProtheusCompletionOrder.fromJson(ordemJson),
      movimentosPrevistos: _list(
        json['movimentosPrevistos'],
      ).map(ProtheusCompletionMovementPreview.fromJson).toList(growable: false),
      saldosComponentes: _list(json['saldosComponentes'])
          .map(ProtheusCompletionComponentBalance.fromJson)
          .toList(growable: false),
      divergencias: _stringList(json['divergencias']),
      pendenciasPesquisa: _stringList(json['pendenciasPesquisa']),
    );
  }
}

class ProtheusCompletionOrder {
  const ProtheusCompletionOrder({
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

  factory ProtheusCompletionOrder.fromJson(Map<String, dynamic> json) {
    return ProtheusCompletionOrder(
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

class ProtheusCompletionMovementPreview {
  const ProtheusCompletionMovementPreview({
    required this.cf,
    required this.tm,
    required this.produto,
    required this.produtoDescricao,
    required this.local,
    required this.quantidade,
    required this.documentoReferencia,
  });

  final String cf;
  final String tm;
  final String produto;
  final String produtoDescricao;
  final String local;
  final num quantidade;
  final String documentoReferencia;

  String get label => '$cf/$tm';

  String get kindLabel => switch (cf) {
    'PR0' => 'Entrada prevista do acabado',
    'RE1' => 'Baixa prevista do componente',
    _ => 'Movimento previsto',
  };

  factory ProtheusCompletionMovementPreview.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProtheusCompletionMovementPreview(
      cf: _text(json['cf']),
      tm: _text(json['tm']),
      produto: _text(json['produto']),
      produtoDescricao: _text(json['produtoDescricao']),
      local: _text(json['local']),
      quantidade: _num(json['quantidade']),
      documentoReferencia: _text(json['documentoReferencia']),
    );
  }
}

class ProtheusCompletionComponentBalance {
  const ProtheusCompletionComponentBalance({
    required this.produto,
    required this.produtoDescricao,
    required this.local,
    required this.saldoAtual,
    required this.quantidadePrevista,
    required this.suficiente,
  });

  final String produto;
  final String produtoDescricao;
  final String local;
  final num saldoAtual;
  final num quantidadePrevista;
  final bool suficiente;

  factory ProtheusCompletionComponentBalance.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProtheusCompletionComponentBalance(
      produto: _text(json['produto']),
      produtoDescricao: _text(json['produtoDescricao']),
      local: _text(json['local']),
      saldoAtual: _num(json['saldoAtual']),
      quantidadePrevista: _num(json['quantidadePrevista']),
      suficiente: json['suficiente'] == true,
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

List<String> _stringList(Object? value) {
  return (value as List<dynamic>? ?? const [])
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
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
