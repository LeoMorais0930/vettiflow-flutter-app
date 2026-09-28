import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_read_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/read_period_filter.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';
import 'warehouse_report_pdf.dart';
import 'production_insights_panel.dart';
import 'local_production_panel.dart';
import 'package:vetti_flow_1_0/data/models/local_production_report.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';

class WarehouseReportPage extends StatefulWidget {
  const WarehouseReportPage({
    super.key,
    this.initialFilters,
    this.sector = ReportSector.warehouse,
  });
  final ReportFilters? initialFilters;
  final ReportSector sector;
  @override
  State<WarehouseReportPage> createState() => _WarehouseReportPageState();
}

class _WarehouseReportPageState extends State<WarehouseReportPage> {
  final _text = <String, TextEditingController>{};
  final _kinds = <String>{};
  final _warehouses = <String>{};
  final _mobileFilters = ExpansibleController();
  DateTime? _start, _end;
  String _source = 'all', _flow = 'all', _status = 'all';
  String _analysis = 'movements';
  String _stage = 'all';
  bool get _localAnalysis =>
      widget.sector == ReportSector.production &&
      _analysis.startsWith('local_');
  bool get _productionPreset =>
      widget.sector == ReportSector.production && _analysis != 'movements';
  bool _details = false,
      _chart = true,
      _loading = false,
      _exporting = false,
      _dirty = true;
  String? _error;
  int _revision = 0, _productPage = 0, _detailPage = 0;
  WarehouseReport? _report;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final f =
        widget.initialFilters ??
        ReportFilters(
          start: DateTime(now.year, now.month),
          end: DateTime(now.year, now.month + 1, 0),
          kinds: widget.sector == ReportSector.smd
              ? const ['production']
              : const [],
          analysis: widget.sector == ReportSector.production
              ? 'local_stages'
              : 'movements',
        );
    _start = f.start;
    _end = f.end;
    _source = f.source;
    _flow = f.flow;
    _status = f.status;
    _details = f.details;
    _analysis = f.analysis;
    _stage = f.stage;
    _kinds.addAll(f.kinds);
    _warehouses.addAll(f.warehouses.where(widget.sector.warehouses.contains));
    final values = {
      'query': f.query,
      'product': f.product,
      'op': f.op,
      'operator': f.operator,
      'document': f.document,
      'unit': f.unit,
      'cf': f.cf,
      'tm': f.tm,
      'tes': f.tes,
      'cfop': f.cfop,
    };
    for (final entry in values.entries) {
      _text[entry.key] = TextEditingController(text: entry.value);
    }
  }

  @override
  void dispose() {
    _mobileFilters.dispose();
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _edit(VoidCallback change) => setState(() {
    change();
    _dirty = true;
    _revision++;
  });
  ReportFilters get _filters => ReportFilters(
    start: _start,
    end: _end,
    query: _text['query']!.text,
    kinds: _kinds.toList(),
    product: _text['product']!.text,
    op: _text['op']!.text,
    operator: _text['operator']!.text,
    document: _text['document']!.text,
    unit: _text['unit']!.text,
    cf: _text['cf']!.text,
    tm: _text['tm']!.text,
    tes: _text['tes']!.text,
    cfop: _text['cfop']!.text,
    source: _source,
    flow: _flow,
    status: _status,
    details: _details,
    warehouses: _warehouses.toList(),
    analysis: _analysis,
    stage: _stage,
  );

  Future<void> _apply() async {
    if (context
            .read<OperatorAssignmentStore?>()
            ?.currentOperator
            ?.canAccessRoute(widget.sector.route) !=
        true) {
      return;
    }
    _mobileFilters.collapse();
    final repo = context.read<WarehouseReadRepository?>();
    final revision = _revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      WarehouseReport result;
      if (_localAnalysis) {
        final store = context.read<ProductionFlowStore?>();
        if (store == null) throw StateError('Dados locais indisponíveis');
        result = buildLocalProductionReport(store.orders, _filters);
      } else {
        if (repo == null) throw StateError('API indisponível');
        result = await repo.report(_filters, sector: widget.sector);
      }
      if (!mounted || revision != _revision) return;
      setState(() {
        _report = result;
        _dirty = false;
        _productPage = 0;
        _detailPage = 0;
      });
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() {
          _report = null;
          _error = _localAnalysis
              ? 'Não foi possível ler os dados locais do VettiFlow.'
              : 'Não foi possível gerar o relatório. Tente novamente.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    final report = _report;
    if (report == null || _dirty) return;
    setState(() => _exporting = true);
    try {
      // Let the progress state paint before the bounded document is rendered.
      await Future<void>.delayed(Duration.zero);
      final bytes = await buildWarehouseReportPdf(
        report,
        includeDetails: _details && report.canDetail,
        includeChart: _chart,
      );
      if (!mounted) return;
      final filename =
          '${report.sector.key}-${report.analysis}-${report.id}.pdf';
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(
                'PDF · ${report.sector.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Salvar PDF'),
                  onPressed: () async {
                    try {
                      await Printing.sharePdf(bytes: bytes, filename: filename);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Não foi possível salvar o PDF.'),
                          ),
                        );
                      }
                    }
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Imprimir'),
                  onPressed: () async {
                    try {
                      await Printing.layoutPdf(
                        onLayout: (_) async => bytes,
                        name: filename,
                      );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Não foi possível abrir a impressão.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            body: PdfPreview(
              build: (_) async => bytes,
              pdfFileName: filename,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              dynamicLayout: false,
              allowPrinting: false,
              allowSharing: false,
              useActions: false,
              onError: (_, _) => const Center(
                child: Text(
                  'Não foi possível mostrar a prévia. Use Salvar PDF.',
                ),
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível montar o PDF. Reduza o detalhamento ou gere apenas o resumo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final operator = context.watch<OperatorAssignmentStore?>()?.currentOperator;
    if (operator?.canAccessRoute(widget.sector.route) != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Relatórios da gestão')),
        body: const Center(
          child: Text('Este relatório não faz parte do seu acesso.'),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, size) {
        final compact = size.maxWidth < 920;
        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          body: Column(
            children: [
              VettiTopBar(
                title: 'Relatórios',
                operatorName: operator?.name ?? 'Consulta',
                operatorRole: widget.sector.label,
                compact: compact,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(compact ? 12 : 28),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Voltar · ${widget.sector.label}',
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.of(context).canPop()
                                ? Navigator.of(context).pop()
                                : Navigator.of(context).pushReplacementNamed(
                                    widget.sector.homeRoute,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.sector == ReportSector.production
                                      ? 'Relatórios da produção'
                                      : 'Relatórios · ${widget.sector.label}',
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.title,
                                  ),
                                ),
                                Text(
                                  _localAnalysis
                                      ? 'VettiFlow · operação da produção'
                                      : '${widget.sector.description} · Protheus DEV',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          children: [
                            _panel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 10,
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        readPeriodLabel(_start, _end),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      FilledButton.icon(
                                        onPressed: _loading ? null : _apply,
                                        icon: const Icon(
                                          Icons.bar_chart_outlined,
                                        ),
                                        label: Text(
                                          _loading
                                              ? 'Consultando...'
                                              : 'Gerar prévia',
                                        ),
                                      ),
                                    ],
                                  ),
                                  ExpansionTile(
                                    controller: _mobileFilters,
                                    tilePadding: EdgeInsets.zero,
                                    title: const Text('Ajustar filtros'),
                                    subtitle: Text(_filterSummary),
                                    children: [_filterContent()],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _preview(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _panel({required Widget child}) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.title,
      ),
    ),
  );
  Widget _field(String key, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: ValueKey('report-$key'),
      controller: _text[key],
      maxLength: key == 'query'
          ? 100
          : key == 'operator'
          ? 50
          : key == 'product'
          ? 40
          : ['op', 'document'].contains(key)
          ? 30
          : 10,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => _edit(() {}),
    ),
  );
  Widget _select(
    String label,
    String value,
    Map<String, String> choices,
    ValueChanged<String> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      key: ValueKey('report-select-$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: choices.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) _edit(() => change(v));
      },
    ),
  );

  String get _filterSummary {
    final count =
        _text.values.where((c) => c.text.trim().isNotEmpty).length +
        (_status == 'all' ? 0 : 1) +
        (_source == 'all' ? 0 : 1) +
        (_flow == 'all' ? 0 : 1) +
        (_kinds.isEmpty ? 0 : 1) +
        (_warehouses.isEmpty ? 0 : 1) +
        (_stage == 'all' ? 0 : 1);
    final selection = count == 0
        ? 'Sem filtros adicionais'
        : '$count filtros adicionais';
    return widget.sector == ReportSector.production
        ? '${productionAnalyses[_analysis]} · $selection'
        : selection;
  }

  Widget _filterContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.sector == ReportSector.production) ...[
        _select(
          'Fonte dos dados',
          _localAnalysis ? 'vettiflow' : 'protheus',
          const {
            'vettiflow': 'VettiFlow · operação',
            'protheus': 'Protheus · movimentos',
          },
          (value) {
            _analysis = value == 'vettiflow' ? 'local_stages' : 'output';
            _stage = 'all';
            _kinds.clear();
            _source = _flow = _status = 'all';
            for (final key in [
              'operator',
              'document',
              'unit',
              'cf',
              'tm',
              'tes',
              'cfop',
            ]) {
              _text[key]!.clear();
            }
          },
        ),
        _select(
          'O que analisar',
          _analysis,
          Map.fromEntries(
            productionAnalyses.entries.where(
              (entry) => entry.key.startsWith('local_') == _localAnalysis,
            ),
          ),
          (value) {
            _analysis = value;
            _stage = 'all';
            _text['operator']!.clear();
            _kinds.clear();
            _source = _flow = _status = 'all';
            for (final key in ['cf', 'tm', 'tes', 'cfop']) {
              _text[key]!.clear();
            }
          },
        ),
        if (outputAnalyses.contains(_analysis))
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Apontamentos PR0 sem marca de estorno.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
      ],
      if (widget.sector.warehouses.length > 1) ...[
        const Text('Armazéns'),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final local in widget.sector.warehouses)
              FilterChip(
                label: Text(
                  reportWarehouse(local),
                  style: const TextStyle(fontSize: 12),
                ),
                selected: _warehouses.contains(local),
                onSelected: (selected) => _edit(() {
                  if (selected) {
                    _warehouses.add(local);
                  } else {
                    _warehouses.remove(local);
                  }
                }),
              ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Nenhum armazém marcado = todos os deste relatório.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      ],
      ReadPeriodFilter(
        dateLabel: _localAnalysis
            ? (_analysis == 'local_pauses'
                  ? 'Data da retomada'
                  : 'Data da conclusão')
            : 'Data do movimento',
        start: _start,
        end: _end,
        onChanged: (range) => _edit(() {
          _start = range?.start;
          _end = range?.end;
        }),
      ),
      const SizedBox(height: 14),
      _field(
        'query',
        _localAnalysis ? 'Buscar produto ou OP' : 'Produto, OP ou documento',
      ),
      if (!_productionPreset)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Tipos e situação'),
          subtitle: Text(
            _kinds.isEmpty
                ? 'Todos os tipos'
                : '${_kinds.length} tipos selecionados',
          ),
          children: [
            _select('Situação', _status, reportStatuses, (v) => _status = v),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final e in reportKinds.entries)
                  FilterChip(
                    label: Text(e.value, style: const TextStyle(fontSize: 12)),
                    selected: _kinds.contains(e.key),
                    onSelected: (selected) => _edit(() {
                      if (selected) {
                        _kinds.add(e.key);
                      } else {
                        _kinds.remove(e.key);
                      }
                    }),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Nenhum tipo marcado = todos.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Produto, OP e operador'),
        children: [
          _field('product', 'Código do produto'),
          _field('op', 'OP completa'),
          if (!_localAnalysis ||
              ['local_operators', 'local_pauses'].contains(_analysis))
            _field(
              'operator',
              _localAnalysis ? 'Operador (nome)' : 'Usuário do lançamento',
            ),
          if (_localAnalysis && _analysis != 'local_quality')
            _select('Etapa', _stage, {
              'all': 'Todas as etapas',
              for (final stage in ProductionStage.productionFlow)
                stage.name: stage.label,
            }, (value) => _stage = value),
          if (_localAnalysis)
            const Text(
              'Período pela conclusão da etapa, sessão ou teste; nas pausas, pela retomada.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
        ],
      ),
      if (!_localAnalysis) ...[
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Mais filtros'),
          children: [
            if (!_productionPreset) ...[
              _select('Fonte', _source, reportSources, (v) => _source = v),
              _select('Sentido', _flow, reportFlows, (v) => _flow = v),
            ],
            for (final key
                in _productionPreset
                    ? ['document', 'unit', 'tm']
                    : ['document', 'unit', 'cf', 'tm', 'tes', 'cfop'])
              _field(key, reportTextFilters[key]!),
            if (!_productionPreset)
              const Text(
                'Usuário, OP, CF e TM filtram movimentos internos. TES e CFOP filtram notas. Combinar os dois grupos pode deixar o recorte vazio.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
          ],
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Incluir registros no PDF'),
          subtitle: const Text(
            'Até 1.000 linhas e 60 páginas. Resumo sem limite de período.',
          ),
          value: _details,
          onChanged: (v) => _edit(() => _details = v ?? false),
        ),
      ],
      const SizedBox(height: 10),
    ],
  );

  Widget _preview() {
    final report = _report;
    final summaryOnly =
        report?.detailStatus == 'too_large' ||
        report?.detailStatus == 'changed';
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Prévia do relatório',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.title,
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('report-pdf'),
                onPressed: report == null || _dirty || _loading || _exporting
                    ? null
                    : _export,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  _exporting
                      ? 'Preparando...'
                      : summaryOnly
                      ? 'Gerar resumo em PDF'
                      : 'Gerar PDF',
                ),
              ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          if (_dirty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Aplique os filtros para atualizar o relatório.'),
            ),
          if (!_dirty && report != null) ...[
            if (summaryOnly)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  report.detailNotice,
                  style: const TextStyle(color: AppColors.orangeText),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              report.filterLabels.join(' · '),
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            if (report.isLocal) ...[
              LocalProductionPanel(key: ValueKey(report.id), report: report),
              const SizedBox(height: 12),
              Text(
                'Último evento do recorte: ${reportDate(report.lastRecord)} · Consulta: ${DateFormat('dd/MM/yyyy HH:mm').format(report.asOf)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ] else if (report.production != null) ...[
              ProductionInsightsPanel(
                key: ValueKey(report.id),
                report: report,
                onFilter: (row) => _edit(() {
                  _text['product']!.text = '${row['code']}';
                  _text['unit']!.text = '${row['unit']}';
                  if (report.analysis == 'orders' &&
                      '${row['op'] ?? ''}'.trim().isNotEmpty) {
                    _text['op']!.text = '${row['op']}';
                  }
                }),
              ),
              const SizedBox(height: 14),
              Text(
                'Último apontamento do recorte: ${reportDate(report.lastRecord)} · Consulta: ${DateFormat('dd/MM/yyyy HH:mm').format(report.asOf)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (report.production!.comparableQuantities)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incluir gráfico de quantidades no PDF'),
                  value: _chart,
                  onChanged: (v) => setState(() => _chart = v ?? true),
                ),
            ] else ...[
              Wrap(
                spacing: 14,
                runSpacing: 12,
                children: [
                  _metric('Registros no recorte', reportNumber(report.total)),
                  _metric(
                    'Marcados como estornados',
                    reportNumber(report.reversedCount),
                  ),
                  _metric(
                    'Último registro do recorte',
                    reportDate(report.lastRecord),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Consultado em ${DateFormat('dd/MM/yyyy HH:mm').format(report.asOf)} · ${report.database}\nÚltimo registro nas tabelas do DEV: ${reportDate(report.databaseLatestRecord)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const Divider(height: 32),
              if (report.sector != ReportSector.warehouse) ...[
                Text(
                  report.scopeNote,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                _heading('Registros por armazém'),
                for (final row in report.warehouseSummary)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(reportWarehouse(row['warehouse'])),
                        ),
                        Text(reportNumber(row['count'])),
                      ],
                    ),
                  ),
                const Divider(height: 24),
              ],
              _heading('Resumo por movimento'),
              if (report.total == 0)
                const Text(
                  'Nenhum registro encontrado para os filtros selecionados.',
                ),
              for (final row in report.summary)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${reportKind(row['kind'])} · ${reportFlow(row['flow'])}\n${reportSituation(row)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        reportNumber(row['count']),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 32),
              _heading('Evolução de registros'),
              _evolution(report),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Incluir gráfico no PDF'),
                value: _chart,
                onChanged: (v) => setState(() => _chart = v ?? true),
              ),
              const Divider(height: 32),
              _heading('Quantidades por produto e unidade'),
              Text(
                report.productNotice,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              for (final row
                  in report.products.skip(_productPage * 20).take(20))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${row['code']} · ${row['description']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${reportKind(row['kind'])} · ${reportFlow(row['flow'])} · ${reportSituation(row)}\nLocal ${row['warehouse'] ?? report.warehouses.join(', ')} · ${reportNumber(row['quantity'])} ${row['unit']} · ${reportNumber(row['count'])} registros',
                  ),
                  trailing: IconButton(
                    tooltip: 'Filtrar este produto',
                    icon: const Icon(Icons.filter_alt_outlined, size: 19),
                    onPressed: () =>
                        _edit(() => _text['product']!.text = '${row['code']}'),
                  ),
                ),
              if (report.products.length > 20)
                _pager(
                  _productPage,
                  report.products.length,
                  (v) => setState(() => _productPage = v),
                ),
            ],
            const Divider(height: 32),
            if (!report.isLocal) ...[
              _heading('Detalhamento'),
              Text(report.detailNotice),
              if (report.canDetail) ...[
                for (final row in report.items.skip(_detailPage * 20).take(20))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${reportDate('${row['date']}')} · ${row['code']}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      '${reportKind(row['kind'])} · ${reportFlow(row['flow'])} · ${reportNumber(row['quantity'])} ${row['unit']}\nLocal ${row['warehouse'] ?? ''} · Doc. ${row['document']} · ${row['source']}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showRecord(row),
                  ),
                if (report.items.length > 20)
                  _pager(
                    _detailPage,
                    report.items.length,
                    (v) => setState(() => _detailPage = v),
                  ),
              ],
              const Divider(height: 32),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Como ler os números'),
              children: [
                for (final note in report.notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      note,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Container(
    width: 210,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.title,
          ),
        ),
      ],
    ),
  );
  Widget _evolution(WarehouseReport report) {
    final points = report.series.length > 24
        ? report.series.sublist(report.series.length - 24)
        : report.series;
    final maximum = points.fold<num>(
      1,
      (m, e) => (e['count'] as num) > m ? e['count'] as num : m,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Até 24 períodos com registro mais recentes. Contagem de registros, não peças.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        for (final row in points)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    reportDate('${row['period']}'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (row['count'] as num) / maximum,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(
                  width: 58,
                  child: Text(
                    reportNumber(row['count']),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _pager(int page, int total, ValueChanged<int> change) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      IconButton(
        tooltip: 'Página anterior',
        onPressed: page == 0 ? null : () => change(page - 1),
        icon: const Icon(Icons.chevron_left),
      ),
      Text('${page + 1} / ${(total / 20).ceil()}'),
      IconButton(
        tooltip: 'Próxima página',
        onPressed: (page + 1) * 20 >= total ? null : () => change(page + 1),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
  Future<void> _showRecord(Map<String, dynamic> row) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${row['code']} · ${row['source']}'),
      content: SingleChildScrollView(
        child: SelectableText(
          [
            '${row['description']}',
            '${reportDate('${row['date']}')} · ${reportSituation(row)}',
            '${reportKind(row['kind'])} · ${reportFlow(row['flow'])}',
            'Quantidade: ${reportNumber(row['quantity'])} ${row['unit']}',
            for (final e in {
              'warehouse': 'Armazém do registro',
              'document': 'Documento',
              'series': 'Série',
              'op': 'OP',
              'operator': 'Usuário',
              'cf': 'CF',
              'tm': 'TM',
              'tes': 'TES',
              'cfop': 'CFOP',
              'otherWarehouse': 'Local da contraparte',
              'otherCode': 'Produto da contraparte',
            }.entries)
              '${e.value}: ${'${row[e.key] ?? ''}'.isEmpty ? 'Não informado' : row[e.key]}',
          ].join('\n\n'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );
}
