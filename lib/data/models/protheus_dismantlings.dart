class ProtheusDismantlingSnapshot {
  const ProtheusDismantlingSnapshot({
    required this.filial,
    this.desmontagens = const [],
    this.divergencias = const [],
  });

  final String filial;
  final List<ProtheusDismantling> desmontagens;
  final List<String> divergencias;

  factory ProtheusDismantlingSnapshot.fromJson(Map<String, dynamic> json) {
    return ProtheusDismantlingSnapshot(
      filial: _text(json['filial'], fallback: '04'),
      desmontagens: _list(
        json['desmontagens'],
      ).map(ProtheusDismantling.fromJson).toList(growable: false),
      divergencias: (json['divergencias'] as List<dynamic>? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class ProtheusDismantling {
  const ProtheusDismantling({
    required this.documento,
    required this.produtoOrigem,
    required this.produtoOrigemDescricao,
    required this.quantidadeOrigem,
    required this.localOrigem,
    required this.data,
    required this.status,
    this.componentesRetornados = const [],
    this.movimentos = const [],
  });

  final String documento;
  final String produtoOrigem;
  final String produtoOrigemDescricao;
  final num quantidadeOrigem;
  final String localOrigem;
  final String data;
  final String status;
  final List<ProtheusReturnedComponent> componentesRetornados;
  final List<ProtheusDismantlingMovement> movimentos;

  String get produtoOrigemLabel {
    if (produtoOrigemDescricao.isEmpty) return produtoOrigem;
    return '$produtoOrigem - $produtoOrigemDescricao';
  }

  String get statusLabel => switch (status) {
    'pareada' => 'Pareada',
    'sem_retorno' => 'Sem retorno DE7',
    'sem_origem' => 'Sem origem RE7',
    _ => 'Incompleta',
  };

  factory ProtheusDismantling.fromJson(Map<String, dynamic> json) {
    return ProtheusDismantling(
      documento: _text(json['documento']),
      produtoOrigem: _text(json['produtoOrigem']),
      produtoOrigemDescricao: _text(json['produtoOrigemDescricao']),
      quantidadeOrigem: _num(json['quantidadeOrigem']),
      localOrigem: _text(json['localOrigem']),
      data: _text(json['data']),
      status: _text(json['status'], fallback: 'incompleta'),
      componentesRetornados: _list(
        json['componentesRetornados'],
      ).map(ProtheusReturnedComponent.fromJson).toList(growable: false),
      movimentos: _list(
        json['movimentos'],
      ).map(ProtheusDismantlingMovement.fromJson).toList(growable: false),
    );
  }
}

class ProtheusReturnedComponent {
  const ProtheusReturnedComponent({
    required this.produto,
    required this.produtoDescricao,
    required this.quantidade,
    required this.local,
    required this.documento,
    required this.data,
    required this.numSeq,
  });

  final String produto;
  final String produtoDescricao;
  final num quantidade;
  final String local;
  final String documento;
  final String data;
  final String numSeq;

  String get produtoLabel {
    if (produtoDescricao.isEmpty) return produto;
    return '$produto - $produtoDescricao';
  }

  factory ProtheusReturnedComponent.fromJson(Map<String, dynamic> json) {
    return ProtheusReturnedComponent(
      produto: _text(json['produto']),
      produtoDescricao: _text(json['produtoDescricao']),
      quantidade: _num(json['quantidade']),
      local: _text(json['local']),
      documento: _text(json['documento']),
      data: _text(json['data']),
      numSeq: _text(json['numSeq']),
    );
  }
}

class ProtheusDismantlingMovement {
  const ProtheusDismantlingMovement({
    required this.cf,
    required this.tm,
    required this.produto,
    required this.local,
    required this.quantidade,
    required this.documento,
    required this.data,
    required this.numSeq,
    required this.estorno,
  });

  final String cf;
  final String tm;
  final String produto;
  final String local;
  final num quantidade;
  final String documento;
  final String data;
  final String numSeq;
  final bool estorno;

  String get label => '$cf/$tm';

  String get kindLabel => switch (cf) {
    'RE7' => 'Origem desmontada',
    'DE7' => 'Componente retornado',
    _ => 'Movimento desmontagem',
  };

  factory ProtheusDismantlingMovement.fromJson(Map<String, dynamic> json) {
    return ProtheusDismantlingMovement(
      cf: _text(json['cf']),
      tm: _text(json['tm']),
      produto: _text(json['produto']),
      local: _text(json['local']),
      quantidade: _num(json['quantidade']),
      documento: _text(json['documento']),
      data: _text(json['data']),
      numSeq: _text(json['numSeq']),
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

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

num _num(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}
