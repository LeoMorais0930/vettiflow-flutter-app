import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vetti_flow_1_0/data/models/protheus_op_movements.dart';
import 'package:vetti_flow_1_0/data/repositories/api_settings.dart';

abstract class ProtheusOpMovementRepository {
  Future<ProtheusOpSnapshot> fetchSnapshot(String op, {String filial = '04'});
}

class EmptyProtheusOpMovementRepository
    implements ProtheusOpMovementRepository {
  const EmptyProtheusOpMovementRepository();

  @override
  Future<ProtheusOpSnapshot> fetchSnapshot(
    String op, {
    String filial = '04',
  }) async {
    return ProtheusOpSnapshot(
      op: op.trim(),
      filial: filial,
      statusOficial: 'nao_encontrada',
    );
  }
}

class ApiProtheusOpMovementRepository implements ProtheusOpMovementRepository {
  ApiProtheusOpMovementRepository({
    required String baseUrl,
    this.apiToken = '',
    http.Client? httpClient,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _http = httpClient ?? http.Client();

  final String baseUrl;
  final String apiToken;
  final http.Client _http;

  static const _timeout = Duration(seconds: 12);

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

  @override
  Future<ProtheusOpSnapshot> fetchSnapshot(
    String op, {
    String filial = '04',
  }) async {
    final normalized = op.trim().toUpperCase();
    if (normalized.isEmpty) {
      return ProtheusOpSnapshot(
        op: '',
        filial: filial,
        statusOficial: 'nao_encontrada',
      );
    }

    final response = await _http
        .get(
          _uri('/api/v1/ops/$normalized/movimentos', {'filial': filial}),
          headers: _headers(),
        )
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ProtheusOpSnapshot.fromJson(json);
    }
    throw StateError(
      'API Protheus HTTP ${response.statusCode}: ${response.body}',
    );
  }
}
