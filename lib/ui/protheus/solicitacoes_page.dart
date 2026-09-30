import 'commitment_review_page.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/data/repositories/api_settings.dart';

/// A fila central é distinta dos rascunhos salvos neste navegador.
class SolicitacoesPage extends StatefulWidget {
  const SolicitacoesPage({super.key});
  @override
  State<SolicitacoesPage> createState() => _SolicitacoesPageState();
}

class _SolicitacoesPageState extends State<SolicitacoesPage> {
  final _client = ApiSettings.createClient();
  List<dynamic> _items = [];
  bool _loading = true;
  bool _enabled = false;
  bool _execution = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await _client
          .get(Uri.parse('${ApiSettings.baseUrl}/api/v1/solicitacoes-status'))
          .timeout(const Duration(seconds: 45));
      final response = await _client
          .get(Uri.parse('${ApiSettings.baseUrl}/api/v1/solicitacoes'))
          .timeout(const Duration(seconds: 45));
      if (status.statusCode != 200 || response.statusCode != 200) {
        throw StateError('Consulta indisponível');
      }
      final settings = jsonDecode(status.body) as Map;
      final items = jsonDecode(utf8.decode(response.bodyBytes)) as List;
      if (!mounted) return;
      setState(() {
        _items = items;
        _enabled = settings['enabled'] == true;
        _execution = settings['executionEnabled'] == true;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível consultar a fila. Confira sua sessão e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Minhas solicitações ADVPL'),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              ListTile(
                leading: Icon(
                  _execution ? Icons.info_outline : Icons.lock_outline,
                ),
                title: Text(
                  _enabled
                      ? 'Fila central de solicitações'
                      : 'Novas solicitações ainda não liberadas',
                ),
                subtitle: Text(
                  _execution
                      ? 'Acompanhe aqui o resultado confirmado no ERP.'
                      : 'Execução no Protheus bloqueada até homologar o ADVPL. Os rascunhos locais não são enviados automaticamente.',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!),
                ),
              Expanded(
                child: _items.isEmpty
                    ? const Center(
                        child: Text('Nenhuma solicitação para este usuário.'),
                      )
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index] as Map;
                          final payload = item['payload'] as Map;
                          return ListTile(
                            title: Text(
                              item['operacao'] == 'exclusao_empenhos'
                                  ? 'Empenhos da OP ${payload['op']} · ${(payload['excluded'] as List).length} exclusões'
                                  : '${payload['produto']} · ${payload['quantidade']} un',
                            ),
                            subtitle: Text(
                              '${item['id']}\n${item['mensagem'] ?? ''}',
                            ),
                            trailing:
                                item['status'] == 'aplicada' &&
                                    (item['protheusRefs'] as List? ?? [])
                                        .isNotEmpty
                                ? TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CommitmentReviewPage(
                                          op: '${(item['protheusRefs'] as List).first}',
                                        ),
                                      ),
                                    ),
                                    child: const Text('Revisar empenhos'),
                                  )
                                : Text('${item['status']}'),
                          );
                        },
                      ),
              ),
            ],
          ),
  );
}
