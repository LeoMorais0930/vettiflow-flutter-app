import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/data/repositories/commitment_review_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

/// Revisão reversível seguida de envio explícito à fila ADVPL.
class CommitmentReviewPage extends StatefulWidget {
  const CommitmentReviewPage({
    super.key,
    required this.op,
    this.filial = '04',
    this.repository,
    this.demonstration = false,
  });
  final String op, filial;
  final CommitmentReviewRepository? repository;
  final bool demonstration;
  @override
  State<CommitmentReviewPage> createState() => _CommitmentReviewPageState();
}

class _CommitmentReviewPageState extends State<CommitmentReviewPage> {
  late final CommitmentReviewRepository _repository;
  Map<String, dynamic>? _data;
  final Map<int, String> _excluded = {};
  bool _loading = true,
      _saving = false,
      _showMod = true,
      _dirty = false,
      _mustReload = false;
  String _search = '', _filter = 'Todos', _message = '';
  static const _reasons = [
    'Já disponível no setor',
    'Não utilizado nesta OP',
    'Caso específico da produção',
  ];
  List<Map<String, dynamic>> get _items => ((_data?['items'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  bool _mod(Map row) => '${row['produto']}'.toUpperCase().startsWith('MOD');
  List<Map<String, dynamic>> get _physical =>
      _items.where((e) => !_mod(e) && (e['quantidade'] as num) > 0).toList();
  bool get _canSave => _data?['canSave'] == true && !_saving && !_mustReload;
  bool get _canSubmit =>
      _canSave &&
      !_dirty &&
      _excluded.isNotEmpty &&
      _data?['canSubmit'] == true;
  String _statusText(Map submission) => switch (submission['status']) {
    'pendente' => 'Aguardando execução no Protheus.',
    'processando' => 'Em execução no Protheus. Não envie novamente.',
    'aguardando_conferencia' =>
      'Execução retornou; aguardando conferência dos empenhos.',
    'aplicada' => 'Exclusões confirmadas no Protheus.',
    'rejeitada' =>
      'Pedido recusado sem alterações confirmadas. Confira o motivo.',
    _ => 'Resultado incerto. Confira no Protheus antes de qualquer novo envio.',
  };

  Future<void> _submit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Enviar exclusões ao Protheus?'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_excluded.length} empenho(s) serão excluídos da OP ${widget.op} quando o pedido for executado.',
                ),
                const SizedBox(height: 12),
                for (final row in _items.where(
                  (r) => _excluded.containsKey(r['id']),
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      "${row['produto']} · ${row['descricao']}\nArmazém ${row['local']} · ${row['quantidade']} ${row['unidade']}\n${_excluded[row['id']]}",
                    ),
                  ),
                const Text(
                  'Os demais empenhos serão mantidos. MOD permanece separado. Após o envio, a revisão fica bloqueada até o resultado.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Continuar revisando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar envio'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _message = '';
    });
    try {
      final submitted = await _repository.submit(widget.op, widget.filial, {
        'expectedVersion': _data!['version'],
        'fingerprint': _data!['fingerprint'],
      });
      if (!mounted) return;
      setState(() {
        _data = {
          ..._data!,
          'submission': submitted,
          'canSave': false,
          'canSubmit': false,
        };
        _message = _statusText(submitted);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _mustReload = true;
          _message =
              'Não foi possível confirmar o envio. Recarregue para consultar a fila antes de tentar novamente. ${e is StateError ? e.message : ""}';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CommitmentReviewRepository();
    _load();
  }

  @override
  void dispose() {
    if (widget.repository == null) _repository.close();
    super.dispose();
  }

  void _accept(Map<String, dynamic> data) {
    _data = data;
    _excluded.clear();
    for (final entry in data['excluded'] as List) {
      _excluded[entry['id'] as int] = entry['reason'] as String;
    }
    _dirty = false;
    _mustReload = false;
  }

  Future<void> _load() async {
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Recarregar os empenhos?'),
          content: const Text(
            'As marcações ainda não salvas serão descartadas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Continuar revisando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Recarregar'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final data = await _repository.load(widget.op, widget.filial);
      if (!mounted) return;
      setState(() {
        _accept(data);
        if (data['submission'] is Map) {
          final submitted = data['submission'] as Map;
          _message = '${_statusText(submitted)} ${submitted['mensagem'] ?? ''}';
        } else if (data['stale'] == true) {
          _message =
              'Os empenhos mudaram no Protheus. Revise a lista atualizada; as marcações antigas não foram reaplicadas.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _data = null;
          _message =
              'Não foi possível carregar os empenhos confirmados desta OP. Recarregue para tentar novamente.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = '';
    });
    try {
      final data = await _repository.save(widget.op, widget.filial, {
        'expectedVersion': _data!['version'],
        'fingerprint': _data!['fingerprint'],
        'excluded': [
          for (final entry in _excluded.entries)
            {'id': entry.key, 'reason': entry.value},
        ],
      });
      if (mounted) {
        setState(() {
          _accept(data);
          _message =
              'Revisão salva. Nenhum empenho foi excluído no Protheus; a aplicação está pendente.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mustReload = true;
          _message =
              'Não foi possível confirmar o salvamento. Recarregue antes de tentar novamente. ${e is StateError ? e.message : ''}';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _leave() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Sair sem salvar a revisão?'),
            content: const Text(
              'Os empenhos do Protheus continuam intactos. As marcações não salvas serão perdidas.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Continuar revisando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Sair sem salvar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final order = (_data?['order'] as Map?) ?? {};
    final visible = _items.where((row) {
      if ((row['quantidade'] as num) <= 0 || (_mod(row) && !_showMod)) {
        return false;
      }
      final excluded = _excluded.containsKey(row['id']);
      return ('${row['produto']} ${row['descricao']}').toLowerCase().contains(
            _search.toLowerCase(),
          ) &&
          (_filter == 'Todos' || (_filter == 'Excluir' ? excluded : !excluded));
    }).toList();
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && await _leave() && context.mounted) {
          setState(() => _dirty = false);
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Revisar empenhos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          actions: [
            TextButton.icon(
              onPressed: _loading || _saving ? null : _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Recarregar'),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, bounds) => _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: SizedBox(
                    height: bounds.maxWidth < 650
                        ? math.max(bounds.maxHeight, 1450)
                        : bounds.maxHeight,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (widget.demonstration)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    'PRÉVIA VISUAL · DADOS ILUSTRATIVOS',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              Wrap(
                                spacing: 16,
                                runSpacing: 6,
                                children: [
                                  _step(
                                    Icons.check_circle_outline,
                                    '1  OP criada',
                                    AppColors.green,
                                  ),
                                  _step(
                                    Icons.format_list_bulleted,
                                    '2  Revisar empenhos',
                                    AppColors.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (_data != null)
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Wrap(
                                    spacing: 35,
                                    runSpacing: 12,
                                    children: [
                                      _info('ORDEM DE PRODUÇÃO', widget.op),
                                      _info(
                                        'PRODUTO',
                                        '${order['produto']} · ${order['produtoDescricao'] ?? ''}',
                                      ),
                                      _info(
                                        'QUANTIDADE',
                                        '${order['quantidadePlanejada'] ?? ''} un',
                                      ),
                                      _info(
                                        'ARMAZÉM',
                                        '${order['local'] ?? ''}',
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 18),
                              const Text(
                                'Gerenciar empenhos desta OP',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Todos começam mantidos. Marque os itens que deseja excluir; você pode desfazer antes de salvar.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_message.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgAndamento,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _message,
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              if (_data != null)
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: LayoutBuilder(
                                            builder: (c, box) {
                                              final search = TextField(
                                                onChanged: (v) =>
                                                    setState(() => _search = v),
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  hintText:
                                                      'Buscar código ou descrição',
                                                  prefixIcon: const Icon(
                                                    Icons.search,
                                                    size: 20,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    borderSide:
                                                        const BorderSide(
                                                          color:
                                                              AppColors.border,
                                                        ),
                                                  ),
                                                ),
                                              );
                                              final filters = Wrap(
                                                spacing: 6,
                                                children: [
                                                  for (final label in [
                                                    'Todos',
                                                    'Mantidos',
                                                    'Excluir',
                                                  ])
                                                    ChoiceChip(
                                                      label: Text(label),
                                                      selected:
                                                          _filter == label,
                                                      onSelected: (_) =>
                                                          setState(
                                                            () =>
                                                                _filter = label,
                                                          ),
                                                      showCheckmark: false,
                                                    ),
                                                ],
                                              );
                                              return box.maxWidth < 650
                                                  ? Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: [
                                                        search,
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        filters,
                                                      ],
                                                    )
                                                  : Row(
                                                      children: [
                                                        Expanded(child: search),
                                                        const SizedBox(
                                                          width: 20,
                                                        ),
                                                        filters,
                                                      ],
                                                    );
                                            },
                                          ),
                                        ),
                                        LayoutBuilder(
                                          builder: (c, box) =>
                                              box.maxWidth < 650
                                              ? const SizedBox.shrink()
                                              : Container(
                                                  color: AppColors.bgHeader,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 11,
                                                      ),
                                                  child: const Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          'PRODUTO',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                AppColors.muted,
                                                            letterSpacing: .8,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 100,
                                                        child: Text(
                                                          'ARMAZÉM',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                AppColors.muted,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 125,
                                                        child: Text(
                                                          'QTD. EMPENHADA',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                AppColors.muted,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 126,
                                                        child: Text(
                                                          'AÇÃO',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                AppColors.muted,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                        ),
                                        const Divider(
                                          height: 1,
                                          color: AppColors.borderLight,
                                        ),
                                        Expanded(
                                          child: visible.isEmpty
                                              ? const Center(
                                                  child: Text(
                                                    'Nenhum empenho neste filtro.',
                                                  ),
                                                )
                                              : ListView.builder(
                                                  itemCount: visible.length,
                                                  itemBuilder: (c, i) =>
                                                      _row(visible[i]),
                                                ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${visible.length} linhas neste filtro',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.muted,
                                                  ),
                                                ),
                                              ),
                                              const Text(
                                                'Mostrar MOD',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.muted,
                                                ),
                                              ),
                                              Switch(
                                                value: _showMod,
                                                onChanged: (v) => setState(
                                                  () => _showMod = v,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (_data == null) const Spacer(),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 18,
                                runSpacing: 8,
                                children: [
                                  Text(
                                    '${_physical.length - _excluded.length} mantidos',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  Text(
                                    '${_excluded.length} marcados para excluir',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.orangeText,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (c, box) {
                                  final note = Text(
                                    _data?['canSubmit'] != true &&
                                            _data?['submission'] == null
                                        ? 'Você pode salvar a revisão.\nO envio aguarda liberação da fila ADVPL.'
                                        : 'Salve a revisão e depois envie as exclusões ao Protheus.\nA execução será acompanhada pela fila ADVPL.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  );
                                  final save = FilledButton.icon(
                                    onPressed: _canSave ? _save : null,
                                    icon: Icon(
                                      _saving
                                          ? Icons.hourglass_empty
                                          : Icons.save_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _saving ? 'Salvando…' : 'Salvar revisão',
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 18,
                                      ),
                                    ),
                                  );
                                  final actions = Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      save,
                                      OutlinedButton.icon(
                                        onPressed: _canSubmit ? _submit : null,
                                        icon: const Icon(
                                          Icons.send_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Enviar ao Protheus'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                  return box.maxWidth < 1000
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            note,
                                            const SizedBox(height: 10),
                                            actions,
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Expanded(child: note),
                                            actions,
                                          ],
                                        );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _step(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 7),
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
  Widget _info(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.muted,
          letterSpacing: .7,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
    ],
  );
  Widget _row(Map<String, dynamic> row) {
    final id = row['id'] as int;
    final removed = _excluded.containsKey(id);
    final mod = _mod(row);
    final action = TextButton.icon(
      key: ValueKey('exclude-$id'),
      onPressed: !_canSave || mod
          ? null
          : () => setState(() {
              if (removed) {
                _excluded.remove(id);
              } else {
                _excluded[id] = _reasons.first;
              }
              _dirty = true;
              _message = '';
            }),
      icon: Icon(removed ? Icons.undo : Icons.remove_circle_outline, size: 18),
      label: Text(
        mod
            ? 'Separado'
            : removed
            ? 'Desfazer'
            : 'Excluir',
      ),
      style: TextButton.styleFrom(
        foregroundColor: removed ? AppColors.primary : AppColors.muted,
      ),
    );
    final product = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${row['produto']}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: removed ? AppColors.muted : AppColors.text,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${row['descricao']}',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.muted,
            decoration: removed ? TextDecoration.lineThrough : null,
          ),
        ),
        if (removed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.remove_circle_outline,
                  size: 14,
                  color: AppColors.orangeText,
                ),
                const SizedBox(width: 5),
                const Text(
                  'Excluir · ',
                  style: TextStyle(fontSize: 12, color: AppColors.orangeText),
                ),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isDense: true,
                      isExpanded: true,
                      value: _excluded[id],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: AppColors.orangeText,
                      ),
                      items: [
                        for (final reason in {..._reasons, _excluded[id]!})
                          DropdownMenuItem(
                            value: reason,
                            child: Text(
                              reason,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _canSave
                          ? (v) => setState(() {
                              _excluded[id] = v!;
                              _dirty = true;
                            })
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: removed ? const Color(0xfffff8f0) : Colors.white,
        border: const Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: LayoutBuilder(
        builder: (c, box) => box.maxWidth < 610
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  product,
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Arm. ${row['local']}   ·   ${row['quantidade']} ${row['unidade']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      action,
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: product),
                  SizedBox(
                    width: 100,
                    child: Text(
                      '${row['local']}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                  SizedBox(
                    width: 125,
                    child: Text(
                      '${row['quantidade']} ${row['unidade']}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  SizedBox(width: 126, child: action),
                ],
              ),
      ),
    );
  }
}
