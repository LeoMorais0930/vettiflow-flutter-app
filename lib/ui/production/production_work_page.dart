import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:flutter/material.dart';
import 'dispatch_lifecycle_card.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_materials_page.dart';
import 'package:vetti_flow_1_0/ui/warehouse/request_material_dialog.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart'
    show reportNumber;
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/read_period_filter.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

/// Operação local com envios, recebimentos e retornos por quantidade.
class ProductionWorkPage extends StatefulWidget {
  const ProductionWorkPage({super.key, this.destinationSector});
  final String? destinationSector;
  @override
  State<ProductionWorkPage> createState() => _ProductionWorkPageState();
}

class _ProductionWorkPageState extends State<ProductionWorkPage> {
  String _view = 'queue';
  String _query = '';
  ProductionStage? _stage;
  DateTimeRange? _period;
  int _page = 0;
  bool _busy = false;
  bool get _incoming => widget.destinationSector != null;
  bool get _draftView => _incoming || _view == 'drafts';
  String get _title => switch (widget.destinationSector) {
    'support' => 'Operação do suporte',
    'expedition' => 'Operação da expedição',
    _ => 'Operação da produção',
  };
  String get _backRoute => switch (widget.destinationSector) {
    'support' => '/suporte',
    'expedition' => '/expedicao',
    _ => '/producao',
  };
  bool _matchesDate(DateTime date) =>
      _period == null ||
      !date.isBefore(_period!.start) &&
          date.isBefore(
            DateTime(
              _period!.end.year,
              _period!.end.month,
              _period!.end.day + 1,
            ),
          );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProductionFlowStore>();
    final operator = context.watch<OperatorAssignmentStore>().currentOperator;
    final allowed =
        operator != null &&
        operator.canUseSector(switch (widget.destinationSector) {
              'support' => AppSector.support,
              'expedition' => AppSector.expedition,
              _ => AppSector.production,
            }) ==
            true;
    final rows = <(ProductionOrderFlow, ProductionDispatchDraft?)>[];
    final now = DateTime.now();
    for (final order in store.orders) {
      if (!order.belongsToProduction ||
          !'${order.number} ${order.productLabel}'.toLowerCase().contains(
            _query.trim().toLowerCase(),
          )) {
        continue;
      }
      if (_draftView) {
        for (final draft in order.dispatchDrafts) {
          if (!_matchesDate(draft.lastActivity)) continue;
          if (widget.destinationSector == 'support' &&
              !['06', '07'].contains(draft.destination)) {
            continue;
          }
          if (widget.destinationSector == 'expedition' &&
              draft.destination != '10' &&
              draft.total(DispatchAction.sendToExpedition) == 0) {
            continue;
          }
          rows.add((order, draft));
        }
      } else {
        if (!_matchesDate(order.createdAt) ||
            _stage != null && order.currentStage != _stage) {
          continue;
        }
        final internal = ProductionOrderFlow.internalProductionStages.contains(
          order.currentStage,
        );
        final route = order.plannedStages.isEmpty
            ? ProductionStage.productionFlow
            : order.plannedStages;
        final index = route.indexOf(order.currentStage);
        final scheduled =
            !internal &&
            !order.isDone &&
            index >= 0 &&
            route
                .skip(index + 1)
                .any(ProductionOrderFlow.internalProductionStages.contains);
        if (_view == 'queue' && internal ||
            _view == 'scheduled' && scheduled ||
            _view == 'finished' &&
                !internal &&
                !scheduled &&
                (order.isDone ||
                    order.currentStage == ProductionStage.expedition)) {
          rows.add((order, null));
        }
      }
    }
    DateTime rowDate((ProductionOrderFlow, ProductionDispatchDraft?) r) =>
        r.$2?.lastActivity ?? r.$1.createdAt;
    rows.sort((a, b) => rowDate(b).compareTo(rowDate(a)));
    final pages = ((rows.length + 19) ~/ 20).clamp(1, 1000000);
    final page = _page.clamp(0, pages - 1);
    final visible = rows.skip(page * 20).take(20).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 920;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              VettiTopBar(
                title: _incoming
                    ? (widget.destinationSector == 'support'
                          ? 'Suporte'
                          : 'Expedição')
                    : 'Produção',
                operatorName: operator?.name ?? 'Consulta',
                operatorRole: 'Operação do VettiFlow',
                compact: compact,
              ),
              Expanded(
                child: !allowed
                    ? const Center(
                        child: Text(
                          'Entre com uma conta do setor ou de gestão.',
                        ),
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1480),
                          child: Padding(
                            padding: EdgeInsets.all(compact ? 12 : 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Voltar',
                                      icon: const Icon(Icons.arrow_back),
                                      onPressed: () => Navigator.canPop(context)
                                          ? Navigator.pop(context)
                                          : Navigator.pushReplacementNamed(
                                              context,
                                              operator.canAccessRoute(
                                                    _backRoute,
                                                  )
                                                  ? _backRoute
                                                  : operator.homeRoute,
                                            ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _title,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.title,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Atualizar tempos',
                                      onPressed: () => setState(() {}),
                                      icon: const Icon(Icons.refresh),
                                    ),
                                    MaterialsNavigationButton(
                                      sector:
                                          widget.destinationSector == 'support'
                                          ? 'suporte'
                                          : widget.destinationSector ==
                                                'expedition'
                                          ? 'expedicao'
                                          : 'producao',
                                    ),
                                    if (!_incoming &&
                                        operator.canView(AppSector.production))
                                      IconButton(
                                        tooltip: 'Relatórios de produção',
                                        onPressed: () => Navigator.pushNamed(
                                          context,
                                          '/producao/relatorios',
                                        ),
                                        icon: const Icon(Icons.bar_chart),
                                      ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'Operações deste navegador · Entregas e recebimentos são confirmados separadamente. Protheus somente leitura.',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (!_incoming)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final tab in const {
                                        'queue': 'Em produção',
                                        'scheduled': 'Programadas',
                                        'finished': 'Fim da produção',
                                        'drafts': 'Envios e retornos',
                                      }.entries)
                                        ChoiceChip(
                                          label: Text(tab.value),
                                          selected: _view == tab.key,
                                          onSelected: (_) => setState(() {
                                            _view = tab.key;
                                            _page = 0;
                                            _stage = null;
                                          }),
                                        ),
                                    ],
                                  ),
                                const SizedBox(height: 12),
                                if (compact)
                                  ExpansionTile(
                                    title: Text(
                                      'Filtros · ${readPeriodLabel(_period?.start, _period?.end)}',
                                    ),
                                    children: [_filters(true)],
                                  )
                                else
                                  _filters(false),
                                const SizedBox(height: 12),
                                Text(
                                  '${rows.length} ${_draftView ? 'envios' : 'OPs'} · Atualizado ${_clock(now)}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: visible.isEmpty
                                      ? Center(
                                          child: Text(
                                            _draftView
                                                ? 'Nenhum envio neste período.'
                                                : 'Nenhuma OP nesta fila.\nAs OPs seguem as etapas escolhidas na programação.',
                                            textAlign: TextAlign.center,
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: visible.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            final (order, draft) =
                                                visible[index];
                                            return _panel(
                                              draft == null
                                                  ? _orderCard(
                                                      order,
                                                      operator,
                                                      now,
                                                    )
                                                  : _draftCard(
                                                      order,
                                                      draft,
                                                      operator,
                                                    ),
                                            );
                                          },
                                        ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      tooltip: 'Página anterior',
                                      onPressed: page == 0
                                          ? null
                                          : () => setState(
                                              () => _page = page - 1,
                                            ),
                                      icon: const Icon(Icons.chevron_left),
                                    ),
                                    Text('${page + 1} / $pages'),
                                    IconButton(
                                      tooltip: 'Próxima página',
                                      onPressed: page + 1 >= pages
                                          ? null
                                          : () => setState(
                                              () => _page = page + 1,
                                            ),
                                      icon: const Icon(Icons.chevron_right),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filters(bool compact) {
    final fields = [
      SizedBox(
        width: compact ? double.infinity : 320,
        child: TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar OP ou produto',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() {
            _query = v;
            _page = 0;
          }),
        ),
      ),
      if (!_draftView)
        SizedBox(
          width: compact ? double.infinity : 230,
          child: DropdownButtonFormField<ProductionStage?>(
            isExpanded: true,
            key: ValueKey(_view),
            initialValue: _stage,
            decoration: const InputDecoration(labelText: 'Etapa atual'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Todas as etapas'),
              ),
              for (final s in ProductionStage.productionFlow)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (v) => setState(() {
              _stage = v;
              _page = 0;
            }),
          ),
        ),
      SizedBox(
        width: compact ? double.infinity : 310,
        child: ReadPeriodFilter(
          start: _period?.start,
          end: _period?.end,
          dateLabel: _draftView
              ? 'Última movimentação do envio'
              : 'Criação da OP',
          onChanged: (v) => setState(() {
            _period = v;
            _page = 0;
          }),
        ),
      ),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: fields,
    );
  }

