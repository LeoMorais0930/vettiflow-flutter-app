import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vetti_flow_1_0/data/models/protheus_transfers.dart';
import 'package:vetti_flow_1_0/data/repositories/api_settings.dart';

abstract class ProtheusTransferRepository {
  Future<ProtheusTransferSnapshot> fetchTransfers({
    String filial = '04',
    String produto = '',
    String localOrigem = '',
    String localDestino = '',
    int limit = 20,
  });
}

class EmptyProtheusTransferRepository implements ProtheusTransferRepository {
  const EmptyProtheusTransferRepository();

  @override
  Future<ProtheusTransferSnapshot> fetchTransfers({
    String filial = '04',
    String produto = '',
    String localOrigem = '',
    String localDestino = '',
    int limit = 20,
  }) async {
    return ProtheusTransferSnapshot(filial: filial);
  }
}

class ApiProtheusTransferRepository implements ProtheusTransferRepository {
  ApiProtheusTransferRepository({
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
  Future<ProtheusTransferSnapshot> fetchTransfers({
    String filial = '04',
    String produto = '',
    String localOrigem = '',
    String localDestino = '',
    int limit = 20,
  }) async {
    final query = {
      'filial': filial,
      'limit': '$limit',
      if (produto.trim().isNotEmpty) 'produto': produto.trim(),
      if (localOrigem.trim().isNotEmpty) 'localOrigem': localOrigem.trim(),
      if (localDestino.trim().isNotEmpty) 'localDestino': localDestino.trim(),
    };
    final response = await _http
        .get(_uri('/api/v1/transferencias', query), headers: _headers())
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ProtheusTransferSnapshot.fromJson(json);
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
