import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vetti_flow_1_0/data/repositories/api_settings.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart';

class WarehouseReadSnapshot {
  WarehouseReadSnapshot(Map<String, dynamic> json)
    : items = _rows(json['items']),
      summary = _rows(json['summary']),
      total = (json['total'] as num?)?.toInt() ?? 0,
      asOf = DateTime.tryParse('${json['asOf'] ?? ''}')?.toLocal(),
      latestMovement = '${json['latestMovement'] ?? ''}',
      databaseLatestRecord = '${json['databaseLatestRecord'] ?? ''}',
      databaseFirstRecord = '${json['databaseFirstRecord'] ?? ''}',
      database = '${json['database'] ?? ''}';

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> summary;
  final int total;
  final DateTime? asOf;
  final String latestMovement;
  final String databaseLatestRecord;
  final String databaseFirstRecord;
  final String database;

  static List<Map<String, dynamic>> _rows(dynamic value) =>
      (value as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
}

/// Consultas apenas. Este repositório não possui métodos de gravação.
class WarehouseReadRepository {
  WarehouseReadRepository({
    required String baseUrl,
    this.apiToken = '',
    http.Client? httpClient,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _http = httpClient ?? http.Client();

  final String baseUrl;
  final String apiToken;
  final http.Client _http;

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 40),
  }) async {
    final token = apiToken.isEmpty ? ApiSettings.token : apiToken;
    final response = await _http
        .get(
          Uri.parse('$baseUrl$path').replace(queryParameters: params),
          headers: {if (token.isNotEmpty) 'X-API-Token': token},
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw StateError(
        response.statusCode == 401
            ? 'Acesso à consulta não autorizado.'
            : 'Não foi possível consultar o Protheus.',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<WarehouseReadSnapshot> fetch({
    String view = 'overview',
    bool production = false,
    bool support = false,
    bool expedition = false,
    String filial = '04',
    String local = '01',
    DateTime? start,
    DateTime? end,
    String query = '',
    String kind = 'all',
    String status = 'all',
    int page = 1,
    int pageSize = 50,
  }) async {
    return WarehouseReadSnapshot(
      await _get(
        expedition
            ? '/api/v1/expedicao'
            : support
            ? '/api/v1/suporte'
            : production
            ? '/api/v1/producao'
            : '/api/v1/almoxarifado',
        {
          'view': view,
          'filial': filial,
          'local': local,
          'query': query,
          'kind': kind,
          'status': status,
          'page': '$page',
          'page_size': '$pageSize',
          if (start != null) 'start': _date(start),
          if (end != null) 'end': _date(end),
        },
      ),
    );
  }

  Future<Map<String, dynamic>> orderDetails(
    String op, {
    String filial = '04',
  }) => _get('/api/v1/ops/${Uri.encodeComponent(op)}/movimentos', {
    'filial': filial,
  });

  void close() => _http.close();
  Future<WarehouseReport> report(
    ReportFilters filters, {
    ReportSector sector = ReportSector.warehouse,
  }) async => WarehouseReport(
    await _get(
      '/api/v1/relatorios/${sector.key}',
      filters.toQuery(),
      timeout: const Duration(seconds: 90),
    ),
  );
  Future<Map<String, dynamic>> dispatchNoteDetails(
    String id, {
    String filial = '04',
  }) {
    final recno = int.parse(id.split(':').last);
    return _get('/api/v1/expedicao/notas/$recno', {'filial': filial});
  }

  Future<Map<String, dynamic>> relatedMovements(
    String id, {
    String filial = '04',
  }) {
    final recno = int.parse(id.split(':').last);
    return _get('/api/v1/almoxarifado/movimentos/$recno', {'filial': filial});
  }

  static String _date(DateTime date) => date.toIso8601String().substring(0, 10);
}
