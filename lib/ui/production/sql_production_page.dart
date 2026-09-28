import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/sql_production_repository.dart';
import 'package:vetti_flow_1_0/shared/models/operator_access.dart';

class SqlProductionPage extends StatefulWidget {
  const SqlProductionPage({super.key, this.localOrder});
  final ProductionOrderFlow? localOrder;
  @override
  State<SqlProductionPage> createState() => _SqlProductionPageState();
}

class _SqlProductionPageState extends State<SqlProductionPage> {
  final _form = GlobalKey<FormState>();
  final _product = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _order = TextEditingController();
  final _writeKey = TextEditingController();
  final _delivery = TextEditingController(text: _date(DateTime.now()));
  String _operation = 'abrir', _origin = '01', _destination = '05';
  String _id = _newId();
  bool _intermediates = false, _busy = false, _loaded = false;
  Map<String, dynamic>? _status, _prepared, _result;
  String? _error;
  static String _date(DateTime value) => value.toIso8601String().split('T').first;
  static String _newId() => 'vf:${DateTime.now().microsecondsSinceEpoch}:${Random.secure().nextInt(1 << 30)}';
  SqlProductionRepository get _repo => context.read<SqlProductionRepository>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final operator = context.read<OperatorAssignmentStore?>()?.currentOperator;
    if (!_loaded && (operator?.isProductionManager == true || operator?.isAdministrator == true)) {
      _loaded = true;
      final local = widget.localOrder;
      if (local != null) {
        _id = 'abrir:${local.number}:${local.createdAt.microsecondsSinceEpoch}';
        _product.text = local.productCode;
        _quantity.text = '${local.quantity}';
        _result = _repo.savedResult(_id);
        _order.text = _result?['protheusRef']?.toString() ?? '';
      }
      final pending = _repo.pending;
      if (pending != null) {
        _prepared = pending;
        _id = pending['id'] as String;
        _error = 'Há um envio sem confirmação. Consulte ou reenvie o mesmo pedido.';
      }
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _repo.status();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível consultar a conexão de escrita.');
    }
  }

  @override
  void dispose() {
    for (final controller in [_product, _quantity, _order, _writeKey, _delivery]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _perform(Future<Map<String, dynamic>> Function() action) async {
    if (_writeKey.text.trim().isEmpty) {
      setState(() => _error = 'Informe a chave de escrita do DEV.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final result = await action();
      if (mounted) setState(() {
        _result = result;
        if (result['protheusRef'] != null) _order.text = result['protheusRef'].toString();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error is SqlProductionException ? error.message : 'Resultado não confirmado. Consulte este pedido antes de repetir.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    if (!_form.currentState!.validate()) return;
    final operator = context.read<OperatorAssignmentStore>().currentOperator!;
    final quantity = _quantity.text.trim().replaceAll(',', '.');
    final body = <String, dynamic>{
      'id': _id, 'operacao': _operation, 'autor': operator.name,
      'data': _date(DateTime.now()),
      if (_operation == 'abrir') ...{
        'produto': _product.text.trim(), 'quantidade': quantity,
        'entrega': _delivery.text.trim(), 'gerarIntermediarias': _intermediates,
      },
      if (_operation == 'alterar') ...{'op': _order.text.trim(), 'novaQuantidade': quantity, 'entrega': _delivery.text.trim()},
      if (_operation == 'apontar') ...{'op': _order.text.trim(), 'quantidadeApontada': quantity, 'destino': _destination},
      if (_operation == 'transferir') ...{'produtoTransferido': _product.text.trim(), 'quantidadeTransferida': quantity, 'origem': _origin, 'destino': _destination},
    };
    await _perform(() async {
      final result = await _repo.send(body, writeKey: _writeKey.text.trim(), preview: true);
      _prepared = body;
      return result;
    });
  }

  void _reset() {
    setState(() {
      _id = _newId(); _prepared = null; _result = null; _error = null;
      // A local OP always reuses its opening ID; changes conflict rather than duplicate it.
      if (widget.localOrder case final local?) {
        if (_operation == 'abrir') _id = 'abrir:${local.number}:${local.createdAt.microsecondsSinceEpoch}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final operator = context.watch<OperatorAssignmentStore?>()?.currentOperator;
    final allowed = operator?.isProductionManager == true || operator?.isAdministrator == true;
    if (!allowed) {
      return Scaffold(appBar: AppBar(title: const Text('Produção no DEV')),
        body: const Center(child: Text('Entre como gestor da produção para acessar.')));
    }
    final pending = _repo.pending != null;
    final frozen = _busy || _prepared != null || _result?['status'] == 'aplicada';
    final enabled = _status?['enabled'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Produção no Protheus DEV'), actions: [IconButton(onPressed: _busy ? null : _loadStatus, icon: const Icon(Icons.refresh), tooltip: 'Atualizar conexão')]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const Text('Abertura e movimentações da produção', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Base HMLp12 · filial 04 · produção 05. As etapas de trabalho continuam no fluxo local. Esta tela registra operações de estoque no DEV.'),
          if (widget.localOrder != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('OP local: ${widget.localOrder!.number}')),
          if (!enabled) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(
            (_status?['reasons'] as List? ?? ['Consultando disponibilidade…']).join('\n'),
          )),
          const SizedBox(height: 16),
          Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(initialValue: _operation, decoration: const InputDecoration(labelText: 'Operação'),
              items: const [DropdownMenuItem(value: 'abrir', child: Text('Abrir OP')),
                DropdownMenuItem(value: 'alterar', child: Text('Alterar quantidade da OP')),
                DropdownMenuItem(value: 'transferir', child: Text('Transferir estoque existente')),
                DropdownMenuItem(value: 'apontar', child: Text('Apontar produção'))],
              onChanged: frozen ? null : (value) => setState(() { _operation = value!; _reset(); })),
            const SizedBox(height: 12),
            if (_operation == 'abrir' || _operation == 'transferir')
              TextFormField(key: const Key('sql-product'), controller: _product, enabled: !frozen,
                decoration: const InputDecoration(labelText: 'Código do produto'), validator: (value) => value!.trim().isEmpty ? 'Informe o produto.' : null),
            if (_operation == 'alterar' || _operation == 'apontar')
              TextFormField(controller: _order, enabled: !frozen, decoration: const InputDecoration(labelText: 'Referência completa da OP no Protheus'), validator: (value) => value!.trim().isEmpty ? 'Informe a OP.' : null),
            const SizedBox(height: 12),
            TextFormField(key: const Key('sql-quantity'), controller: _quantity, enabled: !frozen,
              keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantidade'),
              validator: (value) { final number = num.tryParse((value ?? '').replaceAll(',', '.')); return number == null || !number.isFinite || number <= 0 ? 'Informe uma quantidade positiva.' : null; }),
            const SizedBox(height: 12),
            if (_operation == 'abrir' || _operation == 'alterar')
              TextFormField(controller: _delivery, enabled: !frozen, decoration: const InputDecoration(labelText: 'Entrega (AAAA-MM-DD)'),
                validator: (value) => DateTime.tryParse(value ?? '') == null ? 'Informe uma data válida.' : null),
            if (_operation == 'abrir') CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Gerar OPs intermediárias da estrutura'),
              subtitle: const Text('Gera a quantidade integral dos componentes que têm estrutura própria.'),
              value: _intermediates, onChanged: frozen ? null : (value) => setState(() => _intermediates = value!)),
            if (_operation == 'transferir') _warehouse('Origem', _origin, const ['01','05','07','10'], frozen, (v) => _origin = v),
            if (_operation == 'transferir' || _operation == 'apontar') _warehouse('Destino', _destination,
              _operation == 'apontar' ? const ['05','07','10'] : const ['01','05','07','10'], frozen, (v) => _destination = v),
            const SizedBox(height: 16),
            TextFormField(key: const Key('sql-write-key'), controller: _writeKey, obscureText: true, enableSuggestions: false,
              autocorrect: false, enabled: !_busy, decoration: const InputDecoration(labelText: 'Chave de escrita do DEV', helperText: 'Mantida apenas nesta tela. Não é a senha do banco.')),
          ])),
          const SizedBox(height: 16),
          SelectableText('Pedido: $_id'),
          if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Text(_result!['status'] == 'aplicada' ? 'Operação registrada no DEV' : 'Prévia calculada — ainda não gravada', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (_result!['protheusRef'] != null) SelectableText('OP: ${_result!['protheusRef']}'),
            for (final row in _result!['ordens'] as List? ?? []) Text('OP ${row['op']} · ${row['produto'] ?? ''} · quantidade ${row['quantidade'] ?? row['produzida'] ?? ''}'),
            for (final row in _result!['empenhos'] as List? ?? []) Text('Empenho: ${row['produto']} · ${row['quantidade']} · local ${row['local']}'),
            for (final row in _result!['movimentos'] as List? ?? []) Text('${row['cf']}: ${row['produto']} · ${row['quantidade']} · local ${row['local']}'),
            if (_result!['status'] == 'previa') const Text('Saldos e estrutura serão conferidos novamente ao gravar. A numeração da prévia não é reservada.'),
          ],
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, children: [
            if (!frozen) FilledButton(onPressed: enabled ? _preview : null, child: const Text('Conferir operação')),
            if (_result?['status'] == 'previa' && !pending) FilledButton(onPressed: _busy ? null : () => _perform(() => _repo.send(_prepared!, writeKey: _writeKey.text.trim())), child: const Text('Gravar no DEV')),
            if (pending) OutlinedButton(onPressed: _busy ? null : () => _perform(() => _repo.send(_repo.pending!, writeKey: _writeKey.text.trim())), child: const Text('Reenviar mesmo pedido')),
            OutlinedButton(onPressed: _busy || !enabled ? null : () => _perform(() => _repo.consult(_id, writeKey: _writeKey.text.trim())), child: const Text('Consultar pedido')),
            if (frozen && !pending) TextButton(onPressed: _busy ? null : _reset, child: const Text('Nova operação')),
          ]),
          if (_busy) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
        ]),
      )),
    );
  }

  Widget _warehouse(String label, String value, List<String> options, bool frozen, void Function(String) assign) =>
    Padding(padding: const EdgeInsets.only(top: 12), child: DropdownButtonFormField<String>(initialValue: value,
      decoration: InputDecoration(labelText: label), items: [for (final option in options) DropdownMenuItem(value: option, child: Text(option))],
      onChanged: frozen ? null : (next) => setState(() => assign(next!))));
}
