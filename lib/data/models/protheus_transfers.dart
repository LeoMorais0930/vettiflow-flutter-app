class ProtheusTransferSnapshot {
  const ProtheusTransferSnapshot({
    required this.filial,
    this.transferencias = const [],
    this.divergencias = const [],
  });

  final String filial;
  final List<ProtheusTransfer> transferencias;
  final List<String> divergencias;

  factory ProtheusTransferSnapshot.fromJson(Map<String, dynamic> json) {
    return ProtheusTransferSnapshot(
      filial: _text(json['filial'], fallback: '04'),
      transferencias: _list(
        json['transferencias'],
      ).map(ProtheusTransfer.fromJson).toList(growable: false),
      divergencias: (json['divergencias'] as List<dynamic>? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class ProtheusTransfer {
  const ProtheusTransfer({
    required this.documento,
    required this.produto,
    required this.produtoDescricao,
    required this.quantidade,
    required this.localOrigem,
    required this.localDestino,
    required this.data,
    required this.status,
    this.movimentos = const [],
  });

  final String documento;
  final String produto;
  final String produtoDescricao;
  final num quantidade;
  final String localOrigem;
  final String localDestino;
  final String data;
  final String status;
  final List<ProtheusTransferMovement> movimentos;

  String get routeLabel {
    final origem = localOrigem.isEmpty ? '?' : localOrigem;
    final destino = localDestino.isEmpty ? '?' : localDestino;
    return '$origem -> $destino';
  }

  String get statusLabel => switch (status) {
    'pareada' => 'Pareada',
    'sem_entrada' => 'Sem entrada DE4',
    'sem_saida' => 'Sem saida RE4',
    _ => 'Incompleta',
  };

  factory ProtheusTransfer.fromJson(Map<String, dynamic> json) {
    return ProtheusTransfer(
      documento: _text(json['documento']),
      produto: _text(json['produto']),
      produtoDescricao: _text(json['produtoDescricao']),
      quantidade: _num(json['quantidade']),
      localOrigem: _text(json['localOrigem']),
      localDestino: _text(json['localDestino']),
      data: _text(json['data']),
      status: _text(json['status'], fallback: 'incompleta'),
      movimentos: _list(
        json['movimentos'],
      ).map(ProtheusTransferMovement.fromJson).toList(growable: false),
    );
  }
}

class ProtheusTransferMovement {
  const ProtheusTransferMovement({
    required this.cf,
    required this.tm,
    required this.local,
    required this.quantidade,
    required this.documento,
    required this.data,
    required this.estorno,
  });

  final String cf;
  final String tm;
  final String local;
  final num quantidade;
  final String documento;
  final String data;
  final bool estorno;

  String get label => '$cf/$tm';

  String get kindLabel => switch (cf) {
    'RE4' => 'Saida transferencia',
    'DE4' => 'Entrada transferencia',
    _ => 'Movimento transferencia',
  };

  factory ProtheusTransferMovement.fromJson(Map<String, dynamic> json) {
    return ProtheusTransferMovement(
      cf: _text(json['cf']),
      tm: _text(json['tm']),
      local: _text(json['local']),
      quantidade: _num(json['quantidade']),
      documento: _text(json['documento']),
      data: _text(json['data']),
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
