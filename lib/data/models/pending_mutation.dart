import 'package:vetti_flow_1_0/data/models/production_flow.dart'
    show formatProductionQuantity;

enum MutationKind { aberturaOp, empenho, transferencia, baixaProducao }

enum MutationStatus { pendente, enviando, armazenado, enviado, erro }

extension MutationStatusLabel on MutationStatus {
  String get label => switch (this) {
    MutationStatus.pendente => 'Pendente',
    MutationStatus.enviando => 'Enviando',
    MutationStatus.armazenado => 'Armazenado',
    MutationStatus.enviado => 'Aplicado',
    MutationStatus.erro => 'Erro',
  };
}

enum EmpenhoOperacao { incluir, alterar, excluir }

extension EmpenhoOperacaoLabel on EmpenhoOperacao {
  String get label => switch (this) {
    EmpenhoOperacao.incluir => 'Incluir',
    EmpenhoOperacao.alterar => 'Alterar',
    EmpenhoOperacao.excluir => 'Excluir',
  };
}

sealed class PendingMutation {
  const PendingMutation({
    required this.id,
    required this.filial,
    required this.criadoEm,
    required this.autor,
    this.status = MutationStatus.pendente,
    this.erro,
    this.protheusRef,
  });

  final String id;
  final String filial;
  final DateTime criadoEm;
  final String autor;
  final MutationStatus status;
  final String? erro;
  final String? protheusRef;

  MutationKind get kind;
  String get titulo;
  String get detalhe;

  Map<String, dynamic> payload();

  PendingMutation copyWithStatus({
    required MutationStatus status,
    String? erro,
    String? protheusRef,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'filial': filial,
    'criadoEm': criadoEm.toIso8601String(),
    'autor': autor,
    'status': status.name,
    'erro': erro,
    'protheusRef': protheusRef,
    'payload': payload(),
  };

  static PendingMutation fromJson(Map<String, dynamic> json) {
    final kind = MutationKind.values.firstWhere(
      (value) => value.name == json['kind'],
      orElse: () => throw FormatException('Tipo desconhecido: ${json['kind']}'),
    );
    final payload = (json['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    return switch (kind) {
      MutationKind.aberturaOp => AberturaOpMutation._fromJson(json, payload),
      MutationKind.empenho => EmpenhoMutation._fromJson(json, payload),
      MutationKind.transferencia => TransferenciaMutation._fromJson(
        json,
        payload,
      ),
      MutationKind.baixaProducao => BaixaProducaoMutation._fromJson(
        json,
        payload,
      ),
    };
  }
}

class _Envelope {
  _Envelope(Map<String, dynamic> json)
    : id = json['id'] as String? ?? '',
      filial = json['filial'] as String? ?? '04',
      criadoEm =
          DateTime.tryParse(json['criadoEm'] as String? ?? '') ??
          DateTime.now(),
      autor = json['autor'] as String? ?? '',
      status = MutationStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => MutationStatus.pendente,
      ),
      erro = json['erro'] as String?,
      protheusRef = json['protheusRef'] as String?;

  final String id;
  final String filial;
  final DateTime criadoEm;
  final String autor;
  final MutationStatus status;
  final String? erro;
  final String? protheusRef;
}

final class AberturaOpMutation extends PendingMutation {
  const AberturaOpMutation({
    required super.id,
    required super.filial,
    required super.criadoEm,
    required super.autor,
    required this.produto,
    required this.produtoDescricao,
    required this.quantidade,
    required this.localProducao,
    this.previsao,
    this.observacao,
    this.empenhos = const [],
    super.status,
    super.erro,
    super.protheusRef,
  });

  final String produto;
  final String produtoDescricao;
  final int quantidade;
  final String localProducao;
  final String? previsao;
  final String? observacao;
  final List<EmpenhoLinha> empenhos;

  @override
  MutationKind get kind => MutationKind.aberturaOp;

  @override
  String get titulo => 'Abrir OP - $produto';

  @override
  String get detalhe {
    final partes = [
      '$quantidade un',
      'armazem $localProducao',
      if (previsao != null) 'prazo $previsao',
      if (empenhos.isNotEmpty) '${empenhos.length} empenhos ajustados',
    ];
    return partes.join(' - ');
  }

