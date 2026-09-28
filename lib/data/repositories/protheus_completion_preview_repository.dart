import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vetti_flow_1_0/data/models/protheus_completion_preview.dart';
import 'package:vetti_flow_1_0/data/repositories/api_settings.dart';

abstract class ProtheusCompletionPreviewRepository {
  Future<ProtheusCompletionPreviewSnapshot> fetchPreview(
    String op, {
    String filial = '04',
    num? quantidade,
    String? armazem,
  });
}

class EmptyProtheusCompletionPreviewRepository
    implements ProtheusCompletionPreviewRepository {
  const EmptyProtheusCompletionPreviewRepository();

  @override
  Future<ProtheusCompletionPreviewSnapshot> fetchPreview(
    String op, {
    String filial = '04',
    num? quantidade,
    String? armazem,
  }) async {
    return ProtheusCompletionPreviewSnapshot(
      op: op.trim(),
      filial: filial,
      readOnly: true,
      rotinaStatus: 'pendente_pesquisa',
      quantidadeSolicitada: quantidade ?? 0,
      quantidadeRestante: 0,
    );
  }
}

class ApiProtheusCompletionPreviewRepository
    implements ProtheusCompletionPreviewRepository {
  ApiProtheusCompletionPreviewRepository({
    required String baseUrl,
    this.apiToken = '',
    http.Client? httpClient,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _http = httpClient ?? http.Client();

  final String baseUrl;
  final String apiToken;
  final http.Client _http;

  static const _timeout = Duration(seconds: 12);

  @override
  Future<ProtheusCompletionPreviewSnapshot> fetchPreview(
    String op, {
    String filial = '04',
    num? quantidade,
    String? armazem,
  }) async {
    final normalized = op.trim().toUpperCase();
    if (normalized.isEmpty) {
      return ProtheusCompletionPreviewSnapshot(
        op: '',
        filial: filial,
        readOnly: true,
        rotinaStatus: 'pendente_pesquisa',
        quantidadeSolicitada: quantidade ?? 0,
        quantidadeRestante: 0,
      );
    }

    final query = {
      'filial': filial,
      if (quantidade != null) 'quantidade': '$quantidade',
      if (armazem != null && armazem.trim().isNotEmpty)
        'armazem': armazem.trim().toUpperCase(),
    };
    final response = await _http
        .get(
          _uri('/api/v1/ops/$normalized/apontamento-preview', query),
          headers: _headers(),
        )
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ProtheusCompletionPreviewSnapshot.fromJson(json);
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
