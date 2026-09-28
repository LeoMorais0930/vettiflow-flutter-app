import 'package:intl/intl.dart';

enum ReportSector {
  warehouse('almoxarifado', 'Almoxarifado', ['01']),
  smd('smd', 'SMD', ['03']),
  production('producao', 'Produção', ['05']),
  support('suporte', 'Suporte', ['06', '07']),
  expedition('expedicao', 'Expedição', ['10']),
  management('gestao', 'Gestão', ['01', '03', '05', '06', '07', '10']);

  const ReportSector(this.key, this.label, this.warehouses);
  final String key, label;
  final List<String> warehouses;
  String get route => '/$key/relatorios';
  String get homeRoute => this == management ? '/dashboard' : '/$key';
  String get description => this == production
      ? '05 e movimentos vinculados às OPs do 05'
      : '${warehouses.join(', ')} · $label';
  static ReportSector parse(String? key) =>
      values.firstWhere((sector) => sector.key == key, orElse: () => warehouse);
}

const reportWarehouses = {
  '01': 'Almoxarifado',
  '03': 'SMD',
  '05': 'Produção',
  '06': 'Suporte',
  '07': 'Suporte',
  '10': 'Expedição',
};
String reportWarehouse(dynamic code) {
  final local = '${code ?? ''}'.trim();
  return '${local.isEmpty ? 'Não informado' : local}${reportWarehouses.containsKey(local) ? ' · ${reportWarehouses[local]}' : ''}';
}

const reportKinds = {
  'transfer': 'Transferências',
  'production': 'Apontamentos',
  'consumption': 'Consumo de OP',
  'adjustment': 'Ajustes',
  'dismantling': 'Desmontagens',
  'receipt': 'Notas de entrada',
  'dispatch': 'Notas de saída',
  'other': 'Outros',
};
const productionAnalyses = {
  'local_stages': 'Tempos por etapa',
  'local_operators': 'Trabalho por operador',
  'local_pauses': 'Pausas',
  'local_quality': 'Qualidade no teste',
  'output': 'Quantidade apontada',
  'orders': 'Por ordem de produção',
  'evolution': 'Evolução no período',
  'destinations': 'Destino do apontamento',
  'consumption': 'Consumo e devoluções',
  'reversals': 'Estornos',
  'movements': 'Todos os movimentos',
};
const outputAnalyses = ['output', 'orders', 'evolution', 'destinations'];
const reportFlows = {
  'all': 'Todos os sentidos',
  'in': 'Entrada',
  'out': 'Saída',
  'none': 'Sem efeito em estoque',
  'unknown': 'Efeito não identificado',
};
const reportStatuses = {
  'all': 'Todos os registros',
  'active': 'Sem marca de estorno',
  'reversed': 'Marcados como estornados',
};
const reportSources = {
  'all': 'Todas as fontes',
  'SD3': 'Movimentos internos (SD3)',
  'SD1': 'Notas de entrada (SD1)',
  'SD2': 'Notas de saída (SD2)',
};
const reportTextFilters = {
  'product': 'Código do produto',
  'op': 'OP completa',
  'operator': 'Usuário do lançamento',
  'document': 'Documento',
  'unit': 'Unidade',
  'cf': 'CF',
  'tm': 'TM',
  'tes': 'TES',
  'cfop': 'CFOP',
};

String reportNumber(dynamic value) => value is num
    ? NumberFormat('#,##0.########', 'pt_BR').format(value)
    : 'Não informado';
String reportDate(String value) {
  final normalized = value.replaceAll('-', '');
  if (normalized.length == 8) {
    return '${normalized.substring(6, 8)}/${normalized.substring(4, 6)}/${normalized.substring(0, 4)}';
  }
  if (normalized.length == 6) {
    return '${normalized.substring(4)}/${normalized.substring(0, 4)}';
  }
  return 'Não informado';
}

String reportKind(dynamic kind) => reportKinds[kind] ?? '$kind';
String reportFlow(dynamic flow) =>
    reportFlows[flow] ?? 'Efeito não identificado';
String reportSituation(Map<String, dynamic> row) =>
    row['reversed'] == 1 ? 'Estornado' : 'Sem marca de estorno';

class ReportFilters {
  const ReportFilters({
    this.start,
    this.end,
    this.query = '',
    this.kinds = const [],
    this.product = '',
    this.op = '',
    this.operator = '',
    this.document = '',
    this.unit = '',
    this.cf = '',
    this.tm = '',
    this.tes = '',
    this.cfop = '',
    this.source = 'all',
    this.flow = 'all',
    this.status = 'all',
    this.details = false,
    this.warehouses = const [],
    this.analysis = 'movements',
    this.stage = 'all',
  });
  final DateTime? start, end;
  final String query,
      product,
      op,
      operator,
      document,
      unit,
      cf,
      tm,
      tes,
      cfop,
      source,
      flow,
      status;
  final List<String> kinds;
  final List<String> warehouses;
  final String analysis;
  final String stage;
  final bool details;
  Map<String, dynamic> toQuery() => {
    if (start != null) 'start': start!.toIso8601String().substring(0, 10),
    if (end != null) 'end': end!.toIso8601String().substring(0, 10),
    if (query.trim().isNotEmpty) 'query': query.trim(),
    if (kinds.isNotEmpty) 'kinds': kinds,
    if (warehouses.isNotEmpty) 'warehouses': warehouses,
    if (analysis != 'movements') 'analysis': analysis,
    for (final e in {
      'product': product,
      'op': op,
      'operator': operator,
      'document': document,
      'unit': unit,
      'cf': cf,
      'tm': tm,
      'tes': tes,
      'cfop': cfop,
    }.entries)
      if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
    'source': source,
    'flow': flow,
    'status': status,
    'details': '$details',
  };
}