  Widget _panel(Widget child) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );

  Widget _orderCard(
    ProductionOrderFlow order,
    Operator operator,
    DateTime now,
  ) {
    final store = context.read<ProductionFlowStore>();
    final route = order.plannedStages.isEmpty
        ? ProductionStage.productionFlow
        : order.plannedStages;
    final sessions = order.activeSessionsAt(order.currentStage);
    final names = sessions.map((s) => s.operatorName).toSet().join(', ');
    final internal = ProductionOrderFlow.internalProductionStages.contains(
      order.currentStage,
    );
    final canOperate =
        internal &&
        (operator.canManageAssignments &&
                (operator.area == WorkArea.production ||
                    operator.area == WorkArea.system) ||
            operator.area == WorkArea.production &&
                operator.stage.name == order.currentStage.name);
    final materials =
        context
            .watch<WarehouseRequestStore?>()
            ?.requests
            .where((r) => r.orderNumber == order.number)
            .toList() ??
        [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          order.number,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.title,
            fontSize: 18,
          ),
        ),
        Text(order.productLabel),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            Text('Lote planejado: ${order.quantityLabel}'),
            Text('Na produção: ${order.productionQuantityLabel}'),
            Text('Etapa: ${order.currentStage.label}'),
            Text(switch (order.status) {
              ProductionRunStatus.waiting => 'Aguardando',
              ProductionRunStatus.active => 'Em andamento',
              ProductionRunStatus.paused => 'Pausada',
              ProductionRunStatus.completed => 'Concluída',
            }),
          ],
        ),
        const SizedBox(height: 8),
        if (canOperate ||
            store.canPrepareProductionDispatch(operator) &&
                order.canPrepareDispatch)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (canOperate)
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Abrir etapa'),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      order.currentStage.route,
                      arguments: order.number,
                    ),
                  ),
                if (store.canPrepareProductionDispatch(operator) &&
                    order.canPrepareDispatch)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.outbox_outlined),
                    label: const Text('Preparar envio'),
                    onPressed: _busy ? null : () => _editDraft(order, operator),
                  ),
              ],
            ),
          ),
        if (store.canPrepareProductionDispatch(operator) &&
            order.orderWarehouse == '05' &&
            !order.isDone)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Solicitar material'),
              onPressed: () =>
                  requestOrderMaterial(context, order, operator, '05'),
            ),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Detalhes da OP'),
          children: [
            Text(
              'Sequência: ${route.map((s) => s.label).join(' → ')}',
              style: const TextStyle(color: AppColors.muted),
            ),
            Text(
              order.isDone
                  ? 'Sequência encerrada'
                  : 'Próxima: ${order.nextStageLabel}',
              style: const TextStyle(color: AppColors.muted),
            ),
            if (internal) ...[
              const SizedBox(height: 8),
              Text(
                'Operadores na etapa: ${names.isEmpty ? 'Nenhum registro ativo' : names}',
              ),
              Text(
                'Tempo ativo da etapa: ${formatProductionDuration(order.activeElapsed(now))}',
              ),
            ],
            if (order.orderWarehouse == '05')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Preparado: ${reportNumber(order.preparedQuantity)} ${order.unit} · Disponível para preparar: ${reportNumber(order.availableToPrepare)} ${order.unit}',
                ),
              ),

            if (materials.isNotEmpty) ...[
              for (final r in materials)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${r.componentCode} · ${r.requestedWarehouse} → ${r.orderWarehouse}',
                  ),
                  subtitle: Text(
                    'Entregue: ${reportNumber(r.deliveredQuantity)} / ${reportNumber(r.quantity)} ${r.unit}',
                  ),
                ),
            ] else
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Sem solicitações de material vinculadas.'),
              ),
            if (order.operatorSessions.isEmpty)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Sem tempos de operadores registrados.'),
              ),
            for (final session in order.operatorSessions)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${session.operatorName} · ${session.stage.label}'),
                subtitle: Text(
                  '${session.isCompleted
                      ? 'Encerrada'
                      : session.isRunning
                      ? 'Em andamento'
                      : 'Pausada'} · ${formatProductionDuration(session.elapsed(now))} · Qtde declarada: ${session.producedQuantity} ${order.unit}',
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _draftCard(
    ProductionOrderFlow order,
    ProductionDispatchDraft draft,
    Operator operator,
  ) => DispatchLifecycleCard(
    key: ValueKey('${order.number}:${draft.id}'),
    order: order,
    draft: draft,
    operator: operator,
    sector: widget.destinationSector ?? 'production',
  );

  Future<void> _editDraft(
    ProductionOrderFlow order,
    Operator operator, {
    ProductionDispatchDraft? cancel,
  }) async {
    final draft = await showDialog<_DispatchInput>(
      context: context,
      builder: (_) => _DispatchDialog(order: order, cancel: cancel),
    );
    if (draft == null || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final store = context.read<ProductionFlowStore>();
      if (cancel == null) {
        await store.prepareProductionDispatch(
          order.number,
          operator: operator,
          entryId: draft.id,
          destination: draft.destination,
          quantity: draft.quantity,
          reason: draft.reason,
        );
      } else {
        await store.cancelProductionDispatch(
          order.number,
          operator: operator,
          entryId: cancel.id,
          reason: draft.reason,
        );
      }
      if (!mounted) return;
      setState(() {
        _view = 'drafts';
        _period = null;
        _page = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cancel == null
                ? 'Preparo salvo. Entrega ainda pendente.'
                : 'Preparo cancelado. Histórico mantido.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : 'Não foi possível salvar. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

String _clock(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class _DispatchInput {
  const _DispatchInput(this.id, this.destination, this.quantity, this.reason);
  final String id, destination, reason;
  final num quantity;
}

class _DispatchDialog extends StatefulWidget {
  const _DispatchDialog({required this.order, this.cancel});
  final ProductionOrderFlow order;
  final ProductionDispatchDraft? cancel;
  @override
  State<_DispatchDialog> createState() => _DispatchDialogState();
}

class _DispatchDialogState extends State<_DispatchDialog> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  String? _destination;
  late final _id =
      'dispatch:${widget.order.number}:${DateTime.now().microsecondsSinceEpoch}';
  num? get value => num.tryParse(_quantity.text.trim().replaceAll(',', '.'));
  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.cancel == null ? 'Preparar envio' : 'Cancelar preparo'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${widget.order.number} · ${widget.order.productLabel}'),
              const SizedBox(height: 12),
              if (widget.cancel == null) ...[
                const Text(
                  'Reserva a quantidade para o destino. Depois registre a entrega; o destino confirma o recebimento.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _destination,
                  decoration: const InputDecoration(labelText: 'Destino'),
                  items: [
                    for (final entry
                        in ProductionDispatchDraft.destinations.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (v) => _destination = v,
                  validator: (v) => v == null ? 'Escolha o destino.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Quantidade',
                    helperText:
                        'Disponível: ${reportNumber(widget.order.availableToPrepare)} ${widget.order.unit}',
                  ),
                  validator: (_) =>
                      value == null ||
                          !value!.isFinite ||
                          value! <= 0 ||
                          value! > widget.order.availableToPrepare
                      ? 'Confira a quantidade disponível.'
                      : null,
                ),
                const SizedBox(height: 12),
              ] else
                Text(
                  '${widget.cancel!.destinationLabel} · ${reportNumber(widget.cancel!.quantity)} ${widget.order.unit}',
                ),
              TextFormField(
                controller: _reason,
                maxLength: 300,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: widget.cancel == null
                      ? 'Motivo do envio'
                      : 'Motivo do cancelamento',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe o motivo.' : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Voltar'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              _DispatchInput(
                _id,
                _destination ?? '',
                value ?? 0,
                _reason.text.trim(),
              ),
            );
          }
        },
        child: Text(
          widget.cancel == null ? 'Salvar preparo' : 'Cancelar preparo',
        ),
      ),
    ],
  );
}

class ProductionWorkButton extends StatelessWidget {
  const ProductionWorkButton({super.key, this.destinationSector});
  final String? destinationSector;
  @override
  Widget build(BuildContext context) {
    final operator = context.watch<OperatorAssignmentStore?>()?.currentOperator;
    if (operator == null) return const SizedBox.shrink();
    final route = switch (destinationSector) {
      'support' => '/suporte/operacao',
      'expedition' => '/expedicao/operacao',
      _ => '/producao/operacao',
    };
    final title = destinationSector == null
        ? 'Operação no VettiFlow'
        : 'Operação no VettiFlow';
    final icon = destinationSector == null
        ? Icons.precision_manufacturing_outlined
        : Icons.outbox_outlined;
    void open() => Navigator.pushNamed(context, route);
    if (MediaQuery.sizeOf(context).width < 920 || destinationSector != null) {
      return IconButton(tooltip: title, onPressed: open, icon: Icon(icon));
    }
    return TextButton.icon(
      onPressed: open,
      icon: Icon(icon),
      label: Text(title),
    );
  }
}
