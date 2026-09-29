import 'package:flutter/material.dart';
import '../../../data/models/ordem_producao.dart';
import '../../../data/models/production_flow.dart';
import '../../../data/repositories/flow_tracking_repository.dart';

class FlowTrackingCard extends StatefulWidget {
  const FlowTrackingCard({
    super.key,
    required this.op,
    this.repository,
    this.onChanged,
  });
  final VoidCallback? onChanged;
  final OrdemProducao op;
  final FlowTrackingRepository? repository;
  @override
  State<FlowTrackingCard> createState() => _FlowTrackingCardState();
}

class _FlowTrackingCardState extends State<FlowTrackingCard> {
  late final _repo = widget.repository ?? FlowTrackingRepository();
  Map<String, dynamic>? _data, _pending;
  bool _busy = true;
  String? _error, _selected;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.repository == null) _repo.close();
    super.dispose();
  }

  Future<void> _load({bool notifyDashboard = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _repo.read(widget.op.erpKey!);
      if (!mounted) return;
      final recovering = _pending != null;
      setState(() {
        _data = data;
        if ((data['events'] as List).any(
          (e) => e['requestId'] == _pending?['requestId'],
        )) {
          _pending = null;
        }
      });
      if (notifyDashboard || recovering) widget.onChanged?.call();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível consultar o fluxo. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(String action, String stage) async {
    String note = '';
    if (action == 'pause' || action == 'complete') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            action == 'pause' ? 'Pausar etapa' : 'Concluir etapa inteira',
          ),
          content: action == 'pause'
              ? TextField(
                  onChanged: (value) => note = value,
                  maxLength: 500,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Motivo da pausa',
                  ),
                )
              : const Text(
                  'Confirma a conclusão desta etapa para a OP? Este registro fica no VettiFlow e não realiza apontamento no ERP.',
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      note = note.trim();
      if (!mounted || accepted != true) return;
      if (action == 'pause' && note.isEmpty) {
        setState(() => _error = 'Informe o motivo da pausa.');
        return;
      }
    }
    _pending = {
      'key': widget.op.erpKey,
      'requestId': FlowTrackingRepository.requestId(),
      'expectedVersion': (_data!['state'] as Map)['version'],
      'stage': stage,
      'action': action,
      'note': note,
    };
    await _send();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _repo.send(_pending!);
      if (!mounted) return;
      setState(() {
        _data = data;
        _pending = null;
        _selected = null;
      });
      widget.onChanged?.call();
    } on FlowTrackingException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        if ([401, 403, 404, 409, 422].contains(e.status)) _pending = null;
      });
      // Keep stale state visible, but require a fresh read before another action.
      if (_pending == null) _data = null;
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Resposta não confirmada. Consulte o estado ou reenvie o mesmo registro.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _stageLabel(String stage) =>
      ProductionStage.values.firstWhere((s) => s.name == stage).label;
  static const _actions = {
    'start': 'Iniciou',
    'pause': 'Pausou',
    'resume': 'Retomou',
    'complete': 'Concluiu a etapa',
  };
  @override
  Widget build(BuildContext context) {
    final state = _data?['state'] as Map?;
    final stage = state?['stage'] as String?;
    final status = state?['status'] as String? ?? 'waiting';
    final allowed = (_data?['allowedStages'] as List? ?? []).cast<String>();
    final stages = ProductionStage.productionFlow
        .map((s) => s.name)
        .where(
          (s) =>
              allowed.contains(s) &&
              (stage == null ||
                  ProductionStage.values.firstWhere((p) => p.name == s).index >
                      ProductionStage.values
                          .firstWhere((p) => p.name == stage)
                          .index),
        )
        .toList();
    final canAct =
        !_busy &&
        _pending == null &&
        _data != null &&
        !widget.op.encerradaNoErp;
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Registre o início, as pausas e a conclusão de cada etapa, com usuário e horário. Este controle não movimenta estoque nem encerra a OP no Protheus.',
            ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (state != null)
              Text(
                stage == null
                    ? 'Sem etapa registrada. Selecione a etapa real antes de iniciar.'
                    : '${_stageLabel(stage)} · ${const {'active': 'Em execução', 'paused': 'Pausada', 'completed': 'Etapa concluída'}[status] ?? status}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            if (widget.op.encerradaNoErp)
              const Text(
                'OP encerrada no Protheus: histórico disponível, novos registros bloqueados.',
              ),
            if (_data != null && allowed.isEmpty)
              const Text(
                'Seu usuário pode consultar o histórico, mas não tem permissão para registrar a execução de etapas.',
              ),
            if (canAct &&
                (status == 'waiting' || status == 'completed') &&
                stages.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: stages.contains(_selected) ? _selected : null,
                decoration: const InputDecoration(labelText: 'Etapa a iniciar'),
                items: [
                  for (final s in stages)
                    DropdownMenuItem(value: s, child: Text(_stageLabel(s))),
                ],
                onChanged: (s) => setState(() => _selected = s),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _selected == null
                    ? null
                    : () => _action('start', _selected!),
                child: const Text('Iniciar etapa'),
              ),
            ],
            if (canAct && stage != null && allowed.contains(stage))
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (status == 'active')
                    OutlinedButton(
                      onPressed: () => _action('pause', stage),
                      child: const Text('Pausar'),
                    ),
                  if (status == 'paused')
                    FilledButton(
                      onPressed: () => _action('resume', stage),
                      child: const Text('Retomar'),
                    ),
                  if (status == 'active')
                    FilledButton(
                      onPressed: () => _action('complete', stage),
                      child: const Text('Concluir etapa'),
                    ),
                ],
              ),
            if (_pending != null)
              FilledButton(
                onPressed: _busy ? null : _send,
                child: const Text('Reenviar registro'),
              ),
            TextButton(
              onPressed: _busy ? null : () => _load(notifyDashboard: true),
              child: const Text('Consultar estado'),
            ),
            const Divider(),
            const Text(
              'Histórico recente',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            if ((_data?['events'] as List? ?? []).isEmpty)
              const Text('Nenhuma execução registrada.'),
            for (final event in (_data?['events'] as List? ?? []))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${_actions[event['action']]} · ${_stageLabel(event['stage'])}\n${event['actor']} · ${DateTime.parse(event['createdAt']).toLocal()}${event['note'].isEmpty ? '' : '\n${event['note']}'}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