  @override
  Map<String, dynamic> payload() => {
    'produto': produto,
    'produtoDescricao': produtoDescricao,
    'quantidade': quantidade,
    'localProducao': localProducao,
    'previsao': previsao,
    'observacao': observacao,
    'empenhos': [for (final empenho in empenhos) empenho.toJson()],
  };

  @override
  AberturaOpMutation copyWithStatus({
    required MutationStatus status,
    String? erro,
    String? protheusRef,
  }) => AberturaOpMutation(
    id: id,
    filial: filial,
    criadoEm: criadoEm,
    autor: autor,
    produto: produto,
    produtoDescricao: produtoDescricao,
    quantidade: quantidade,
    localProducao: localProducao,
    previsao: previsao,
    observacao: observacao,
    empenhos: empenhos,
    status: status,
    erro: erro,
    protheusRef: protheusRef ?? this.protheusRef,
  );

  static AberturaOpMutation _fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> payload,
  ) {
    final env = _Envelope(json);
    return AberturaOpMutation(
      id: env.id,
      filial: env.filial,
      criadoEm: env.criadoEm,
      autor: env.autor,
      status: env.status,
      erro: env.erro,
      protheusRef: env.protheusRef,
      produto: payload['produto'] as String? ?? '',
      produtoDescricao: payload['produtoDescricao'] as String? ?? '',
      quantidade: (payload['quantidade'] as num?)?.toInt() ?? 0,
      localProducao: payload['localProducao'] as String? ?? '',
      previsao: payload['previsao'] as String?,
      observacao: payload['observacao'] as String?,
      empenhos: [
        for (final item in (payload['empenhos'] as List?) ?? const [])
          EmpenhoLinha.fromJson((item as Map).cast<String, dynamic>()),
      ],
    );
  }
}

class EmpenhoLinha {
  const EmpenhoLinha({
    required this.produto,
    required this.descricao,
    required this.quantidade,
    required this.local,
    this.quantidadeOriginal,
    this.structureSequence = '',
  });

  final String produto;
  final String descricao;
  final double quantidade;
  final String local;
  final double? quantidadeOriginal;
  final String structureSequence;

  Map<String, dynamic> toJson() => {
    'produto': produto,
    'descricao': descricao,
    'quantidade': quantidade,
    'local': local,
    'quantidadeOriginal': quantidadeOriginal,
    'structureSequence': structureSequence,
  };

  factory EmpenhoLinha.fromJson(Map<String, dynamic> json) => EmpenhoLinha(
    produto: json['produto'] as String? ?? '',
    descricao: json['descricao'] as String? ?? '',
    quantidade: (json['quantidade'] as num?)?.toDouble() ?? 0,
    local: json['local'] as String? ?? '',
    quantidadeOriginal: (json['quantidadeOriginal'] as num?)?.toDouble(),
    structureSequence: json['structureSequence'] as String? ?? '',
  );
}

final class EmpenhoMutation extends PendingMutation {
  const EmpenhoMutation({
    required super.id,
    required super.filial,
    required super.criadoEm,
    required super.autor,
    required this.op,
    required this.operacao,
    required this.produto,
    required this.produtoDescricao,
    required this.local,
    required this.quantidade,
    this.quantidadeAnterior,
    this.localAnterior,
    this.motivo,
    super.status,
    super.erro,
    super.protheusRef,
  });

  final String op;
  final EmpenhoOperacao operacao;
  final String produto;
  final String produtoDescricao;
  final String local;
  final double quantidade;
  final double? quantidadeAnterior;
  final String? localAnterior;
  final String? motivo;

  @override
  MutationKind get kind => MutationKind.empenho;

  @override
  String get titulo => '${operacao.label} empenho - OP $op';

