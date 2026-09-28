import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'dart:async';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart';
import 'package:vetti_flow_1_0/ui/reports/warehouse_report_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_read_repository.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/shared/layout/app_breakpoints.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/read_period_filter.dart';

bool _isAdministrator(Operator? operator) =>
    operator?.area == WorkArea.system && operator?.canManageAssignments == true;

class WarehousePage extends WarehouseReadPage {
  const WarehousePage({super.key});
}

class WarehouseNavigationButton extends StatelessWidget {
  const WarehouseNavigationButton({super.key});

  @override
  Widget build(BuildContext context) {
    final operator = context.watch<OperatorAssignmentStore?>()?.currentOperator;
    if (operator?.canView(AppSector.warehouse) != true) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      icon: const Icon(Icons.warehouse_outlined, size: 20),
      label: Text(
        _isAdministrator(operator) ? 'Consulta administrativa' : 'Almoxarifado',
      ),
      onPressed: () => Navigator.of(context).pushNamed(
        _isAdministrator(operator) ? '/admin/armazens' : '/almoxarifado',
      ),
    );
  }
}

class WarehouseReadPage extends StatefulWidget {
  const WarehouseReadPage({super.key, this.administrative = false})
    : smd = false,
      expedition = false,
      support = false,
      sectorAction = null,
      production = false;
  const WarehouseReadPage.smd({super.key, this.sectorAction})
    : administrative = false,
      expedition = false,
      smd = true,
      support = false,
      production = false;
  const WarehouseReadPage.production({super.key, this.sectorAction})
    : administrative = false,
      expedition = false,
      smd = false,
      support = false,
      production = true;
  const WarehouseReadPage.support({super.key, this.sectorAction})
    : administrative = false,
      expedition = false,
      smd = false,
      production = false,
      support = true;
  const WarehouseReadPage.expedition({super.key, this.sectorAction})
    : administrative = false,
      smd = false,
      production = false,
      support = false,
      expedition = true;
  final bool expedition;
  final bool support;
  final Widget? sectorAction;
  final bool production;
  final bool smd;
  final bool administrative;
  @override
  State<WarehouseReadPage> createState() => _WarehouseReadPageState();
}

const _warehouseViews = ['overview', 'history', 'stock', 'orders', 'inventory'];
const _warehouseTabs = [
  'Visão geral',
  'Histórico',
  'Estoque',
  'OPs',
  'Inventário',
];
const _kinds = {
  'all': 'Todos os movimentos',
  'transfer': 'Transferências',
  'production': 'Produção',
  'consumption': 'Consumo de OP',
  'adjustment': 'Ajustes',
  'dismantling': 'Desmontagens',
  'receipt': 'Notas de entrada',
  'dispatch': 'Notas de saída',
  'other': 'Outros',
};

