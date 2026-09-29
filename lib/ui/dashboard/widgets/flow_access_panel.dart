import 'package:flutter/material.dart';
import '../../../data/repositories/flow_access_repository.dart';

/// Permissions come exclusively from the authenticated server response.
class FlowAccessPanel extends StatefulWidget {
  const FlowAccessPanel({super.key, this.repository});
  final FlowAccessRepository? repository;
  @override
  State<FlowAccessPanel> createState() => _FlowAccessPanelState();
}

class _FlowAccessPanelState extends State<FlowAccessPanel> {
  static const labels = {
    'warehouse': 'Almoxarifado',
    'smd': 'SMD',
    'firmware': 'Gravação',
    'soldering': 'Soldagem',
    'testing': 'Teste',
    'closing': 'Fechamento',
    'expedition': 'Expedição',
  };
  late final _repo = widget.repository ?? FlowAccessRepository();
  final _username = TextEditingController();
  Map<String, dynamic>? _me, _user;
  List<dynamic> _users = [];
  Set<String> _stages = {};
  bool _busy = true;
  String? _error, _message;
  Map<String, dynamic>? _directory;
  String? _directoryError;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _username.dispose();
    if (widget.repository == null) _repo.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
      _me = null;
      _user = null;
      _directory = null;
      _directoryError = null;
      _search = '';
      _message = null;
    });
    try {
      final me = await _repo.me();
      final users = me['canManage'] == true
          ? (await _repo.users())['items'] as List
          : <dynamic>[];
      Map<String, dynamic>? directory;
      String? directoryError;
      if (me['canManage'] == true) {
        try {
          directory = await _repo.directory();
        } catch (e) {
          directoryError = e.toString();
        }
      }
      if (!mounted) return;
      setState(() {
        _me = me;
        _users = users;
        _directory = directory;
        _directoryError = directoryError;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _consult([String? selected]) async {
    if (_busy) return;
    final username = (selected ?? _username.text).trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9._@-]{0,63}$').hasMatch(username)) {
      setState(() => _error = 'Informe o login Protheus, sem espaços.');
      return;
    }
    _username.text = username;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
      _user = null;
    });
    try {
      final user = await _repo.read(username);
      if (!mounted) return;
      setState(() {
        _user = user;
        _stages = Set<String>.from(user['stages'] as List);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _user == null || _user!['isAdmin'] == true) return;
    final username = _user!['username'] as String;
    final stages = labels.keys.where(_stages.contains).toList();
    final version = _user!['version'] as int;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final saved = await _repo.save(username, stages, version);
      if (!mounted) return;
      setState(() {
        _user = saved;
        _stages = Set<String>.from(saved['stages'] as List);
        _users = [..._users.where((u) => u['username'] != username), saved];
        _message = 'Permissões salvas no servidor.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _user = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _names(List<dynamic> stages) => stages.isEmpty
      ? 'Somente consulta'
      : stages.map((s) => labels[s] ?? s).join(', ');
  @override
  Widget build(BuildContext context) {
    final canManage = _me?['canManage'] == true;
    final directoryItems = (_directory?['items'] as List? ?? [])
        .where(
          (u) => '${u['name']} ${u['username']}'.toLowerCase().contains(
            _search.trim().toLowerCase(),
          ),
        )
        .toList();
    final editable = !_busy && _user != null && _user!['isAdmin'] != true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Permissões de execução',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Defina quem pode iniciar, pausar, retomar e concluir etapas no VettiFlow. Estas permissões não concedem acesso adicional ao Protheus.',
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_message != null)
              Text(_message!, style: const TextStyle(color: Colors.green)),
            if (_me != null && !canManage) ...[
              const SizedBox(height: 12),
              Text(
                'Suas etapas autorizadas: ${_names(_me!['stages'] as List)}',
              ),
              const Text('Solicite ao administrador alterações no seu acesso.'),
            ],
            if (canManage) ...[
              if (_directoryError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _directoryError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_directory != null)
                ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Usuários ativos do Protheus (${(_directory!['items'] as List).length})',
                  ),
                  subtitle: Text(
                    'Base ${_directory!['sourceDatabase']} · contas habilitadas no cadastro',
                  ),
                  children: [
                    Text(
                      'Consulta: ${DateTime.parse(_directory!['queriedAt'] as String).toLocal()}. A lista reflete a cópia disponível dessa base.',
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('flow-directory-search'),
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nome ou login',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => _search = value),
                    ),
                    if (directoryItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Nenhum usuário corresponde à busca.'),
                      )
                    else
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          itemCount: directoryItems.length,
                          itemBuilder: (context, index) {
                            final user = directoryItems[index];
                            return ListTile(
                              title: Text(user['name'] as String),
                              subtitle: Text(user['username'] as String),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _busy
                                  ? null
                                  : () => _consult(user['username'] as String),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              const Text(
                'Use o login exato do Protheus. O usuário precisa autenticar no ERP e ter um perfil de acesso ao app.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('flow-access-username'),
                controller: _username,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Login Protheus'),
                onChanged: (_) => setState(() {
                  _user = null;
                  _message = null;
                }),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _consult(),
                  child: const Text('Consultar usuário'),
                ),
              ),
              if (_users.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final user in _users)
                      ActionChip(
                        label: Text(
                          '${user['username']}${user['isAdmin'] == true ? ' · Administrador' : ''}',
                        ),
                        onPressed: _busy
                            ? null
                            : () => _consult(user['username'] as String),
                      ),
                  ],
                ),
              if (_user != null) ...[
                const Divider(),
                Text(
                  'Permissões de ${_user!['username']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (_user!['isAdmin'] == true)
                  const Text(
                    'Administrador: acesso a todas as etapas. Este perfil é gerenciado no servidor.',
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final entry in labels.entries)
                      FilterChip(
                        label: Text(entry.value),
                        selected: _stages.contains(entry.key),
                        onSelected: !editable
                            ? null
                            : (selected) => setState(() {
                                selected
                                    ? _stages.add(entry.key)
                                    : _stages.remove(entry.key);
                                _message = null;
                              }),
                      ),
                  ],
                ),
                if (_stages.isEmpty)
                  const Text(
                    'Sem etapas selecionadas: o usuário poderá consultar, mas não registrar execuções.',
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: editable ? _save : null,
                    child: const Text('Salvar permissões'),
                  ),
                ),
                if ((_user!['history'] as List? ?? []).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Histórico de permissões',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  for (final event in (_user!['history'] as List).take(10))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${event['actor']} · ${DateTime.parse(event['createdAt'] as String).toLocal()}\n${_names(event['before'] as List)} → ${_names(event['after'] as List)}',
                      ),
                    ),
                ],
              ],
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Atualizar acessos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