/// A server result is kept intact; preview and PDF always use this same snapshot.
class WarehouseReport {
  WarehouseReport(Map<String, dynamic> json)
    : id = json['id'] as String,
      database = json['database'] as String,
      company = json['company'] as String,
      filial = json['filial'] as String,
      sector = ReportSector.parse(json['sector'] as String?),
      warehouses = List<String>.from(json['warehouses'] as List? ?? ['01']),
      scopeNote = '${json['scopeNote'] ?? 'Movimentos do armazém 01.'}',
      warehouseSummary = _rows(json['warehouseSummary'] ?? []),
      production = json['production'] == null
          ? null
          : ProductionInsights(
              Map<String, dynamic>.from(json['production'] as Map),
            ),
      local = json['local'] == null
          ? null
          : Map<String, dynamic>.unmodifiable(json['local'] as Map),
      total = (json['total'] as num).toInt(),
      filters = Map.unmodifiable(json['filters'] as Map<String, dynamic>),
      summary = _rows(json['summary']),
      series = _rows(json['series']),
      products = _rows(json['products']),
      items = _rows(json['items']),
      productGroupCount = (json['productGroupCount'] as num).toInt(),
      seriesGroupCount = (json['seriesGroupCount'] as num).toInt(),
      detailStatus = json['detailStatus'] as String,
      detailLimit = (json['detailLimit'] as num).toInt(),
      firstRecord = '${json['firstRecord'] ?? ''}',
      lastRecord = '${json['lastRecord'] ?? ''}',
      databaseLatestRecord = '${json['databaseLatestRecord'] ?? ''}',
      startedAt = DateTime.parse(json['startedAt'] as String).toLocal(),
      asOf = DateTime.parse(json['asOf'] as String).toLocal();
  final String id,
      database,
      company,
      filial,
      detailStatus,
      firstRecord,
      lastRecord,
      databaseLatestRecord;
  final int total, productGroupCount, seriesGroupCount, detailLimit;
  final ReportSector sector;
  final List<String> warehouses;
  final String scopeNote;
  final List<Map<String, dynamic>> warehouseSummary;
  final ProductionInsights? production;
  final Map<String, dynamic>? local;
  bool get isLocal => local != null;
  String get originLabel =>
      isLocal ? 'VettiFlow · dados locais deste dispositivo' : 'Protheus DEV';
  String get analysis => '${filters['analysis'] ?? 'movements'}';
  String get analysisLabel => sector == ReportSector.production
      ? productionAnalyses[analysis] ?? 'Movimentações'
      : 'Movimentações';
  final DateTime startedAt, asOf;
  final Map<String, dynamic> filters;
  final List<Map<String, dynamic>> summary, series, products, items;
  static List<Map<String, dynamic>> _rows(dynamic rows) => List.unmodifiable(
    (rows as List).map((e) => Map<String, dynamic>.unmodifiable(e as Map)),
  );
  int get reversedCount => summary
      .where((e) => e['reversed'] == 1)
      .fold(0, (sum, e) => sum + (e['count'] as num).toInt());
  bool get canDetail =>
      detailStatus == 'complete' &&
      items.length == total &&
      total <= detailLimit;
  String get periodLabel {
    final start = DateTime.tryParse('${filters['start']}');
    final end = DateTime.tryParse('${filters['end']}');
    if (start == null || end == null) return 'Todo o período';
    if (start.day == 1 &&
        start.year == end.year &&
        start.month == end.month &&
        end.day == DateTime(end.year, end.month + 1, 0).day) {
      const months = [
        'Janeiro',
        'Fevereiro',
        'Março',
        'Abril',
        'Maio',
        'Junho',
        'Julho',
        'Agosto',
        'Setembro',
        'Outubro',
        'Novembro',
        'Dezembro',
      ];
      return '${months[start.month - 1]} de ${start.year}';
    }
    return '${reportDate('${filters['start']}')} a ${reportDate('${filters['end']}')}';
  }