  @override
  String get detalhe {
    final quantidadeTexto = formatProductionQuantity(quantidade);
    return switch (operacao) {
      EmpenhoOperacao.incluir =>
        '$produto - $quantidadeTexto un - armazem $local',
      EmpenhoOperacao.excluir => '$produto - armazem $local',
      EmpenhoOperacao.alterar => () {
        final anterior = quantidadeAnterior;
        final partes = <String>[produto];
        if (anterior != null && anterior != quantidade) {
          partes.add(
            '${formatProductionQuantity(anterior)} para $quantidadeTexto un',
          );
        } else {
          partes.add('$quantidadeTexto un');
        }
        if (localAnterior != null && localAnterior != local) {
          partes.add('armazem $localAnterior para $local');
        }
        return partes.join(' - ');
      }(),
    };
  }

  @override
  Map<String, dynamic> payload() => {
    'op': op,
    'operacao': operacao.name,
    'produto': produto,
    'produtoDescricao': produtoDescricao,
    'local': local,
    'quantidade': quantidade,
    'quantidadeAnterior': quantidadeAnterior,
    'localAnterior': localAnterior,
    'motivo': motivo,
  };

  @override
  EmpenhoMutation copyWithStatus({
    required MutationStatus status,
    String? erro,
    String? protheusRef,
  }) => EmpenhoMutation(
    id: id,
    filial: filial,
    criadoEm: criadoEm,
    autor: autor,
    op: op,
    operacao: operacao,
    produto: produto,
    produtoDescricao: produtoDescricao,
    local: local,
    quantidade: quantidade,
    quantidadeAnterior: quantidadeAnterior,
    localAnterior: localAnterior,
    motivo: motivo,
    status: status,
    erro: erro,
    protheusRef: protheusRef ?? this.protheusRef,
  );

  static EmpenhoMutation _fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> payload,
  ) {
    final env = _Envelope(json);
    return EmpenhoMutation(
      id: env.id,
      filial: env.filial,
      criadoEm: env.criadoEm,
      autor: env.autor,
      status: env.status,
      erro: env.erro,
      protheusRef: env.protheusRef,
      op: payload['op'] as String? ?? '',
      operacao: EmpenhoOperacao.values.firstWhere(
        (value) => value.name == payload['operacao'],
        orElse: () => EmpenhoOperacao.alterar,
      ),
      produto: payload['produto'] as String? ?? '',
      produtoDescricao: payload['produtoDescricao'] as String? ?? '',
      local: payload['local'] as String? ?? '',
      quantidade: (payload['quantidade'] as num?)?.toDouble() ?? 0,
      quantidadeAnterior: (payload['quantidadeAnterior'] as num?)?.toDouble(),
      localAnterior: payload['localAnterior'] as String?,
      motivo: payload['motivo'] as String?,
    );
  }
}

final class TransferenciaMutation extends PendingMutation {
  const TransferenciaMutation({
    required super.id,
    required super.filial,
    required super.criadoEm,
    required super.autor,
    required this.produto,
    required this.produtoDescricao,
    required this.quantidade,
    required this.localOrigem,
    required this.localDestino,
    this.op,
    this.motivo,
    super.status,
    super.erro,
    super.protheusRef,
  });

  final String produto;
  final String produtoDescricao;
  final double quantidade;
  final String localOrigem;
  final String localDestino;
  final String? op;
  final String? motivo;

  @override
  MutationKind get kind => MutationKind.transferencia;

  @override
  String get titulo => 'Transferir - $produto';

  @override
  String get detalhe {
    final partes = [
      '${formatProductionQuantity(quantidade)} un',
      '$localOrigem para $localDestino',
      if (op != null) 'OP $op',
    ];
    return partes.join(' - ');
  }

  @override
  Map<String, dynamic> payload() => {
    'produto': produto,
    'produtoDescricao': produtoDescricao,
    'quantidade': quantidade,
    'localOrigem': localOrigem,
    'localDestino': localDestino,
    'op': op,
    'motivo': motivo,
  };

  @override
  TransferenciaMutation copyWithStatus({
    required MutationStatus status,
    String? erro,
    String? protheusRef,
  }) => TransferenciaMutation(
    id: id,
    filial: filial,
    criadoEm: criadoEm,
    autor: autor,
    produto: produto,
    produtoDescricao: produtoDescricao,
    quantidade: quantidade,
    localOrigem: localOrigem,
    localDestino: localDestino,
    op: op,
    motivo: motivo,
    status: status,
    erro: erro,
    protheusRef: protheusRef ?? this.protheusRef,
  );

