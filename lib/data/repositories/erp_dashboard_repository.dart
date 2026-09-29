import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ordem_producao.dart';
import '../models/flow_execution.dart';
import '../models/production_flow.dart';
import 'api_settings.dart';
import 'flow_op_repository.dart';

/// OPs do ERP são consultadas; rascunhos locais mantêm seu fluxo separado.
class ErpDashboardRepository extends FlowOpRepository {
  ErpDashboardRepository(
    super.store, {
    required this.baseUrl,
    http.Client? client,
    super.protheusProducts,
    super.warehouseRequests,
  }) : _client = client ?? ApiSettings.createClient();
  final String baseUrl;
  final http.Client _client;
  final Set<String> _erpIds = {};

  @override
  Future<List<OrdemProducao>> fetchOrdens() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/api/v1/ops/abertas?filial=04'))
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw StateError('Não foi possível consultar as OPs do Protheus.');
    }
    final rows = jsonDecode(utf8.decode(response.bodyBytes)) as List;
    var cursor = 0;
    while (true) {
      final closedResponse = await _client
          .get(
            Uri.parse(
              '$baseUrl/api/v1/ops/encerradas?filial=04&after=$cursor&page_size=2000',
            ),
          )
          .timeout(const Duration(seconds: 45));
      if (closedResponse.statusCode != 200) {
        throw StateError(
          'Não foi possível consultar o histórico de OPs encerradas.',
        );
      }
      final page =
          jsonDecode(utf8.decode(closedResponse.bodyBytes))
              as Map<String, dynamic>;
      rows.addAll(page['items'] as List);
      final next = page['nextCursor'];
      if (next == null) break;
      if (next is! int || next <= cursor) {
        throw StateError('Paginação inválida no histórico de OPs.');
      }
      cursor = next;
    }
    final remote = rows.map((value) {
      final row = value as Map;
      final number =
          '${row['numero']}${row['item']}${row['sequencia']}${row['itemGrade'] ?? ''}'
              .trim();
      final quantity = row['quantidade'] as num;
      final produced = (row['produzida'] as num?) ?? 0;
      final closed = row['encerrada'] == true;
      final completed =
          closed ||
          ('${row['local'] ?? ''}'.trim() == '10' &&
              quantity > 0 &&
              produced >= quantity &&
              row['materiaisPendentes'] == 0);
      return OrdemProducao(
        numero: number,
        produto: '${row['produto']}',
        qtd: quantity,
        responsavel: 'Protheus · consulta',
        dataAbertura: '${row['emissao'] ?? ''}',
        prazo: '${row['previsao'] ?? ''}',
        status: completed
            ? StatusOP.finalizada
            : produced > 0
            ? StatusOP.emAndamento
            : StatusOP.naoIniciada,
        progresso: quantity > 0
            ? (produced / quantity * 100).round().clamp(0, 100)
            : 0,
        mes: _month('${row['emissao'] ?? ''}'),
        armazem: '${row['local'] ?? ''}',
        erpReadOnly: true,
        erpKey: Map.unmodifiable({
          'filial': '${row['filial'] ?? '04'}'.trim(),
          'numero': '${row['numero']}'.trim(),
          'item': '${row['item']}'.trim(),
          'sequencia': '${row['sequencia']}'.trim(),
          'grade': '${row['itemGrade'] ?? ''}'.trim(),
        }),
        encerradaNoErp: closed,
        dataEncerramento: '${row['encerramento'] ?? ''}',
        observacao: closed
            ? 'Encerrada no Protheus em ${row['encerramento'] ?? 'data não informada'}. Registro oficial de encerramento; quantidade produzida $produced de $quantity.'
            : completed
            ? 'Concluída no painel: produção atendida na Expedição, sem materiais pendentes. MOD tratado separadamente. OP não encerrada no ERP.'
            : 'OP do Protheus. Materiais pendentes: ${row['materiaisPendentes'] ?? 'não verificado'}. MOD pendente: ${row['modPendente'] ?? 'não verificado'}.',
      );
    }).toList();
    _erpIds.addAll(remote.map((o) => o.numero));
    final executionResponse = await _client
        .get(Uri.parse('$baseUrl/api/v1/flow/states'))
        .timeout(const Duration(seconds: 45));
    if (executionResponse.statusCode != 200) {
      throw StateError('Não foi possível atualizar a execução das etapas.');
    }
    final executionRows =
        (jsonDecode(utf8.decode(executionResponse.bodyBytes)) as Map)['items']
            as List;
    final executions = {
      for (final row in executionRows)
        FlowExecution.identity(Map<String, String>.from(row['key'] as Map)):
            FlowExecution.fromJson(Map<String, dynamic>.from(row as Map)),
    };
    final local = await super.fetchOrdens();
    final uniqueRemote = {
      for (final op in remote)
        op.numero:
            executions[FlowExecution.identity(op.erpKey!)]?.matches(op) == true
            ? op.copyWith(
                execution: executions[FlowExecution.identity(op.erpKey!)],
              )
            : op,
    };
    return [
      ...uniqueRemote.values,
      ...local.where((o) => !_erpIds.contains(o.numero)),
    ];
  }

  void _allowLocal(String number) {
    if (_erpIds.contains(number)) {
      throw StateError('OP do Protheus disponível somente para consulta.');
    }
  }

  @override
  Future<void> avancarStatus(
    String numero, {
    int quantidadeArmazenada = 0,
    String? operatorName,
    String? operatorPin,
  }) async {
    _allowLocal(numero);
    await super.avancarStatus(
      numero,
      quantidadeArmazenada: quantidadeArmazenada,
      operatorName: operatorName,
      operatorPin: operatorPin,
    );
  }

  @override
  Future<void> voltarStatus(String numero) async {
    _allowLocal(numero);
    await super.voltarStatus(numero);
  }

  @override
  Future<void> atualizarRota(
    String numero,
    List<ProductionStage> stages,
  ) async {
    _allowLocal(numero);
    await super.atualizarRota(numero, stages);
  }

  @override
  Future<void> cancelarOrdem(
    String numero, {
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) async {
    _allowLocal(numero);
    await super.cancelarOrdem(
      numero,
      returnWarehouses: returnWarehouses,
      operatorName: operatorName,
      operatorPin: operatorPin,
    );
  }

  static String _month(String date) {
    final parts = date.split('/');
    final month = parts.length == 3 ? int.tryParse(parts[1]) : null;
    if (month == null || month < 1 || month > 12) return '';
    return const [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ][month - 1];
  }

  void close() => _client.close();
}
