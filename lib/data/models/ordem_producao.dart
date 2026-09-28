import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

enum StatusOP {
  aAbrir,
  naoIniciada,
  emAndamento,
  finalizada;

  String get label => switch (this) {
    aAbrir => 'A abrir',
    naoIniciada => 'Aberta · não iniciada',
    emAndamento => 'Em andamento',
    finalizada => 'Finalizada',
  };

  String get shortLabel => switch (this) {
    aAbrir => 'A abrir',
    naoIniciada => 'Não iniciadas',
    emAndamento => 'Em andamento',
    finalizada => 'Finalizadas',
  };

  Color get dot => switch (this) {
    aAbrir => AppColors.dotAAbrir,
    naoIniciada => AppColors.dotNaoIniciada,
    emAndamento => AppColors.dotAndamento,
    finalizada => AppColors.dotFinalizada,
  };

  Color get textColor => switch (this) {
    aAbrir => AppColors.statusAAbrir,
    naoIniciada => AppColors.statusNaoIniciada,
    emAndamento => AppColors.statusAndamento,
    finalizada => AppColors.statusFinalizada,
  };

  Color get bgColor => switch (this) {
    aAbrir => AppColors.bgAAbrir,
    naoIniciada => AppColors.bgNaoIniciada,
    emAndamento => AppColors.bgAndamento,
    finalizada => AppColors.bgFinalizada,
  };

  Color get barColor => switch (this) {
    finalizada => AppColors.barGreen,
    emAndamento => AppColors.barYellow,
    _ => AppColors.barGray,
  };

  StatusOP? get next => switch (this) {
    aAbrir => naoIniciada,
    naoIniciada => emAndamento,
    emAndamento => finalizada,
    finalizada => null,
  };

  StatusOP? get previous => switch (this) {
    aAbrir => null,
    naoIniciada => aAbrir,
    emAndamento => naoIniciada,
    finalizada => emAndamento,
  };

  String get actionLabel => switch (this) {
    aAbrir => 'Abrir OP',
    naoIniciada => 'Iniciar produção',
    emAndamento => 'Finalizar OP',
    finalizada => '',
  };
}

class OrdemProducao {
  final String numero;
  final String produto;
  final int qtd;
  final String responsavel;
  final String dataAbertura;
  final String prazo;
  final StatusOP status;
  final int progresso;
  final String mes;
  final bool atrasada;
  final String prioridade;
  final String armazem;
  final String localConsumoComponentes;
  final String localEntradaAcabado;
  final List<String> roteamentoAvisos;

  /// Etapa real da OP no fluxo de produção (fonte: ProductionFlowStore).
  final ProductionStage stage;

  /// Materiais (BOM) do produto: (descrição, quantidade por unidade).
  final List<(String, num)> materiais;
  final List<MaterialOpDetalhe> materiaisDetalhados;
  final List<ResumoPausaOp> pausas;
  final String tempoTotal;
  final String tempoEtapaAtual;
  final String? observacao;
  final List<ProductionStage> plannedStages;
  final List<ResumoAssinaturaOp> assinaturas;

  const OrdemProducao({
    required this.numero,
    required this.produto,
    required this.qtd,
    required this.responsavel,
    required this.dataAbertura,
    required this.prazo,
    required this.status,
    required this.progresso,
    required this.mes,
    this.atrasada = false,
    this.prioridade = 'Media',
    this.armazem = '',
    this.localConsumoComponentes = '',
    this.localEntradaAcabado = '',
    this.roteamentoAvisos = const [],
    this.stage = ProductionStage.warehouse,
    this.materiais = const [],
    this.materiaisDetalhados = const [],
    this.pausas = const [],
    this.tempoTotal = '0min',
    this.tempoEtapaAtual = '0min',
    this.observacao,
    this.plannedStages = const [],
    this.assinaturas = const [],
  });

  String get qtdLabel => '$qtd un';

  String get prazoLabel => 'Prazo $prazo';

  String get percentLabel => '$progresso%';

  bool get prioridadeAlta => prioridade == 'Alta';

  bool get showBar =>
      status == StatusOP.emAndamento || status == StatusOP.finalizada;

