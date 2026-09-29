import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vetti_flow_1_0/data/models/protheus_inventory_audit.dart';
import 'package:vetti_flow_1_0/data/repositories/api_settings.dart';

abstract class ProtheusInventoryAuditRepository {
  Future<ProtheusInventoryAuditSnapshot> fetchAuditMovements({
    String filial = '04',
    String documento = '',
    String op = '',
    String produto = '',
    String tipo = '',
    int limit = 50,
  });
}

class EmptyProtheusInventoryAuditRepository
    implements ProtheusInventoryAuditRepository {
  const EmptyProtheusInventoryAuditRepository();

  @override
  Future<ProtheusInventoryAuditSnapshot> fetchAuditMovements({
    String filial = '04',
    String documento = '',
    String op = '',
    String produto = '',
    String tipo = '',
    int limit = 50,
  }) async {
    return ProtheusInventoryAuditSnapshot(filial: filial);
  }
}

class ApiProtheusInventoryAuditRepository
    implements ProtheusInventoryAuditRepository {
  ApiProtheusInventoryAuditRepository({
    required String baseUrl,
    this.apiToken = '',
    http.Client? httpClient,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _http = httpClient ?? ApiSettings.createClient();

  final String baseUrl;
  final String apiToken;
  final http.Client _http;

  static const _timeout = Duration(seconds: 12);

  @override
  Future<ProtheusInventoryAuditSnapshot> fetchAuditMovements({
    String filial = '04',
    String documento = '',
    String op = '',
    String produto = '',
    String tipo = '',
    int limit = 50,
  }) async {
    final query = {
      'filial': filial,
      'limit': '$limit',
      if (documento.trim().isNotEmpty) 'documento': documento.trim(),
      if (op.trim().isNotEmpty) 'op': op.trim(),
      if (produto.trim().isNotEmpty) 'produto': produto.trim(),
      if (tipo.trim().isNotEmpty) 'tipo': tipo.trim(),
    };
    final response = await _http
        .get(_uri('/api/v1/auditoria-estoque', query), headers: _headers())
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ProtheusInventoryAuditSnapshot.fromJson(json);
    }
    throw StateError(
      'API Protheus HTTP ${response.statusCode}: ${response.body}',
    );
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Map<String, String> _headers() {
    final token = apiToken.trim().isNotEmpty
        ? apiToken.trim()
        : ApiSettings.token;
    return {if (token.isNotEmpty) 'X-API-Token': token};
  }
}
