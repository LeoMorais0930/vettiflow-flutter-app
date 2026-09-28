import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/protheus_product_lookup.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_product_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';

Future<void> requestOrderMaterial(
  BuildContext context,
  ProductionOrderFlow order,
  Operator operator,
  String destination,
) => showDialog<void>(
  context: context,
  builder: (_) => _RequestDialog(
    order: order,
    operator: operator,
    destination: destination,
  ),
);

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({
    required this.order,
    required this.operator,
    required this.destination,
  });
  final ProductionOrderFlow order;
  final Operator operator;
  final String destination;
  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _code = TextEditingController();
  final _quantity = TextEditingController();
  final _form = GlobalKey<FormState>();
  late final _id =
      'REQ:${widget.order.number}:${DateTime.now().microsecondsSinceEpoch}';
  ProtheusProduct? _product;
  bool _loading = false;
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _code.text.trim();
    if (code.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _product = null;
    });
    try {
      final product =
          (await context.read<ProtheusProductRepository>().lookupByCode(
            code,
          ))?.product;
      if (!mounted) return;
      setState(() {
        if (_code.text.trim() != code) return;
        if (product == null ||
            product.isBlockedForOperations ||
            product.unit.trim().isEmpty) {
          _error = 'Material não encontrado, bloqueado ou sem unidade.';
        } else {
          _product = product;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível consultar o cadastro. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Solicitar material ao almoxarifado'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${widget.order.number} · 01 → ${widget.destination}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(
                  labelText: 'Código do material',
                ),
                onChanged: (_) => setState(() => _product = null),
                validator: (_) =>
                    _product == null ? 'Consulte e confirme o material.' : null,
              ),
              TextButton.icon(
                onPressed: _loading ? null : _lookup,
                icon: const Icon(Icons.search),
                label: Text(_loading ? 'Consultando…' : 'Consultar código'),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              if (_product != null)
                Text('${_product!.label} · ${_product!.unit}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Quantidade solicitada',
                ),
                validator: (v) {
                  final n = num.tryParse((v ?? '').trim().replaceAll(',', '.'));
                  return n == null || !n.isFinite || n <= 0
                      ? 'Informe uma quantidade positiva.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'O almoxarifado confirma a disponibilidade. A solicitação é local e não reserva estoque no Protheus.',
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
        onPressed: _loading
            ? null
            : () {
                if (!_form.currentState!.validate()) return;
                try {
                  context.read<WarehouseRequestStore>().createLinkedRequest(
                    order: widget.order,
                    operator: widget.operator,
                    componentCode: _product!.code,
                    description: _product!.description,
                    unit: _product!.unit,
                    quantity: num.parse(
                      _quantity.text.trim().replaceAll(',', '.'),
                    ),
                    destination: widget.destination,
                    requestId: _id,
                  );
                  Navigator.pop(context);
                } on StateError catch (e) {
                  setState(() => _error = e.message);
                }
              },
        child: const Text('Solicitar'),
      ),
    ],
  );
}