  OrdemProducao copyWith({
    String? numero,
    String? produto,
    int? qtd,
    String? responsavel,
    String? dataAbertura,
    String? prazo,
    StatusOP? status,
    int? progresso,
    String? mes,
    bool? atrasada,
    String? prioridade,
    String? armazem,
    String? localConsumoComponentes,
    String? localEntradaAcabado,
    List<String>? roteamentoAvisos,
    ProductionStage? stage,
    List<(String, num)>? materiais,
    List<MaterialOpDetalhe>? materiaisDetalhados,
    List<ResumoPausaOp>? pausas,
    String? tempoTotal,
    String? tempoEtapaAtual,
    String? Function()? observacao,
    List<ProductionStage>? plannedStages,
    List<ResumoAssinaturaOp>? assinaturas,
  }) {
    return OrdemProducao(
      numero: numero ?? this.numero,
      produto: produto ?? this.produto,
      qtd: qtd ?? this.qtd,
      responsavel: responsavel ?? this.responsavel,
      dataAbertura: dataAbertura ?? this.dataAbertura,
      prazo: prazo ?? this.prazo,
      status: status ?? this.status,
      progresso: progresso ?? this.progresso,
      mes: mes ?? this.mes,
      atrasada: atrasada ?? this.atrasada,
      prioridade: prioridade ?? this.prioridade,
      armazem: armazem ?? this.armazem,
      localConsumoComponentes:
          localConsumoComponentes ?? this.localConsumoComponentes,
      localEntradaAcabado: localEntradaAcabado ?? this.localEntradaAcabado,
      roteamentoAvisos: roteamentoAvisos ?? this.roteamentoAvisos,
      stage: stage ?? this.stage,
      materiais: materiais ?? this.materiais,
      materiaisDetalhados: materiaisDetalhados ?? this.materiaisDetalhados,
      pausas: pausas ?? this.pausas,
      tempoTotal: tempoTotal ?? this.tempoTotal,
      tempoEtapaAtual: tempoEtapaAtual ?? this.tempoEtapaAtual,
      observacao: observacao != null ? observacao() : this.observacao,
      plannedStages: plannedStages ?? this.plannedStages,
      assinaturas: assinaturas ?? this.assinaturas,
    );
  }
}

class ResumoAssinaturaOp {
  const ResumoAssinaturaOp({
    required this.tipo,
    required this.etapa,
    required this.operador,
    required this.pin,
    required this.quando,
    required this.detalhe,
  });

  final String tipo;
  final String etapa;
  final String operador;
  final String pin;
  final String quando;
  final String detalhe;
}

class MaterialOpDetalhe {
  const MaterialOpDetalhe({
    required this.codigo,
    required this.descricao,
    required this.quantidadePorUnidade,
    required this.quantidadeTotal,
    required this.filial,
    required this.armazem,
    required this.movimentaEstoque,
  });

  final String codigo;
  final String descricao;
  final num quantidadePorUnidade;
  final num quantidadeTotal;
  final String filial;
  final String armazem;
  final bool movimentaEstoque;

  String get label => '$codigo - $descricao';
}

class ResumoPausaOp {
  const ResumoPausaOp({
    required this.etapa,
    required this.motivo,
    required this.operador,
    required this.tempo,
    required this.iniciadaEm,
    required this.status,
    this.quantidadeProduzida = 0,
  });

  final String etapa;
  final String motivo;
  final String operador;
  final String tempo;
  final String iniciadaEm;
  final String status;
  final int quantidadeProduzida;
}

class OrdemArmazenada {
  final String numero;
  final String produto;
  final int quantidadeOriginal;
  final num quantidadeArmazenada;
  final String unidade;
  final String responsavel;
  final String data;

  const OrdemArmazenada({
    required this.numero,
    required this.produto,
    required this.quantidadeOriginal,
    required this.quantidadeArmazenada,
    this.unidade = 'un',
    required this.responsavel,
    required this.data,
  });

  String get qtdOriginalLabel => '$quantidadeOriginal $unidade';

  String get qtdArmazenadaLabel =>
      '${formatProductionQuantity(quantidadeArmazenada).replaceAll('.', ',')} $unidade';

  String get tipoLabel => quantidadeArmazenada >= quantidadeOriginal
      ? 'Armazenada total'
      : 'Armazenada parcial';
}