  List<String> get filterLabels => [
    periodLabel,
    if (sector == ReportSector.production) analysisLabel,
    if (!isLocal) 'Armazéns: ${warehouses.join(', ')}',
    if (!isLocal) reportStatuses[filters['status']] ?? reportStatuses['all']!,
    if (isLocal && filters['stageLabel'] != null)
      'Etapa: ${filters['stageLabel']}',
    if ('${filters['query'] ?? ''}'.isNotEmpty) 'Busca: ${filters['query']}',
    if ((filters['kinds'] as List? ?? []).isNotEmpty)
      'Movimentos: ${(filters['kinds'] as List).map(reportKind).join(', ')}',
    for (final e in reportTextFilters.entries)
      if ('${filters[e.key] ?? ''}'.isNotEmpty)
        '${isLocal && e.key == 'operator' ? 'Operador' : e.value}: ${filters[e.key]}',
    if (filters['source'] != null && filters['source'] != 'all')
      reportSources[filters['source']]!,
    if (filters['flow'] != null && filters['flow'] != 'all')
      reportFlow(filters['flow']),
  ];
  String get detailNotice => switch (detailStatus) {
    'too_large' =>
      'O recorte tem ${reportNumber(total)} registros. O PDF detalhado aceita até ${reportNumber(detailLimit)}. Gere o resumo completo ou reduza o período.',
    'changed' =>
      'Os dados mudaram durante a consulta. Atualize para incluir o detalhamento.',
    'complete' =>
      '${reportNumber(total)} registros disponíveis para o detalhamento.',
    _ =>
      'Resumo do recorte completo. Ative o detalhamento e aplique os filtros para incluir os registros.',
  };
  String get productNotice =>
      '${reportNumber(products.length)} de ${reportNumber(productGroupCount)} grupos por produto, unidade, armazém, movimento, sentido e estorno. Ordenados por número de registros.';
  List<String> get notes => isLocal
      ? List<String>.from(local!['notes'] as List)
      : [
          scopeNote,
          if (production != null) ...[
            'Quantidade apontada: PR0 sem marca de estorno, pela data do movimento. ER0, consumo e transferências ficam fora desta medida; não é calculado saldo líquido de estornos.',
            'OPs com apontamento não são OPs encerradas. Dias com apontamento não são dias trabalhados. Esta fonte não informa horas trabalhadas, metas ou eficiência por pessoa.',
            production!.notice,
          ],
          if (analysis == 'reversals')
            'Inclui ER0 e registros marcados como estornados. São ocorrências separadas; não somar suas quantidades como perdas ou subtrair duas vezes da produção.',
          if (sector == ReportSector.production)
            'O local efetivo está indicado em cada registro. Há sobreposição com relatórios de outros setores; não some seus totais ao da produção.',
          if (sector == ReportSector.smd)
            'Apontamentos e consumo são movimentos diferentes. A conta do lançamento não comprova que cada consumo foi digitado manualmente pela operadora.',
          if (sector == ReportSector.support)
            'Movimentos e notas não comprovam, por si só, reparos concluídos.',
          if (sector == ReportSector.expedition)
            'Itens de notas não comprovam entrega ao cliente. Este modelo não apura rastreio ou prazo de entrega.',
          'Contagens representam registros de movimentos ou itens de notas, não peças, notas ou transferências pareadas.',
          'Quantidades separadas por produto e unidade. Entradas, saídas e estornos não são somados como saldo.',
          'SD3: data do movimento. SD1: digitação. SD2: emissão. Efeito fiscal em estoque conforme cadastro atual da TES.',
          'Consulta do DEV; não representa fechamento histórico de estoque. Leituras entre ${DateFormat('dd/MM/yyyy HH:mm:ss').format(startedAt)} e ${DateFormat('dd/MM/yyyy HH:mm:ss').format(asOf)}.',
          if (productGroupCount > products.length)
            'O quadro de produtos é um ranking limitado; os totais por movimento abrangem o recorte completo.',
          if (seriesGroupCount > series.length)
            'Evolução limitada aos ${series.length} períodos com registro mais recentes, de $seriesGroupCount. O resumo considera todos.',
        ];
}

class ProductionInsights {
  ProductionInsights(Map<String, dynamic> json)
    : metrics = Map<String, dynamic>.unmodifiable(json['metrics'] as Map),
      rows = WarehouseReport._rows(json['rows']),
      groupCount = (json['groupCount'] as num).toInt(),
      periodUnit = '${json['periodUnit']}';
  final Map<String, dynamic> metrics;
  final List<Map<String, dynamic>> rows;
  final int groupCount;
  final String periodUnit;
  String get notice =>
      '${rows.length} de $groupCount grupos. Quantidades por produto e unidade; grupos ordenados por registros, ou pelos períodos mais recentes na evolução. Indicadores calculados no recorte completo.';
  bool get comparableQuantities =>
      rows.isNotEmpty &&
      rows.map((r) => '${r['code']}|${r['unit']}').toSet().length == 1;
  static String rowLabel(
    Map<String, dynamic> row,
    String analysis,
  ) => switch (analysis) {
    'orders' =>
      '${'${row['op'] ?? ''}'.trim().isEmpty ? 'Sem OP informada' : 'OP ${row['op']}'} · ${row['code']}',
    'evolution' => '${reportDate('${row['period']}')} · ${row['code']}',
    'destinations' => 'Local ${row['warehouse']} · ${row['code']}',
    _ => '${row['code']} · ${row['description']}',
  };
}
