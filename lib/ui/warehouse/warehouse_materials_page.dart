import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart'
    show reportNumber, reportDate;
import 'package:vetti_flow_1_0/data/models/warehouse_request.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/read_period_filter.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

/// Acompanhamento local de materiais; nenhuma ação chama o Protheus.
class WarehouseMaterialsPage extends StatefulWidget {
  const WarehouseMaterialsPage({super.key, this.destinationWarehouses});
  final List<String>? destinationWarehouses;
  @override
  State<WarehouseMaterialsPage> createState() => _WarehouseMaterialsPageState();
}

class _WarehouseMaterialsPageState extends State<WarehouseMaterialsPage> {
  String _query = '';
  String _status = 'open';
  bool get _receiving => widget.destinationWarehouses != null;
  String get _sectorRoute =>
      switch (widget.destinationWarehouses?.firstOrNull) {
        '03' => '/smd',
        '05' => '/producao',
        '06' || '07' => '/suporte',
        '10' => '/expedicao',
        _ => '/almoxarifado',
      };
  DateTimeRange? _period;
  int _page = 0;
  static const _pageSize = 20;

  @override
  Widget build(BuildContext context) {
    final operator = context.watch<OperatorAssignmentStore>().currentOperator;
    final store = context.watch<WarehouseRequestStore>();
    final orders = context.watch<ProductionFlowStore>().orders;
    final allowed =
        operator != null && operator.canAccessRoute('$_sectorRoute/materiais');
    final source = store.requests.where(
      (r) => _receiving
          ? widget.destinationWarehouses!.contains(r.orderWarehouse)
          : r.requestedWarehouse == '01',
    );
    final rows = source.where((r) {
      if (_status == 'open' &&
          ((_receiving
                  ? r.remainingQuantity == 0 &&
                        r.toReceive == 0 &&
                        r.availableAtDestination == 0 &&
                        r.returnTransit == 0
                  : r.isDelivered && r.returnTransit == 0 ||
                        r.cancelledQuantity >= r.quantity) ||
              r.status == WarehouseRequestStatus.rejected)) {
        return false;
      }
      if (_status == 'delivered' && !r.isDelivered) {
        return false;
      }
      if (_status == 'unavailable' &&
          r.status != WarehouseRequestStatus.rejected) {
        return false;
      }
      final period = _period;
      if (period != null &&
          (r.createdAt.isBefore(period.start) ||
              !r.createdAt.isBefore(
                DateTime(period.end.year, period.end.month, period.end.day + 1),
              ))) {
        return false;
      }
      return '${r.orderNumber} ${r.productCode} ${r.productName} ${r.componentCode} ${r.componentDescription} ${r.requestedBy}'
          .toLowerCase()
          .contains(_query.trim().toLowerCase());
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final pages = ((rows.length + _pageSize - 1) ~/ _pageSize).clamp(
      1,
      1000000,
    );
    final page = _page.clamp(0, pages - 1);
    final visible = rows.skip(page * _pageSize).take(_pageSize).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 920;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              VettiTopBar(
                title: _receiving ? 'Materiais do setor' : 'Almoxarifado',
                operatorName: operator?.name ?? 'Consulta',
                operatorRole: 'Pedidos de materiais',
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
                                      tooltip: 'Voltar ao setor',
                                      icon: const Icon(Icons.arrow_back),
                                      onPressed: () =>
                                          Navigator.of(context).canPop()
                                          ? Navigator.pop(context)
                                          : Navigator.pushReplacementNamed(
                                              context,
                                              operator.canAccessRoute(
                                                    _sectorRoute,
                                                  )
                                                  ? _sectorRoute
                                                  : operator.homeRoute,
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Pedidos de materiais',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.title,
                                        ),
                                      ),
                                    ),
                                    if (!_receiving)
                                      IconButton(
                                        tooltip: 'OPs a liberar',
                                        icon: const Icon(
                                          Icons.playlist_add_check,
                                        ),
                                        onPressed: () => Navigator.pushNamed(
                                          context,
                                          '/almoxarifado/operacao',
                                        ),
                                      ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'Pedidos, entregas e devoluções locais. Não alteram o estoque no Protheus.',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (store.persistenceError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      store.persistenceError!,
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ),
                                if (store.persistenceError != null)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: store.retrySaving,
                                      child: const Text(
                                        'Tentar salvar novamente',
                                      ),
                                    ),
                                  ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final entry in const {
                                      'open': 'Pendentes',
                                      'unavailable': 'Indisponíveis',
                                      'delivered': 'Entregues',
                                      'all': 'Todos',
                                    }.entries)
                                      ChoiceChip(
                                        label: Text(entry.value),
                                        selected: _status == entry.key,
                                        onSelected: (_) => setState(() {
                                          _status = entry.key;
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
                                  '${rows.length} itens de material',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: visible.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'Nenhum pedido neste filtro.\nAs solicitações vinculadas às OPs aparecem aqui.',
                                            textAlign: TextAlign.center,
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: visible.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            final request = visible[index];
                                            final order = orders
                                                .where(
                                                  (o) =>
                                                      o.number ==
                                                      request.orderNumber,
                                                )
                                                .firstOrNull;
                                            return _requestCard(
                                              request,
                                              order,
                                              store,
                                              operator,
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
        labelText: 'OP, produto, material ou solicitante',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (v) => setState(() {
        _query = v;
        _page = 0;
      }),
    );
    final period = ReadPeriodFilter(
      start: _period?.start,
      end: _period?.end,
      dateLabel: 'Data do pedido',
      onChanged: (v) => setState(() {
        _period = v;
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

  Widget _requestCard(
    WarehouseConfirmationRequest r,
    ProductionOrderFlow? order,
    WarehouseRequestStore store,
    Operator operator,
  ) {
    final activeOrder = r.manual || (order != null && !order.isDone);
    final editable = !_receiving && activeOrder && store.canHandle(r, operator);
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
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'OP ${r.orderNumber} · ${r.productCode}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              Text(
                r.progressLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${r.componentCode} · ${r.componentDescription}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${r.warehouseLabel} → ${r.orderWarehouseLabel}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            'Solicitado por ${r.requestedBy} · ${_date(r.createdAt)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if (order != null && order.plannedStages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Rota da OP: ${order.plannedStages.map((s) => s.label).join(' → ')}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          if (!activeOrder)
            const Text(
              'OP encerrada ou não disponível neste dispositivo. Atendimento bloqueado.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              Text('Pedido: ${_quantity(r.quantity, r.unit)}'),
              Text('Separado: ${_quantity(r.separatedQuantity, r.unit)}'),
              Text('Entregue: ${_quantity(r.deliveredQuantity, r.unit)}'),
              Text('Recebido: ${_quantity(r.receivedQuantity, r.unit)}'),
              Text(
                'Disponível no destino: ${_quantity(r.availableAtDestination, r.unit)}',
              ),
              Text('Usado: ${_quantity(r.usedQuantity, r.unit)}'),
              if (r.returnSentQuantity > 0)
                Text(
                  'Devolvido / recebido na origem: ${_quantity(r.returnSentQuantity, r.unit)} / ${_quantity(r.returnedQuantity, r.unit)}',
                ),
              Text(
                'Falta entregar: ${_quantity(r.remainingQuantity, r.unit)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (r.status == WarehouseRequestStatus.rejected &&
              r.responseNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                r.responseNote!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (editable && r.status != WarehouseRequestStatus.confirmed) ...[
                FilledButton.icon(
                  onPressed: () => _run(() => store.confirm(r.id, operator)),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Confirmar disponibilidade'),
                ),
                if (r.isPending)
                  OutlinedButton(
                    onPressed: () => _edit(r, operator, 'reject'),
                    child: const Text('Informar falta'),
                  ),
              ],
              if (editable &&
                  r.status == WarehouseRequestStatus.confirmed &&
                  r.toSeparate > 0)
                FilledButton.icon(
                  onPressed: () => _edit(r, operator, 'separate'),
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('Registrar separação'),
                ),
              if (editable && r.readyToDeliver > 0)
                FilledButton.icon(
                  onPressed: () => _edit(r, operator, 'deliver'),
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('Registrar entrega'),
                ),
              for (final action
                  in (_receiving
                      ? [
                          WarehouseMaterialAction.received,
                          WarehouseMaterialAction.used,
                          WarehouseMaterialAction.returnSent,
                        ]
                      : [
                          WarehouseMaterialAction.returnReceived,
                          WarehouseMaterialAction.unseparated,
                          WarehouseMaterialAction.cancelled,
                        ]))
                if (r.limitFor(action) > 0 &&
                    store.canRecordMaterial(r, operator, action))
                  OutlinedButton(
                    onPressed: () => _edit(r, operator, action.name),
                    child: Text(_actionLabel(action.name)),
                  ),
              TextButton.icon(
                onPressed: () => _history(r),
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Histórico'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _run(VoidCallback action) {
    try {
      action();
    } on StateError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _edit(
    WarehouseConfirmationRequest request,
    Operator operator,
    String action,
  ) async {
    final result = await showDialog<_MaterialEntry>(
      context: context,
      builder: (_) => _MaterialDialog(request: request, action: action),
    );
    if (result == null || !mounted) return;
    final store = context.read<WarehouseRequestStore>();
    final orders = context.read<ProductionFlowStore>().orders;
    if (['reject', 'separate', 'deliver'].contains(action) &&
        !request.manual &&
        !orders.any((o) => o.number == request.orderNumber && !o.isDone)) {
      _run(
        () =>
            throw StateError('A OP não está mais disponível para atendimento.'),
      );
      return;
    }
    _run(() {
      if (action == 'reject') {
        store.reject(request.id, operator, result.note);
      } else {
        final type = action == 'separate'
            ? WarehouseMaterialAction.separated
            : action == 'deliver'
            ? WarehouseMaterialAction.delivered
            : WarehouseMaterialAction.values.byName(action);
        store.recordMaterialEvent(
          request.id,
          operator,
          result.quantity,
          type,
          eventId: result.id,
          note: result.note,
        );
      }
    });
  }

  void _history(WarehouseConfirmationRequest r) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Histórico · ${r.componentCode}'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pedido criado · ${_date(r.createdAt)} · ${r.requestedBy}'),
              Text('${_quantity(r.quantity, r.unit)} · OP ${r.orderNumber}'),
              if (r.events.isEmpty && r.responseBy != null)
                Text(
                  '${r.progressLabel} · ${r.responseBy} · ${_date(r.updatedAt)}',
                ),
              for (final event in r.events) ...[
                const Divider(height: 24),
                Text(
                  event.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text('${_date(event.at)} · ${event.operatorName}'),
                if (event.quantity > 0) Text(_quantity(event.quantity, r.unit)),
                if (event.note.isNotEmpty) Text(event.note),
              ],
            ],
          ),
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

String _quantity(num value, String unit) =>
    '${reportNumber(value)} ${unit.isEmpty ? '(unidade não informada)' : unit}';
String _date(DateTime date) =>
    '${reportDate(date.toIso8601String().substring(0, 10))} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class _MaterialEntry {
  const _MaterialEntry(this.id, this.quantity, this.note);
  final String id;
  final num quantity;
  final String note;
}

class _MaterialDialog extends StatefulWidget {
  const _MaterialDialog({required this.request, required this.action});
  final WarehouseConfirmationRequest request;
  final String action;
  @override
  State<_MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialDialogState extends State<_MaterialDialog> {
  final _form = GlobalKey<FormState>();
  late final _quantity = TextEditingController();
  final _note = TextEditingController();
  late final _id =
      'material:${widget.request.id}:${DateTime.now().microsecondsSinceEpoch}';
  num get _limit => widget.request.limitFor(
    widget.action == 'separate'
        ? WarehouseMaterialAction.separated
        : widget.action == 'deliver'
        ? WarehouseMaterialAction.delivered
        : widget.action == 'reject'
        ? WarehouseMaterialAction.rejected
        : WarehouseMaterialAction.values.byName(widget.action),
  );
  num? get _value => num.tryParse(_quantity.text.trim().replaceAll(',', '.'));
  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_actionLabel(widget.action)),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.request.componentCode} · ${widget.request.componentDescription}',
              ),
              const SizedBox(height: 16),
              if (widget.action != 'reject')
                TextFormField(
                  controller: _quantity,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Quantidade desta vez',
                    helperText:
                        'Disponível: ${reportNumber(_limit)} ${widget.request.unit}',
                  ),
                  validator: (_) =>
                      _value == null ||
                          !_value!.isFinite ||
                          _value! <= 0 ||
                          _value! > _limit + _limit.abs() * 1e-10
                      ? 'Informe um valor maior que zero, até ${reportNumber(_limit)}.'
                      : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLength: 300,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText:
                      [
                        'reject',
                        'returnSent',
                        'cancelled',
                        'unseparated',
                      ].contains(widget.action)
                      ? 'Motivo'
                      : 'Observação (opcional)',
                ),
                validator: (value) =>
                    [
                          'reject',
                          'returnSent',
                          'cancelled',
                          'unseparated',
                        ].contains(widget.action) &&
                        (value?.trim().isEmpty ?? true)
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
              _MaterialEntry(_id, _value ?? 0, _note.text.trim()),
            );
          }
        },
        child: const Text('Registrar'),
      ),
    ],
  );
}

String _actionLabel(String action) => switch (action) {
  'reject' => 'Informar falta',
  'separate' => 'Registrar separação',
  'deliver' => 'Registrar entrega',
  'received' => 'Confirmar recebimento',
  'used' => 'Registrar uso',
  'returnSent' => 'Devolver material',
  'returnReceived' => 'Receber devolução',
  'unseparated' => 'Desfazer separação',
  'cancelled' => 'Cancelar saldo não separado',
  _ => action,
};

class MaterialsNavigationButton extends StatelessWidget {
  const MaterialsNavigationButton({super.key, required this.sector});
  final String sector;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Materiais do setor',
    icon: const Icon(Icons.inventory_2_outlined),
    onPressed: () => Navigator.pushNamed(context, '/$sector/materiais'),
  );
}
