import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_materials_page.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart'
    show reportNumber;
import 'package:vetti_flow_1_0/data/models/warehouse_request.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/read_period_filter.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

class SmdWorkPage extends StatefulWidget {
  const SmdWorkPage({super.key});
  @override
  State<SmdWorkPage> createState() => _SmdWorkPageState();
}

class _SmdWorkPageState extends State<SmdWorkPage> {
  String _view = 'queue';
  String _query = '';
  DateTimeRange? _period;
  int _page = 0;
  bool _busy = false;

  bool _matchesOrder(ProductionOrderFlow order) =>
      '${order.number} ${order.productCode} ${order.productName}'
          .toLowerCase()
          .contains(_query.trim().toLowerCase());
  bool _matchesDate(DateTime date) {
    final range = _period;
    return range == null ||
        (!date.isBefore(range.start) &&
            date.isBefore(
              DateTime(range.end.year, range.end.month, range.end.day + 1),
            ));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProductionFlowStore>();
    final operator = context.watch<OperatorAssignmentStore>().currentOperator;
    final materials = context.watch<WarehouseRequestStore>().requests;
    final allowed = operator != null && operator.canUseSector(AppSector.smd);
    final rows = <(ProductionOrderFlow, SmdPointing?)>[];
    for (final order in store.orders.where(_matchesOrder)) {
      if (_view == 'history') {
        for (final entry in order.smd.entries.where(
          (e) => _matchesDate(e.at),
        )) {
          rows.add((order, entry));
        }
      } else if (_matchesDate(order.createdAt)) {
        final smdIndex = order.plannedStages.indexOf(ProductionStage.smd);
        final currentIndex = order.plannedStages.indexOf(order.currentStage);
        if (_view == 'queue' &&
            order.currentStage == ProductionStage.smd &&
            order.smd.completedAt == null) {
          rows.add((order, null));
        } else if (_view == 'scheduled' &&
            !order.isDone &&
            order.smd.completedAt == null &&
            currentIndex >= 0 &&
            smdIndex > currentIndex) {
          rows.add((order, null));
        }
      }
    }
    rows.sort(
      (a, b) =>
          (b.$2?.at ?? b.$1.createdAt).compareTo(a.$2?.at ?? a.$1.createdAt),
    );
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
                title: 'SMD',
                operatorName: operator?.name ?? 'Consulta',
                operatorRole: 'Apontamentos do VettiFlow',
                compact: compact,
              ),
              Expanded(
                child: !allowed
                    ? const Center(
                        child: Text('Entre com uma conta do SMD ou de gestão.'),
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
                                      tooltip: 'Voltar ao SMD',
                                      icon: const Icon(Icons.arrow_back),
                                      onPressed: () => Navigator.canPop(context)
                                          ? Navigator.pop(context)
                                          : Navigator.pushReplacementNamed(
                                              context,
                                              operator.canView(AppSector.smd)
                                                  ? '/smd'
                                                  : operator.homeRoute,
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Apontamentos do SMD',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.title,
                                        ),
                                      ),
                                    ),
                                    const MaterialsNavigationButton(
                                      sector: 'smd',
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'OPs do VettiFlow · Registros locais neste navegador. Não geram baixa no Protheus.',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final entry in const {
                                      'queue': 'Em SMD',
                                      'scheduled': 'Programadas',
                                      'history': 'Histórico',
                                    }.entries)
                                      ChoiceChip(
                                        label: Text(entry.value),
                                        selected: _view == entry.key,
                                        onSelected: (_) => setState(() {
                                          _view = entry.key;
                                          _page = 0;
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
                                  '${rows.length} ${_view == 'history' ? 'registros' : 'OPs'}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: visible.isEmpty
                                      ? Center(
                                          child: Text(
                                            _view == 'history'
                                                ? 'Nenhum apontamento neste período.'
                                                : _view == 'scheduled'
                                                ? 'Nenhuma OP com SMD previsto nas próximas etapas.'
                                                : 'Nenhuma OP nesta fila.\nAs OPs aparecem quando chegam à etapa SMD da rota escolhida.',
                                            textAlign: TextAlign.center,
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: visible.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            final (order, entry) =
                                                visible[index];
                                            return _card(
                                              order,
                                              entry,
                                              operator,
                                              store,
                                              materials
                                                  .where(
                                                    (r) =>
                                                        r.orderNumber ==
                                                            order.number &&
                                                        r.requestedWarehouse ==
                                                            '01',
                                                  )
                                                  .toList(),
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
                                    Text('${page + 1} de $pages'),
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
    final search = TextField(
      decoration: const InputDecoration(
        labelText: 'OP ou produto',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (value) => setState(() {
        _query = value;
        _page = 0;
      }),
    );
    final period = ReadPeriodFilter(
      start: _period?.start,
      end: _period?.end,
      dateLabel: _view == 'history'
          ? 'Data do apontamento / correção'
          : 'Data de criação da OP',
      onChanged: (value) => setState(() {
        _period = value;
        _page = 0;
      }),
    );
    return compact
        ? Column(children: [search, const SizedBox(height: 8), period])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: search),
              const SizedBox(width: 16),
              SizedBox(width: 300, child: period),
            ],
          );
  }

  Widget _card(
    ProductionOrderFlow order,
    SmdPointing? entry,
    Operator operator,
    ProductionFlowStore store,
    List<WarehouseConfirmationRequest> materials,
  ) {
    final canPoint =
        store.canPointSmd(operator) &&
        order.currentStage == ProductionStage.smd &&
        order.smd.completedAt == null;
    final remaining = order.smd.remaining(order.quantity);
    final unit = order.unit.isEmpty ? '(unidade não informada)' : order.unit;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            order.number,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            order.productLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (entry == null) ...[
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                Text('Planejado: ${reportNumber(order.quantity)} $unit'),
                Text('Apontado: ${reportNumber(order.smd.produced)} $unit'),
                Text(
                  'Restante: ${reportNumber(remaining)} $unit',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              order.currentStage == ProductionStage.smd
                  ? 'Após o SMD: ${order.nextStageLabel}'
                  : 'Etapa atual: ${order.currentStage.label}',
              style: const TextStyle(color: AppColors.muted),
            ),
            if (materials.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Materiais do almoxarifado · ${materials.where((r) => r.isDelivered).length}/${materials.length} itens entregues',
                ),
                children: [
                  for (final request in materials)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${request.componentCode} · ${request.progressLabel}',
                      ),
                      subtitle: Text(
                        'Entrega registrada: ${reportNumber(request.deliveredQuantity)} de ${reportNumber(request.quantity)} ${request.unit}\nDestino: ${request.orderWarehouseLabel}',
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            if (canPoint)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (remaining > 1e-8)
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _point(order, operator),
                      icon: const Icon(Icons.add_task, size: 18),
                      label: const Text('Apontar produção'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _complete(order, operator),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Concluir SMD'),
                    ),
                ],
              ),
          ] else ...[
            Text(
              '${entry.isReversal
                  ? 'Correção'
                  : order.smd.isReversed(entry.id)
                  ? 'Apontamento anulado'
                  : 'Produção apontada'} · ${entry.isReversal ? '−' : ''}${reportNumber(entry.quantity)} $unit',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${_date(entry.at)} · ${entry.operatorName}',
              style: const TextStyle(color: AppColors.muted),
            ),
            if (entry.note.isNotEmpty) Text(entry.note),
            if (order.smd.completedAt != null)
              Text(
                'SMD concluído em ${_date(order.smd.completedAt!)} por ${order.smd.completedBy}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            if (canPoint &&
                !entry.isReversal &&
                !order.smd.isReversed(entry.id))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _point(order, operator, correction: entry),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Anular apontamento'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : 'Não foi possível salvar o apontamento. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _point(
    ProductionOrderFlow order,
    Operator operator, {
    SmdPointing? correction,
  }) async {
    final result = await showDialog<_EntryDraft>(
      context: context,
      builder: (_) => _PointingDialog(order: order, correction: correction),
    );
    if (result == null || !mounted) return;
    final store = context.read<ProductionFlowStore>();
    await _run(
      () => correction == null
          ? store.pointSmd(
              order.number,
              operator: operator,
              entryId: result.id,
              quantity: result.quantity,
              note: result.note,
            )
          : store.reverseSmdPointing(
              order.number,
              operator: operator,
              pointingId: correction.id,
              reason: result.note,
            ),
      correction == null
          ? 'Apontamento salvo no VettiFlow.'
          : 'Correção registrada no histórico.',
    );
  }

  Future<void> _complete(ProductionOrderFlow order, Operator operator) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Concluir SMD?'),
        content: Text(
          '${order.number}\nQuantidade apontada: ${reportNumber(order.smd.produced)} ${order.unit}\nPróxima etapa: ${order.nextStageLabel}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => context.read<ProductionFlowStore>().completeSmd(
        order.number,
        operator: operator,
      ),
      'SMD concluído no VettiFlow.',
    );
  }
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class _EntryDraft {
  const _EntryDraft(this.id, this.quantity, this.note);
  final String id;
  final num quantity;
  final String note;
}

class _PointingDialog extends StatefulWidget {
  const _PointingDialog({required this.order, this.correction});
  final ProductionOrderFlow order;
  final SmdPointing? correction;
  @override
  State<_PointingDialog> createState() => _PointingDialogState();
}

class _PointingDialogState extends State<_PointingDialog> {
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  final _form = GlobalKey<FormState>();
  late final _id =
      'smd:${widget.order.number}:${DateTime.now().microsecondsSinceEpoch}';
  num? get value => num.tryParse(_quantity.text.trim().replaceAll(',', '.'));
  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correcting = widget.correction != null;
    final remaining = widget.order.smd.remaining(widget.order.quantity);
    return AlertDialog(
      title: Text(correcting ? 'Anular apontamento' : 'Apontar produção'),
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
                const SizedBox(height: 16),
                if (correcting)
                  Text(
                    'Quantidade a anular: ${reportNumber(widget.correction!.quantity)} ${widget.order.unit}\nO registro original será mantido no histórico.',
                  )
                else
                  TextFormField(
                    controller: _quantity,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Quantidade produzida agora',
                      helperText:
                          'Restante: ${reportNumber(remaining)} ${widget.order.unit}',
                    ),
                    validator: (_) =>
                        value == null ||
                            !value!.isFinite ||
                            value! <= 0 ||
                            value! > remaining + remaining.abs() * 1e-10
                        ? 'Informe uma quantidade válida até ${reportNumber(remaining)}.'
                        : null,
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  maxLength: 300,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: correcting
                        ? 'Motivo da correção'
                        : 'Observação (opcional)',
                  ),
                  validator: (text) =>
                      correcting && (text?.trim().isEmpty ?? true)
                      ? 'Informe o motivo.'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(
                context,
                _EntryDraft(_id, value ?? 0, _note.text.trim()),
              );
            }
          },
          child: Text(correcting ? 'Anular' : 'Registrar'),
        ),
      ],
    );
  }
}
