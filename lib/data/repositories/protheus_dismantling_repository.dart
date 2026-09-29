import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vetti_flow_1_0/data/models/protheus_dismantlings.dart';
import 'package:vetti_flow_1_0/data/repositories/api_settings.dart';

abstract class ProtheusDismantlingRepository {
  Future<ProtheusDismantlingSnapshot> fetchDismantlings({
    String filial = '04',
    String documento = '',
    String produto = '',
    int limit = 20,
  });
}

class EmptyProtheusDismantlingRepository
    implements ProtheusDismantlingRepository {
  const EmptyProtheusDismantlingRepository();

  @override
  Future<ProtheusDismantlingSnapshot> fetchDismantlings({
    String filial = '04',
    String documento = '',
    String produto = '',
    int limit = 20,
  }) async {
    return ProtheusDismantlingSnapshot(filial: filial);
  }
}

class ApiProtheusDismantlingRepository
    implements ProtheusDismantlingRepository {
  ApiProtheusDismantlingRepository({
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
  Future<ProtheusDismantlingSnapshot> fetchDismantlings({
    String filial = '04',
    String documento = '',
    String produto = '',
    int limit = 20,
  }) async {
    final query = {
      'filial': filial,
      'limit': '$limit',
      if (documento.trim().isNotEmpty) 'documento': documento.trim(),
      if (produto.trim().isNotEmpty) 'produto': produto.trim(),
    };
    final response = await _http
        .get(_uri('/api/v1/desmontagens', query), headers: _headers())
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ProtheusDismantlingSnapshot.fromJson(json);
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
