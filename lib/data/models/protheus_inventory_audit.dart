class ProtheusInventoryAuditSnapshot {
  const ProtheusInventoryAuditSnapshot({
    required this.filial,
    this.movimentos = const [],
    this.resumoPorTipo = const [],
    this.pendenciasPesquisa = const [],
  });

  final String filial;
  final List<ProtheusInventoryAuditMovement> movimentos;
  final List<ProtheusInventoryAuditSummary> resumoPorTipo;
  final List<String> pendenciasPesquisa;

  factory ProtheusInventoryAuditSnapshot.fromJson(Map<String, dynamic> json) {
    return ProtheusInventoryAuditSnapshot(
      filial: _text(json['filial'], fallback: '04'),
      movimentos: _list(
        json['movimentos'],
      ).map(ProtheusInventoryAuditMovement.fromJson).toList(growable: false),
      resumoPorTipo: _list(
        json['resumoPorTipo'],
      ).map(ProtheusInventoryAuditSummary.fromJson).toList(growable: false),
      pendenciasPesquisa:
          (json['pendenciasPesquisa'] as List<dynamic>? ?? const [])
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
    );
  }
}

class ProtheusInventoryAuditMovement {
  const ProtheusInventoryAuditMovement({
    required this.cf,
    required this.tm,
    required this.tipo,
    required this.tipoLabel,
    required this.documento,
    required this.op,
    required this.produto,
    required this.produtoDescricao,
    required this.quantidade,
    required this.local,
    required this.data,
    required this.numSeq,
    required this.usuario,
    required this.motivo,
    required this.observacao,
    required this.estorno,
  });

  final String cf;
  final String tm;
  final String tipo;
  final String tipoLabel;
  final String documento;
  final String op;
  final String produto;
  final String produtoDescricao;
  final num quantidade;
  final String local;
  final String data;
  final String numSeq;
  final String usuario;
  final String motivo;
  final String observacao;
  final bool estorno;

  String get label => '$cf/$tm';

  String get produtoLabel {
    if (produtoDescricao.isEmpty) return produto;
    return '$produto - $produtoDescricao';
  }

  factory ProtheusInventoryAuditMovement.fromJson(Map<String, dynamic> json) {
    return ProtheusInventoryAuditMovement(
      cf: _text(json['cf']),
      tm: _text(json['tm']),
      tipo: _text(json['tipo'], fallback: 'outro'),
      tipoLabel: _text(json['tipoLabel'], fallback: 'Movimento especial'),
      documento: _text(json['documento']),
      op: _text(json['op']),
      produto: _text(json['produto']),
      produtoDescricao: _text(json['produtoDescricao']),
      quantidade: _num(json['quantidade']),
      local: _text(json['local']),
      data: _text(json['data']),
      numSeq: _text(json['numSeq']),
      usuario: _text(json['usuario']),
      motivo: _text(json['motivo']),
      observacao: _text(json['observacao']),
      estorno: json['estorno'] == true,
    );
  }
}

class ProtheusInventoryAuditSummary {
  const ProtheusInventoryAuditSummary({
    required this.tipo,
    required this.tipoLabel,
    required this.quantidadeMovimentos,
  });

  final String tipo;
  final String tipoLabel;
  final int quantidadeMovimentos;

  factory ProtheusInventoryAuditSummary.fromJson(Map<String, dynamic> json) {
    return ProtheusInventoryAuditSummary(
      tipo: _text(json['tipo'], fallback: 'outro'),
      tipoLabel: _text(json['tipoLabel'], fallback: 'Movimento especial'),
      quantidadeMovimentos: _int(json['quantidadeMovimentos']),
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

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

num _num(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
