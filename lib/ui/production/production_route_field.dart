import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';

class ProductionRouteField extends StatelessWidget {
  const ProductionRouteField({
    super.key,
    required this.stages,
    required this.onChanged,
  });
  final List<ProductionStage> stages;
  final ValueChanged<List<ProductionStage>> onChanged;

  static const available = [
    ProductionStage.firmware,
    ProductionStage.soldering,
    ProductionStage.testing,
    ProductionStage.closing,
    ProductionStage.expedition,
  ];

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('production-route'),
    icon: const Icon(Icons.route_outlined, size: 18),
    label: Text('Etapas: ${stages.map((s) => s.label).join(' → ')}'),
    onPressed: () async {
      final result = await showDialog<List<ProductionStage>>(
        context: context,
        builder: (_) => _RouteDialog(initial: stages),
      );
      if (result != null && context.mounted) onChanged(result);
    },
  );
}

class _RouteDialog extends StatefulWidget {
  const _RouteDialog({required this.initial});
  final List<ProductionStage> initial;
  @override
  State<_RouteDialog> createState() => _RouteDialogState();
}

class _RouteDialogState extends State<_RouteDialog> {
  late final _route = [...widget.initial];

  void _move(int from, int to) =>
      setState(() => _route.insert(to, _route.removeAt(from)));

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Etapas da OP'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Escolha as etapas e ajuste a ordem pelas setas.'),
            const SizedBox(height: 12),
            for (final stage in [
              ..._route,
              ...ProductionRouteField.available.where(
                (s) => !_route.contains(s),
              ),
            ])
              Row(
                children: [
                  Checkbox(
                    key: ValueKey('route-${stage.name}'),
                    value: _route.contains(stage),
                    onChanged: _route.length == 1 && _route.contains(stage)
                        ? null
                        : (checked) => setState(() {
                            if (checked == true) {
                              _route.add(stage);
                            } else {
                              _route.remove(stage);
                            }
                          }),
                  ),
                  Expanded(
                    child: Text(
                      '${_route.contains(stage) ? '${_route.indexOf(stage) + 1}. ' : ''}${stage.label}',
                    ),
                  ),
                  if (_route.contains(stage)) ...[
                    IconButton(
                      tooltip: 'Antecipar ${stage.label}',
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      onPressed: _route.indexOf(stage) > 0
                          ? () => _move(
                              _route.indexOf(stage),
                              _route.indexOf(stage) - 1,
                            )
                          : null,
                    ),
                    IconButton(
                      tooltip: 'Adiar ${stage.label}',
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      onPressed: _route.indexOf(stage) < _route.length - 1
                          ? () => _move(
                              _route.indexOf(stage),
                              _route.indexOf(stage) + 1,
                            )
                          : null,
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 12),
            Text(
              'Começa em ${_route.first.label}. Termina em ${_route.last.label}.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, [..._route]),
        child: const Text('Usar sequência'),
      ),
    ],
  );
}