class _WarehouseReadPageState extends State<WarehouseReadPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool get _sectorProduction => widget.smd || widget.production;
  bool get _hasFiscalTabs => widget.support || widget.expedition;
  bool get _fiscalNotes => _hasFiscalTabs && _tab == 2;
  List<String> get _views => _hasFiscalTabs
      ? const ['overview', 'history', 'history', 'stock', 'orders', 'inventory']
      : _sectorProduction
      ? const ['orders', 'history', 'history', 'history', 'stock']
      : _warehouseViews;
  List<String> get _tabs => _hasFiscalTabs
      ? const [
          'Visão geral',
          'Histórico',
          'Notas',
          'Estoque',
          'OPs',
          'Inventário',
        ]
      : _sectorProduction
      ? const ['OPs', 'Apontamentos', 'Consumo', 'Movimentações', 'Estoque']
      : _warehouseTabs;
  bool get _isHistory => _view == 'history' || _view == 'overview';
  ReportSector get _reportSector => widget.administrative
      ? ReportSector.management
      : widget.expedition
      ? ReportSector.expedition
      : widget.support
      ? ReportSector.support
      : widget.production
      ? ReportSector.production
      : widget.smd
      ? ReportSector.smd
      : ReportSector.warehouse;
  String get _title => widget.expedition
      ? 'Expedição'
      : widget.support
      ? 'Suporte'
      : widget.production
      ? 'Produção'
      : widget.smd
      ? 'SMD'
      : widget.administrative
      ? 'Armazéns'
      : 'Almoxarifado';
  @override
  void initState() {
    super.initState();
    if (_sectorProduction) {
      _local = widget.production ? '05' : '03';
      _status = 'active';
    }
    if (widget.support) _local = '06';
    if (widget.expedition) _local = '10';
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  Future<WarehouseReadSnapshot>? _future;
  int _tab = 0;
  int _page = 1;
  int _pageSize = 50;
  String _local = '01';
  String _kind = 'all';
  String _status = 'all';
  DateTime? _end;
  DateTime? _start;
  bool get _allowed =>
      context.read<OperatorAssignmentStore?>()?.currentOperator?.canAccessRoute(
        widget.administrative ? '/admin/armazens' : _reportSector.homeRoute,
      ) ==
      true;

  String get _view => _views[_tab];
  WarehouseReadRepository? get _repo =>
      context.read<WarehouseReadRepository?>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_allowed) _future ??= _fetch();
  }

  Future<WarehouseReadSnapshot>? _fetch() {
    final future = !_allowed
        ? null
        : _repo?.fetch(
            view: _view,
            production: widget.production,
            support: widget.support,
            expedition: widget.expedition,
            local: _local,
            start: _start,
            end: _end,
            query: _search.text.trim(),
            kind: _kind,
            status: _status,
            page: _page,
            pageSize: _view == 'overview' ? 8 : _pageSize,
          );
    // A retry can fail before the next frame subscribes the FutureBuilder.
    // Observe it immediately; the original future still drives the error UI.
    future?.ignore();
    return future;
  }

  void _reload({bool resetPage = true}) {
    _debounce?.cancel();
    setState(() {
      if (resetPage) _page = 1;
      _future = _fetch();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _selectTab(int value) {
    _tabController.animateTo(value);
    _tab = value;
    _status = _sectorProduction && _view == 'orders' ? 'active' : 'all';
    _kind = _fiscalNotes
        ? 'fiscal'
        : _sectorProduction && value == 1
        ? 'production'
        : _sectorProduction && value == 2
        ? 'consumption'
        : 'all';
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operator = context.watch<OperatorAssignmentStore?>()?.currentOperator;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.expanded;
        final content = Column(
          children: [
            VettiTopBar(
              title: _title,
              operatorName: operator?.name ?? 'Consulta',
              operatorRole: widget.administrative ? 'Administração' : _title,
              compact: compact,
            ),
            Expanded(
              child: !_allowed
                  ? const _Notice(
                      'Acesso ao setor',
                      'Este setor não faz parte do seu acesso.',
                    )
                  : Padding(
                      padding: compact
                          ? const EdgeInsets.fromLTRB(12, 18, 12, 12)
                          : const EdgeInsets.fromLTRB(40, 32, 40, 28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppBreakpoints.maxContentWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.administrative
                                        ? 'Consulta administrativa'
                                        : 'Consulta do Protheus',
                                    style: TextStyle(
                                      fontSize: compact ? 20 : 24,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.title,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_reportSector.description} · Filial 04',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      if (!widget.administrative)
                                        FilledButton.icon(
                                          onPressed: () => Navigator.pushNamed(
                                            context,
                                            _operationRoute,
                                          ),
                                          icon: Icon(
                                            widget.smd
                                                ? Icons.add_task
                                                : Icons.play_arrow_outlined,
                                          ),
                                          label: Text(
                                            widget.smd
                                                ? 'Apontamentos'
                                                : !_sectorProduction &&
                                                      !_hasFiscalTabs
                                                ? 'Atender materiais'
                                                : 'Operação',
                                          ),
                                        ),
                                      OutlinedButton.icon(
                                        onPressed: _showActions,
                                        icon: const Icon(Icons.more_horiz),
                                        label: const Text('Mais opções'),
                                      ),
                                      IconButton(
                                        tooltip: 'Atualizar',
                                        onPressed: () =>
                                            _reload(resetPage: false),
                                        icon: const Icon(Icons.refresh),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              if (constraints.maxWidth < 1100)
                                DropdownButtonFormField<int>(
                                  key: ValueKey('consultation-tab-$_tab'),
                                  initialValue: _tab,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Consultar',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: [
                                    for (var i = 0; i < _tabs.length; i++)
                                      DropdownMenuItem(
                                        value: i,
                                        child: Text(_tabs[i]),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) _selectTab(value);
                                  },
                                )
                              else
                                _panel(
                                  TabBar(
                                    controller: _tabController,
                                    onTap: _selectTab,
                                    tabs: [
                                      for (final label in _tabs)
                                        Tab(text: label),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 18),
                              Expanded(
                                child: FutureBuilder<WarehouseReadSnapshot>(
                                  future: _future,
                                  builder: (context, snapshot) {
                                    final loading =
                                        snapshot.connectionState ==
                                        ConnectionState.waiting;
                                    final data = loading || snapshot.hasError
                                        ? null
                                        : snapshot.data;
                                    final records = Column(
                                      children: [
                                        if (loading)
                                          const LinearProgressIndicator(
                                            minHeight: 2,
                                          ),
                                        Expanded(
                                          child: ListView(
                                            controller: _scroll,
                                            padding: const EdgeInsets.all(16),
                                            children: [
                                              ...[
                                                ExpansionTile(
                                                  tilePadding: EdgeInsets.zero,
                                                  title: const Text('Filtros'),
                                                  subtitle: Text(
                                                    _view == 'stock'
                                                        ? 'Saldos atuais'
                                                        : readPeriodLabel(
                                                            _start,
                                                            _end,
                                                          ),
                                                  ),
                                                  children: [
                                                    _filters(),
                                                    const SizedBox(height: 12),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                              ],
                                              if (_future == null)
                                                const _Notice(
                                                  'Consulta indisponível',
                                                  'Configure a conexão com a API para carregar os dados.',
                                                )
                                              else if (snapshot.hasError)
                                                _Notice(
                                                  'Não foi possível carregar',
                                                  'Verifique a conexão e tente novamente.',
                                                  action: TextButton.icon(
                                                    onPressed: _reload,
                                                    icon: const Icon(
                                                      Icons.refresh,
                                                    ),
                                                    label: const Text(
                                                      'Tentar novamente',
                                                    ),
                                                  ),
                                                )
                                              else if (data != null) ...[
                                                Tooltip(
                                                  message:
                                                      'Maior data de movimentos, notas, OPs e inventários de todos os armazéns e filiais da empresa no DEV. Atualização em até 1 minuto.',
                                                  child: _timestamp(data),
                                                ),
                                                const SizedBox(height: 16),
                                                if (_view == 'overview') ...[
                                                  _summary(data),
                                                  const SizedBox(height: 24),
                                                  const Text(
                                                    'Últimos registros',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                ],
                                                if (widget.production &&
                                                    _isHistory)
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                      bottom: 12,
                                                    ),
                                                    child: Text(
                                                      'Movimentos do armazém 05 e das suas OPs, incluindo outros destinos.',
                                                      style: TextStyle(
                                                        color: AppColors.muted,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                if (_view == 'stock')
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                      bottom: 16,
                                                    ),
                                                    child: Text(
                                                      'Saldos atuais. Empenhado e reservado são exibidos separadamente.',
                                                      style: TextStyle(
                                                        color: AppColors.muted,
                                                      ),
                                                    ),
                                                  ),
                                                if (_view == 'orders')
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                      bottom: 16,
                                                    ),
                                                    child: Text(
                                                      'Abra uma OP para ver seus empenhos e movimentos.',
                                                      style: TextStyle(
                                                        color: AppColors.muted,
                                                      ),
                                                    ),
                                                  ),
                                                if (_view == 'inventory')
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                      bottom: 16,
                                                    ),
                                                    child: Text(
                                                      'Contagens do Protheus. Os acertos de estoque aparecem no Histórico.',
                                                      style: TextStyle(
                                                        color: AppColors.muted,
                                                      ),
                                                    ),
                                                  ),
                                                if (data.items.isEmpty)
                                                  const _Notice(
                                                    'Nenhum registro encontrado',
                                                    'Experimente outro período ou filtro.',
                                                  )
                                                else
                                                  for (final item in data.items)
                                                    _record(item),
                                                if (_view == 'overview' &&
                                                    data.total >
                                                        data.items.length)
                                                  TextButton(
                                                    onPressed: () =>
                                                        _selectTab(1),
                                                    child: const Text(
                                                      'Ver histórico completo',
                                                    ),
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (data != null && _view != 'overview')
                                          _pagination(data),
                                      ],
                                    );
                                    return _panel(records);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          body: SafeArea(child: content),
        );
      },
    );
  }

  String get _operationRoute => widget.smd
      ? '/smd/apontar'
      : widget.production
      ? '/producao/operacao'
      : widget.support
      ? '/suporte/operacao'
      : widget.expedition
      ? '/expedicao/operacao'
      : '/almoxarifado/materiais';

  void _openReport() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WarehouseReportPage(
        sector: _reportSector,
        initialFilters: ReportFilters(
          analysis: widget.production
              ? (_kind == 'consumption'
                    ? 'consumption'
                    : !_isHistory
                    ? 'local_stages'
                    : _kind == 'production'
                    ? 'output'
                    : 'movements')
              : 'movements',
          warehouses: widget.support || widget.administrative
              ? [_local]
              : const [],
          start: _start,
          end: _end,
          query: _search.text.trim(),
          kinds: _isHistory && reportKinds.containsKey(_kind)
              ? [_kind]
              : _fiscalNotes
              ? const ['receipt', 'dispatch']
              : widget.smd && !_isHistory
              ? const ['production']
              : const [],
          status: _isHistory && reportStatuses.containsKey(_status)
              ? _status
              : 'all',
        ),
      ),
    ),
  );

  void _showActions() {
    void open(String route) {
      Navigator.pop(context);
      Navigator.pushNamed(context, route);
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Text(
                'Opções · $_title',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.summarize_outlined),
                title: const Text('Relatórios'),
                onTap: () {
                  Navigator.pop(context);
                  _openReport();
                },
              ),
              if (!widget.administrative)
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Materiais do setor'),
                  onTap: () => open('${_reportSector.homeRoute}/materiais'),
                ),
              if (!widget.administrative &&
                  !_sectorProduction &&
                  !_hasFiscalTabs)
                ListTile(
                  leading: const Icon(Icons.playlist_add_check),
                  title: const Text('Liberação de OPs'),
                  onTap: () => open('/almoxarifado/operacao'),
                ),
              if (widget.sectorAction != null) widget.sectorAction!,
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(Widget child) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(18),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget _filters() => LayoutBuilder(
    builder: (context, size) {
      final width = size.maxWidth < 600 ? size.maxWidth : 270.0;
      return Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (widget.administrative || widget.support)
            SizedBox(
              width: width,
              child: DropdownButtonFormField<String>(
                key: const ValueKey('warehouse-selector'),
                initialValue: _local,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Armazém',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  if (widget.support) ...[
                    const DropdownMenuItem(
                      value: '06',
                      child: Text('06 · Assistência técnica'),
                    ),
                    const DropdownMenuItem(
                      value: '07',
                      child: Text('07 · Suporte externo'),
                    ),
                  ],
                  if (!widget.support)
                    for (final target in WarehouseRouting.operational)
                      DropdownMenuItem(
                        value: target.code,
                        child: Text(
                          '${target.code} · ${target.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _local = value;
                    _reload();
                  }
                },
              ),
            ),
          SizedBox(
            width: width,
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: 'Buscar produto, OP ou documento',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          _search.clear();
                          _reload();
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _reload);
              },
              onSubmitted: (_) => _reload(),
            ),
          ),
          if (_view != 'stock')
            SizedBox(
              width: width,
              child: ReadPeriodFilter(
                start: _start,
                end: _end,
                dateLabel: _view == 'orders'
                    ? 'Emissão da OP'
                    : _view == 'inventory'
                    ? 'Data da contagem'
                    : 'Data do movimento',
                onChanged: (range) {
                  _start = range?.start;
                  _end = range?.end;
                  _reload();
                },
              ),
            ),
          if (_isHistory && (!_sectorProduction || _tab == 3))
            SizedBox(
              width: width,
              child: DropdownButtonFormField<String>(
                key: ValueKey('kind-$_tab'),
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Movimento',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  if (_fiscalNotes)
                    const DropdownMenuItem(
                      value: 'fiscal',
                      child: Text('Todas as notas'),
                    ),
                  for (final kind in _kinds.entries)
                    if (!_fiscalNotes ||
                        kind.key == 'receipt' ||
                        kind.key == 'dispatch')
                      DropdownMenuItem(
                        value: kind.key,
                        child: Text(kind.value),
                      ),
                ],
                onChanged: (value) {
                  _kind = value ?? 'all';
                  _reload();
                },
              ),
            ),
          if (['history', 'stock', 'orders'].contains(_view))
            SizedBox(
              width: width,
              child: DropdownButtonFormField<String>(
                key: ValueKey('status-$_tab'),
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Situação',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('Todas')),
                  if (_view == 'history') ...[
                    const DropdownMenuItem(
                      value: 'active',
                      child: Text('Sem marca de estorno'),
                    ),
                    const DropdownMenuItem(
                      value: 'reversed',
                      child: Text('Marcados como estornados'),
                    ),
                  ],
                  if (_view == 'stock')
                    const DropdownMenuItem(
                      value: 'nonzero',
                      child: Text('Com saldo'),
                    ),
                  if (_view == 'orders') ...[
                    const DropdownMenuItem(
                      value: 'active',
                      child: Text('Em aberto'),
                    ),
                    const DropdownMenuItem(
                      value: 'closed',
                      child: Text('Encerradas'),
                    ),
                  ],
                ],
                onChanged: (value) {
                  _status = value ?? 'all';
                  _reload();
                },
              ),
            ),
        ],
      );
    },
  );

  Widget _timestamp(WarehouseReadSnapshot data) {
    final time = data.asOf;
    return Text(
      [
        '${data.total} registros',
        if (data.database.isNotEmpty) data.database,
        if (time != null)
          'Consultado às ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        if (data.databaseLatestRecord.isNotEmpty)
          'Último registro no DEV: ${_rawDate(data.databaseLatestRecord)}',
      ].join(' · '),
      style: const TextStyle(fontSize: 12, color: AppColors.muted),
    );
  }

  Widget _summary(WarehouseReadSnapshot data) {
    int count(String flow) => data.summary
        .where((r) => r['flow'] == flow && r['reversed'] != 1)
        .fold(0, (sum, r) => sum + (r['count'] as num).toInt());
    final reversed = data.summary
        .where((r) => r['reversed'] == 1)
        .fold<int>(0, (sum, r) => sum + (r['count'] as num).toInt());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 600
                ? (constraints.maxWidth - 12) / 2
                : (constraints.maxWidth - 36) / 4;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(
                  'Entradas',
                  count('in'),
                  Icons.south_west,
                  AppColors.green,
                  width,
                ),
                _metric(
                  'Saídas',
                  count('out'),
                  Icons.north_east,
                  AppColors.orange,
                  width,
                ),
                _metric(
                  'Sem efeito no estoque',
                  count('none'),
                  Icons.receipt_long_outlined,
                  AppColors.muted,
                  width,
                ),
                _metric(
                  'Marcados como estornados',
                  reversed,
                  Icons.undo,
                  AppColors.danger,
                  width,
                ),
              ],
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Contagem de registros, não de peças. Notas: efeito conforme a TES atual.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        if (count('unknown') > 0)
          Text(
            '${count('unknown')} registros com efeito a conferir.',
            style: const TextStyle(color: AppColors.orange),
          ),
      ],
    );
  }

  Widget _metric(
    String label,
    int value,
    IconData icon,
    Color color,
    double width,
  ) => Container(
    width: width,
    constraints: const BoxConstraints(minHeight: 116),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _record(Map<String, dynamic> row) {
    final code = _text(row, 'code');
    final isHistory = _isHistory;
    final title = _view == 'orders' ? _text(row, 'op') : code;
    final flow = _text(row, 'flow');
    final color = row['reversed'] == 1
        ? AppColors.danger
        : flow == 'in'
        ? AppColors.green
        : flow == 'out'
        ? AppColors.orange
        : AppColors.primary;
    final chips = <String>[
      if (isHistory && widget.production)
        WarehouseRouting.labelForWarehouse(_text(row, 'warehouse')),
      if (isHistory) _kindLabel(row),
      if (isHistory) _flowLabel(row),
      if (row['reversed'] == 1) 'Estornado',
      if (_view == 'orders') row['closed'] == 1 ? 'Encerrada' : 'Em aberto',
      if (_text(row, 'otherWarehouse').isNotEmpty)
        flow == 'out'
            ? '${_text(row, 'warehouse')} → ${_text(row, 'otherWarehouse')}'
            : '${_text(row, 'otherWarehouse')} → ${_text(row, 'warehouse')}',
      if (_text(row, 'otherCode').isNotEmpty && row['otherCode'] != row['code'])
        'Troca de produto',
      if (_text(row, 'materialType') == 'MO' || code.startsWith('MOD'))
        'Mão de obra',
    ];
    return Card(
      margin: const EdgeInsets.only(top: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _details(row),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${_view == 'orders' ? '$code · ' : ''}${_text(row, 'description')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      '${warehouseNumber(row['quantity'])} ${_text(row, 'unit')}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.iconMuted,
                    size: 18,
                  ),
                ],
              ),
              if (chips.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final label in chips)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgHeader,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              if (_view == 'stock')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Empenhado: ${warehouseNumber(row['committed'])} · Reservado: ${warehouseNumber(row['reserved'])} · A classificar: ${warehouseNumber(row['awaitingClassification'])}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              if (_view == 'orders')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Produzido: ${warehouseNumber(row['produced'])} ${_text(row, 'unit')} · Restante: ${warehouseNumber(_remaining(row))} ${_text(row, 'unit')} · Emissão: ${_rawDate(_text(row, 'date'))}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              if (isHistory || _view == 'inventory')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    [
                      _rawDate(_text(row, 'date')),
                      if (_text(row, 'op').isNotEmpty) 'OP ${_text(row, 'op')}',
                      if (_text(row, 'document').isNotEmpty)
                        'Doc. ${_text(row, 'document')}',
                      if (_text(row, 'operator').isNotEmpty)
                        'Usuário: ${_text(row, 'operator')}',
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pagination(WarehouseReadSnapshot data) {
    final pages = (data.total / _pageSize).ceil().clamp(1, 100000);
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Página $_page de $pages · ${data.total} registros',
            style: const TextStyle(fontSize: 12),
          ),
          DropdownButton<int>(
            key: const ValueKey('page-size'),
            value: _pageSize,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 12, color: AppColors.text),
            items: [
              for (final size in [20, 50, 100])
                DropdownMenuItem(value: size, child: Text('$size por página')),
            ],
            onChanged: (value) {
              if (value != null) {
                _pageSize = value;
                _reload();
              }
            },
          ),
          IconButton(
            tooltip: 'Página anterior',
            onPressed: _page > 1
                ? () {
                    _page--;
                    _reload(resetPage: false);
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Próxima página',
            onPressed: _page < pages
                ? () {
                    _page++;
                    _reload(resetPage: false);
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _details(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (_) => _RecordDetails(
        row: row,
        view: _view,
        dispatchFuture: widget.expedition && row['source'] == 'SD2'
            ? _repo?.dispatchNoteDetails(_text(row, 'id'))
            : null,
        orderFuture: _view == 'orders'
            ? _repo?.orderDetails(_text(row, 'op'))
            : null,
        relatedFuture:
            _text(row, 'id').startsWith('SD3:') &&
                ['transfer', 'dismantling'].contains(row['kind'])
            ? _repo?.relatedMovements(_text(row, 'id'))
            : null,
      ),
    );
  }
}

num? _remaining(Map<String, dynamic> row) {
  final quantity = row['quantity'];
  final produced = row['produced'];
  if (quantity is! num || produced is! num) return null;
  return (quantity - produced).clamp(0, double.infinity);
}

class _RecordDetails extends StatelessWidget {
  const _RecordDetails({
    required this.row,
    required this.view,
    this.orderFuture,
    this.relatedFuture,
    this.dispatchFuture,
  });
  final Map<String, dynamic> row;
  final String view;
  final Future<Map<String, dynamic>>? orderFuture;
  final Future<Map<String, dynamic>>? relatedFuture;
  final Future<Map<String, dynamic>>? dispatchFuture;

  @override
  Widget build(BuildContext context) {
    final fields = <String, String>{
      'Produto': '${_text(row, 'code')} · ${_text(row, 'description')}',
      'Quantidade': '${warehouseNumber(row['quantity'])} ${_text(row, 'unit')}',
      'Armazém': WarehouseRouting.labelForWarehouse(_text(row, 'warehouse')),
      if (_text(row, 'kind').isNotEmpty) 'Movimento': _kindLabel(row),
      if (_text(row, 'flow').isNotEmpty) 'Efeito': _flowLabel(row),
      if (row['reversed'] == 1) 'Situação': 'Estornado',
      if (_text(row, 'otherWarehouse').isNotEmpty)
        'Outro armazém': WarehouseRouting.labelForWarehouse(
          _text(row, 'otherWarehouse'),
        ),
      if (_text(row, 'otherCode').isNotEmpty)
        'Produto do outro lado':
            '${_text(row, 'otherCode')} · ${warehouseNumber(row['otherQuantity'])} ${_text(row, 'otherUnit')}',
      'Data': _rawDate(_text(row, 'date')),
      'Documento': _text(row, 'document'),
      'Série da nota': _text(row, 'series'),
      'OP': _text(row, 'op'),
      'Usuário do movimento': _text(row, 'operator'),
      'Motivo / operação':
          '${_text(row, 'reason')} ${_text(row, 'reasonDescription')}'.trim(),
      'Contraparte / loja':
          '${_text(row, 'partner')} ${_text(row, 'partnerStore')}'.trim(),
      'Lote': _text(row, 'lot'),
      'Número de série': _text(row, 'serial'),
      'Endereço': _text(row, 'address'),
      if (view == 'stock') ...{
        'Empenhado': warehouseNumber(row['committed']),
        'Reservado': warehouseNumber(row['reserved']),
        'A classificar': warehouseNumber(row['awaitingClassification']),
        'Custo médio (moeda 1)': warehouseNumber(row['averageCost']),
        'Valor do saldo (moeda 1)': warehouseNumber(row['stockValue']),
      },
      if (view == 'orders') ...{
        'Produzido': warehouseNumber(row['produced']),
        'Restante': warehouseNumber(_remaining(row)),
        'Situação': row['closed'] == 1 ? 'Encerrada' : 'Em aberto',
        'Entrega prevista': _rawDate(_text(row, 'dueDate')),
        'Encerramento': _rawDate(_text(row, 'closedDate')),
        'Armazém de terceiro': _text(row, 'thirdPartyWarehouse'),
        'Envio ao terceiro': _text(row, 'sentToThirdParty'),
        'Retorno do terceiro': _text(row, 'returnedFromThirdParty'),
      },
      if (view == 'inventory') ...{
        'Contagem': _text(row, 'counting'),
        'Status cadastrado': _text(row, 'inventoryStatus'),
      },
      if (row['kind'] == 'dismantling')
        'Rateio': '${warehouseNumber(row['allocation'])}%',
      'Observação': _text(row, 'observation'),
    }..removeWhere((key, value) => value.trim().isEmpty);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Detalhes do registro',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar detalhes',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final field in fields.entries)
                      _field(field.key, field.value),
                    if (row['kind'] == 'transfer' && row['peerCount'] != 1)
                      const _Notice(
                        'Contraparte a conferir',
                        'Não foi possível identificar um único movimento correspondente.',
                      ),
                    if (row['source'] == 'SD1' || row['source'] == 'SD2')
                      const Text(
                        'Efeito no estoque conforme o cadastro atual da TES. Para notas de entrada, o período considera a data de digitação.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    if (dispatchFuture != null) _dispatchDetails(),
                    if (_text(row, 'materialType') == 'MO' ||
                        _text(row, 'code').startsWith('MOD'))
                      const Text(
                        'Registro de mão de obra. Não representa uma peça física.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Referências do Protheus'),
                      children: [
                        for (final field in {
                          'Origem': _text(row, 'source'),
                          'Registro': _text(row, 'id'),
                          'Sequência': _text(row, 'sequence'),
                          'CF / TM':
                              '${_text(row, 'cf')} / ${_text(row, 'tm')}',
                          'TES': _text(row, 'tes'),
                          'CFOP': _text(row, 'cfop'),
                        }.entries)
                          if (field.value.isNotEmpty)
                            _field(field.key, field.value),
                      ],
                    ),
                    if (relatedFuture != null)
                      FutureBuilder<Map<String, dynamic>>(
                        future: relatedFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text(
                              'Não foi possível carregar os registros relacionados.',
                              style: TextStyle(color: AppColors.danger),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const LinearProgressIndicator();
                          }
                          final items = snapshot.data!['items'] as List? ?? [];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Registros relacionados',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (items.isEmpty)
                                const Text(
                                  'Nenhum registro relacionado encontrado.',
                                ),
                              for (final item in items)
                                _field(
                                  '${item['code']} · Armazém ${item['warehouse']}',
                                  '${warehouseNumber(item['quantity'])} ${item['unit'] ?? ''} · ${item['cf'] ?? ''}'
                                      '${item['cf'] == 'DE7' ? ' · Rateio: ${warehouseNumber(item['allocation'])}%' : ''}',
                                ),
                            ],
                          );
                        },
                      ),
                    if (orderFuture != null)
                      FutureBuilder<Map<String, dynamic>>(
                        future: orderFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text(
                              'Não foi possível carregar os empenhos e movimentos.',
                              style: TextStyle(color: AppColors.danger),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const LinearProgressIndicator();
                          }
                          final commitments =
                              snapshot.data!['empenhos'] as List? ?? [];
                          final movements =
                              snapshot.data!['movimentos'] as List? ?? [];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),
                              const Text(
                                'Empenhos',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (commitments.isEmpty)
                                const Text('Nenhum empenho encontrado.'),
                              for (final value in commitments)
                                _field(
                                  '${value['produto']} · Armazém ${value['local']}',
                                  'Previsto: ${warehouseNumber(value['quantidadeOriginal'])} · Restante: ${warehouseNumber(value['quantidadeRestante'])}',
                                ),
                              const SizedBox(height: 16),
                              const Text(
                                'Movimentos da OP',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (movements.isEmpty)
                                const Text('Nenhum movimento encontrado.'),
                              for (final value in movements)
                                _field(
                                  '${value['produto']} · ${value['cf']}/${value['tm']}',
                                  '${warehouseNumber(value['quantidade'])} · Armazém ${value['local']} · Doc. ${value['documento']}',
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copiar detalhes'),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: fields.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('\n'),
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Detalhes copiados.')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dispatchDetails() => FutureBuilder<Map<String, dynamic>>(
    future: dispatchFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text('Não foi possível carregar os dados de transporte.');
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final data = snapshot.data!;
      final item = Map<String, dynamic>.from(data['item'] as Map? ?? {});
      final header = Map<String, dynamic>.from(data['document'] as Map? ?? {});
      String value(String key) =>
          _text(header, key).isEmpty ? 'Não informado' : _text(header, key);
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pedido e transporte',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _field(
              'Pedido do item',
              _text(item, 'salesOrder').isEmpty
                  ? 'Não informado'
                  : _text(item, 'salesOrder'),
            ),
            if (_text(item, 'salesOrderItem').isNotEmpty)
              _field('Item do pedido', _text(item, 'salesOrderItem')),
            if (data['headerStatus'] != 'found')
              Text(
                data['headerStatus'] == 'ambiguous'
                    ? 'Mais de um cabeçalho fiscal encontrado. Confira no Protheus.'
                    : 'Cabeçalho fiscal não localizado no DEV.',
              )
            else ...[
              if (_text(header, 'partnerName').isNotEmpty)
                _field('Nome no documento', _text(header, 'partnerName')),
              _field(
                'Transportadora',
                [
                  if (_text(header, 'carrier').isNotEmpty)
                    _text(header, 'carrier'),
                  value('carrierName'),
                ].join(' · '),
              ),
              _field('Rastreio', value('trackingCode')),
              _field('Tipo de rastreio', value('trackingType')),
              _field('Registro do rastreio', value('trackingLog')),
              for (var i = 1; i <= 4; i++)
                if ((header['volume$i'] as num? ?? 0) != 0 ||
                    _text(header, 'packaging$i').isNotEmpty)
                  _field(
                    'Volumes da nota / espécie $i',
                    '${warehouseNumber(header['volume$i'])} · ${_text(header, 'packaging$i')}',
                  ),
              const Text(
                'Dados registrados na nota. Rastreio não comprova coleta ou entrega.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        SelectableText(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.title, this.detail, {this.action});
  final String title;
  final String detail;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        const Icon(Icons.inbox_outlined, size: 36, color: AppColors.iconMuted),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        ?action,
      ],
    ),
  );
}

String _text(Map<String, dynamic> row, String key) =>
    '${row[key] ?? ''}'.trim();

String _rawDate(String value) {
  if (RegExp(r'^\d{8}$').hasMatch(value)) {
    return '${value.substring(6, 8)}/${value.substring(4, 6)}/${value.substring(0, 4)}';
  }
  return value;
}

String warehouseNumber(dynamic value) {
  final number = value is num ? value : num.tryParse('$value');
  if (number == null) return '—';
  return number
      .toStringAsFixed(6)
      .replaceFirst(RegExp(r'\.?0+$'), '')
      .replaceAll('.', ',');
}

String _kindLabel(Map<String, dynamic> row) => switch (row['cf']) {
  'RE4' || 'DE4' => 'Transferência',
  'PR0' => 'Produção',
  'ER0' => 'Estorno de produção',
  'RE1' => 'Consumo de OP',
  'DE1' => 'Devolução de componente',
  'RE7' => 'Saída para desmontagem',
  'DE7' => 'Retorno da desmontagem',
  'RE0' || 'DE0' => 'Ajuste de estoque',
  _ => _kinds[row['kind']] ?? 'Movimento',
};
String _flowLabel(Map<String, dynamic> row) => switch (row['flow']) {
  'in' => 'Entrada',
  'out' => 'Saída',
  'none' => 'Sem efeito no estoque',
  _ => 'Efeito a conferir',
};
