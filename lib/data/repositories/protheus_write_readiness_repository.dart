import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vetti_flow_1_0/data/models/protheus_write_readiness.dart';
import 'package:vetti_flow_1_0/data/repositories/api_settings.dart';

abstract class ProtheusWriteReadinessRepository {
  Future<ProtheusWriteReadinessSnapshot> fetchReadiness();
}

class EmptyProtheusWriteReadinessRepository
    implements ProtheusWriteReadinessRepository {
  const EmptyProtheusWriteReadinessRepository();

  @override
  Future<ProtheusWriteReadinessSnapshot> fetchReadiness() async {
    return const ProtheusWriteReadinessSnapshot(
      readOnly: true,
      writeEnabled: false,
      status: 'bloqueada_por_politica',
      database: '',
      blockedOperations: ['sql_direto'],
    );
  }
}

class ApiProtheusWriteReadinessRepository
    implements ProtheusWriteReadinessRepository {
  ApiProtheusWriteReadinessRepository({
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
  Future<ProtheusWriteReadinessSnapshot> fetchReadiness() async {
    final response = await _http
        .get(_uri('/api/v1/write-readiness'), headers: _headers())
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ProtheusWriteReadinessSnapshot.fromJson(json);
    }
    throw StateError(
      'API Protheus HTTP ${response.statusCode}: ${response.body}',
    );
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers() {
    final token = apiToken.trim().isNotEmpty
        ? apiToken.trim()
        : ApiSettings.token;
    return {if (token.isNotEmpty) 'X-API-Token': token};
  }
}