  static TransferenciaMutation _fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> payload,
  ) {
    final env = _Envelope(json);
    return TransferenciaMutation(
      id: env.id,
      filial: env.filial,
      criadoEm: env.criadoEm,
      autor: env.autor,
      status: env.status,
      erro: env.erro,
      protheusRef: env.protheusRef,
      produto: payload['produto'] as String? ?? '',
      produtoDescricao: payload['produtoDescricao'] as String? ?? '',
      quantidade: (payload['quantidade'] as num?)?.toDouble() ?? 0,
      localOrigem: payload['localOrigem'] as String? ?? '',
      localDestino: payload['localDestino'] as String? ?? '',
      op: payload['op'] as String?,
      motivo: payload['motivo'] as String?,
    );
  }
}

final class BaixaProducaoMutation extends PendingMutation {
  const BaixaProducaoMutation({
    required super.id,
    required super.filial,
    required super.criadoEm,
    required super.autor,
    required this.op,
    required this.produto,
    required this.produtoDescricao,
    required this.quantidadeProduzida,
    required this.localProducao,
    required this.componentes,
    super.status,
    super.erro,
    super.protheusRef,
  });

  final String op;
  final String produto;
  final String produtoDescricao;
  final int quantidadeProduzida;
  final String localProducao;
  final List<BaixaComponente> componentes;

  @override
  MutationKind get kind => MutationKind.baixaProducao;

  @override
  String get titulo => 'Producao - OP $op';

  @override
  String get detalhe =>
      '$produto - $quantidadeProduzida un - '
      '${componentes.length} componente${componentes.length == 1 ? '' : 's'}';

  @override
  Map<String, dynamic> payload() => {
    'op': op,
    'produto': produto,
    'produtoDescricao': produtoDescricao,
    'quantidadeProduzida': quantidadeProduzida,
    'localProducao': localProducao,
    'componentes': [for (final componente in componentes) componente.toJson()],
  };

  @override
  BaixaProducaoMutation copyWithStatus({
    required MutationStatus status,
    String? erro,
    String? protheusRef,
  }) => BaixaProducaoMutation(
    id: id,
    filial: filial,
    criadoEm: criadoEm,
    autor: autor,
    op: op,
    produto: produto,
    produtoDescricao: produtoDescricao,
    quantidadeProduzida: quantidadeProduzida,
    localProducao: localProducao,
    componentes: componentes,
    status: status,
    erro: erro,
    protheusRef: protheusRef ?? this.protheusRef,
  );

  static BaixaProducaoMutation _fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> payload,
  ) {
    final env = _Envelope(json);
    return BaixaProducaoMutation(
      id: env.id,
      filial: env.filial,
      criadoEm: env.criadoEm,
      autor: env.autor,
      status: env.status,
      erro: env.erro,
      protheusRef: env.protheusRef,
      op: payload['op'] as String? ?? '',
      produto: payload['produto'] as String? ?? '',
      produtoDescricao: payload['produtoDescricao'] as String? ?? '',
      quantidadeProduzida:
          (payload['quantidadeProduzida'] as num?)?.toInt() ?? 0,
      localProducao: payload['localProducao'] as String? ?? '',
      componentes: [
        for (final item in (payload['componentes'] as List?) ?? const [])
          BaixaComponente.fromJson((item as Map).cast<String, dynamic>()),
      ],
    );
  }
}

class BaixaComponente {
  const BaixaComponente({
    required this.produto,
    required this.local,
    required this.quantidade,
  });

  final String produto;
  final String local;
  final double quantidade;

  Map<String, dynamic> toJson() => {
    'produto': produto,
    'local': local,
    'quantidade': quantidade,
  };

  factory BaixaComponente.fromJson(Map<String, dynamic> json) =>
      BaixaComponente(
        produto: json['produto'] as String? ?? '',
        local: json['local'] as String? ?? '',
        quantidade: (json['quantidade'] as num?)?.toDouble() ?? 0,
      );
}
