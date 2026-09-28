import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/ui/warehouse/request_material_dialog.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart'
    show reportNumber;
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class DispatchLifecycleCard extends StatefulWidget {
  const DispatchLifecycleCard({
    super.key,
    required this.order,
    required this.draft,
    required this.operator,
    required this.sector,
  });
  final ProductionOrderFlow order;
  final ProductionDispatchDraft draft;
  final Operator operator;
  final String sector;
  @override
  State<DispatchLifecycleCard> createState() => _DispatchLifecycleCardState();
}

class _DispatchLifecycleCardState extends State<DispatchLifecycleCard> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final o = widget.order;
    final store = context.read<ProductionFlowStore>();
    final balances = <String, num>{
      'A entregar': d.pendingDelivery,
      'Em trânsito para ${d.destinationLabel}': d.initialTransit,
      'No suporte · a reparar': d.supportPending,
      'Reparado no suporte': d.supportRepaired,
      'Suporte → expedição': d.expeditionTransit,
      'Disponível na expedição': d.expeditionReady,
      'Armazenado': d.stored,
      'Despachado (líquido de retornos)': d.shipped,
      'Retorno de cliente a receber': d.customerReturnTransit,
      'Devolução à produção a receber': d.returnTransit,
      'Recebido de volta na produção': d.returned,
      'Cancelado': d.cancelledQuantity,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${o.number} · ${d.destinationLabel}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.title,
          ),
        ),
        Text(o.productLabel),
        const SizedBox(height: 8),
        Text(
          '${reportNumber(d.quantity)} ${o.unit} · ${d.progressLabel}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final e in balances.entries.where((e) => e.value > 1e-8).take(2))
          Text('${e.key}: ${reportNumber(e.value)} ${o.unit}'),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Ver quantidades e preparo'),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Preparado em ${_date(d.createdAt)} por ${d.operatorName}',
              ),
              subtitle: Text(d.reason),
            ),
            for (final e in balances.entries.where((e) => e.value > 1e-8))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.key),
                trailing: Text('${reportNumber(e.value)} ${o.unit}'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final action in DispatchAction.values)
              if (!d.isCancelled &&
                  d.limitFor(action) > 1e-8 &&
                  (action.sector == 'destination'
                          ? (d.isSupport ? 'support' : 'expedition')
                          : action.sector) ==
                      widget.sector &&
                  store.canRecordDispatch(widget.operator, d, action))
                OutlinedButton(
                  onPressed: _busy ? null : () => _act(action),
                  child: Text(action.label),
                ),
          ],
        ),
        if ((widget.sector == 'support' &&
                d.supportPending + d.supportRepaired > 0 &&
                store.canRecordDispatch(
                  widget.operator,
                  d,
                  DispatchAction.diagnose,
                )) ||
            (widget.sector == 'expedition' &&
                d.expeditionReady + d.stored > 0 &&
                store.canRecordDispatch(
                  widget.operator,
                  d,
                  DispatchAction.store,
                )))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Solicitar material'),
              onPressed: () => requestOrderMaterial(
                context,
                o,
                widget.operator,
                widget.sector == 'expedition' ? '10' : d.destination,
              ),
            ),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Histórico · ${d.events.length} registros'),
          children: [
            if (d.isCancelled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Preparo cancelado'),
                subtitle: Text(
                  '${_date(d.cancelledAt!)} · ${d.cancelledBy}\n${d.cancellationReason}',
                ),
              ),
            for (final e in d.events.reversed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${e.action.historyLabel}${e.quantity > 0 ? ' · ${reportNumber(e.quantity)} ${o.unit}' : ''}',
                ),
                subtitle: Text(
                  '${_date(e.at)} · ${e.operatorName}\n${e.note}${e.reference.isEmpty ? '' : '\nReferência: ${e.reference}'}',
                ),
              ),
            if (d.events.isEmpty && !d.isCancelled)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Aguardando a primeira entrega.'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _act(DispatchAction action) async {
    final result = await showDialog<_Input>(
      context: context,
      builder: (_) => _EventDialog(
        order: widget.order,
        draft: widget.draft,
        action: action,
      ),
    );
    if (result == null || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await context.read<ProductionFlowStore>().recordDispatchEvent(
        widget.order.number,
        draftId: widget.draft.id,
        eventId: result.id,
        action: action,
        quantity: result.quantity,
        note: result.note,
        operator: widget.operator,
        returnStage: result.stage,
        reference: result.reference,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${action.historyLabel} no VettiFlow.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message
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

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class _Input {
  const _Input(this.id, this.quantity, this.note, this.stage, this.reference);
  final String id, note, reference;
  final num quantity;
  final ProductionStage? stage;
}

class _EventDialog extends StatefulWidget {
  const _EventDialog({
    required this.order,
    required this.draft,
    required this.action,
  });
  final ProductionOrderFlow order;
  final ProductionDispatchDraft draft;
  final DispatchAction action;
  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  final _reference = TextEditingController();
  late final _id =
      '${widget.draft.id}:${DateTime.now().microsecondsSinceEpoch}';
  ProductionStage? _stage;
  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final limit = widget.draft.limitFor(action);
    final current = widget.order.currentStage;
    final stages =
        ProductionOrderFlow.internalProductionStages.contains(current)
        ? [current]
        : (widget.order.plannedStages.isEmpty
                  ? ProductionStage.productionFlow
                  : widget.order.plannedStages)
              .where(ProductionOrderFlow.internalProductionStages.contains)
              .toList();
    return AlertDialog(
      title: Text(action.label),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${widget.order.number} · ${widget.order.productLabel}'),
                const SizedBox(height: 12),
                const Text(
                  'Registro operacional local. Não altera o Protheus.',
                ),
                if (action == DispatchAction.deliver &&
                    widget.draft.destination == '10' &&
                    !widget.order.readyForExpedition)
                  const Text(
                    'Conclua a sequência da produção antes de entregar à expedição.',
                    style: TextStyle(color: AppColors.orangeText),
                  ),
                if (action.requiresQuantity) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Quantidade',
                      helperText:
                          'Disponível: ${reportNumber(limit)} ${widget.order.unit}',
                    ),
                    validator: (v) {
                      final n = num.tryParse(
                        (v ?? '').trim().replaceAll(',', '.'),
                      );
                      return n == null || !n.isFinite || n <= 0 || n > limit
                          ? 'Informe uma quantidade até ${reportNumber(limit)}.'
                          : null;
                    },
                  ),
                ],
                if (action == DispatchAction.receiveReturn) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProductionStage>(
                    isExpanded: true,
                    initialValue: _stage,
                    decoration: const InputDecoration(
                      labelText: 'Retomar produção em',
                    ),
                    items: [
                      for (final s in stages)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (s) => _stage = s,
                    validator: (s) =>
                        s == null ? 'Escolha a etapa da OP.' : null,
                  ),
                  const Text(
                    'A quantidade recebida volta à OP. As próximas etapas seguem a sequência programada.',
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: action == DispatchAction.diagnose
                        ? 'Diagnóstico'
                        : action == DispatchAction.repair
                        ? 'Reparo realizado e resultado'
                        : 'Motivo / conferência',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Preencha o registro.'
                      : null,
                ),
                TextFormField(
                  controller: _reference,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: action == DispatchAction.ship
                        ? 'Referência do despacho'
                        : 'Documento ou referência (opcional)',
                  ),
                  validator: (v) =>
                      action == DispatchAction.ship &&
                          (v?.trim().isEmpty ?? true)
                      ? 'Informe a referência.'
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
                _Input(
                  _id,
                  action.requiresQuantity
                      ? num.parse(_quantity.text.trim().replaceAll(',', '.'))
                      : 0,
                  _note.text.trim(),
                  _stage,
                  _reference.text.trim(),
                ),
              );
            }
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
