import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/repositories/api_settings.dart';

class ProtheusHealth {
  const ProtheusHealth({
    required this.ok,
    required this.database,
    required this.company,
    required this.readOnly,
    required this.applying,
  });

  final bool ok;
  final String database;
  final String company;
  final bool readOnly;
  final bool applying;

  factory ProtheusHealth.fromJson(Map<String, dynamic> json) {
    return ProtheusHealth(
      ok: json['ok'] == true,
      database: json['banco']?.toString().trim() ?? '',
      company: json['empresa']?.toString().trim() ?? '',
      readOnly: json['readOnly'] != false,
      applying: json['aplicando'] == true,
    );
  }
}

class MutationResult {
  const MutationResult({
    required this.id,
    required this.status,
    this.protheusRef,
    this.erro,
  });

  final String id;
  final MutationStatus status;
  final String? protheusRef;
  final String? erro;

  factory MutationResult.fromJson(Map<String, dynamic> json) => MutationResult(
    id: json['id'] as String? ?? '',
    status: MutationStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => MutationStatus.erro,
    ),
    protheusRef: json['protheusRef'] as String?,
    erro: json['erro'] as String?,
  );
}

class SyncUnavailableException implements Exception {
  const SyncUnavailableException(this.motivo);

  final String motivo;

  @override
  String toString() => 'API do Protheus indisponivel: $motivo';
}

class ProtheusSyncClient {
  ProtheusSyncClient({
    required this.baseUrl,
    this.apiToken = '',
    http.Client? httpClient,
  }) : _http = httpClient ?? ApiSettings.createClient();

  final String baseUrl;
  final String apiToken;
  final http.Client _http;

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers({bool json = false}) {
    final token = apiToken.trim().isNotEmpty
        ? apiToken.trim()
        : ApiSettings.token;
    return {
      if (json) 'Content-Type': 'application/json',
      if (token.isNotEmpty) 'X-API-Token': token,
    };
  }

  Future<bool> health() async {
    final info = await healthInfo();
    return info.ok;
  }

  Future<ProtheusHealth> healthInfo() async {
    try {
      final response = await _http
          .get(_uri('/api/v1/health'), headers: _headers())
          .timeout(_timeout);
      if (response.statusCode != 200) {
        return const ProtheusHealth(
          ok: false,
          database: '',
          company: '',
          readOnly: true,
          applying: false,
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ProtheusHealth.fromJson(body);
    } catch (_) {
      return const ProtheusHealth(
        ok: false,
        database: '',
        company: '',
        readOnly: true,
        applying: false,
      );
    }
  }

  Future<List<MutationResult>> push(List<PendingMutation> mutations) async {
    if (mutations.isEmpty) return const [];
    return [
      for (final mutation in mutations)
        MutationResult(
          id: mutation.id,
          status: MutationStatus.erro,
          erro: 'Protheus em modo somente leitura. Nenhum dado foi enviado.',
        ),
    ];
  }

  Future<List<MutationResult>> finalizar(List<String> ids) async {
    if (ids.isEmpty) return const [];
    return [
      for (final id in ids)
        MutationResult(
          id: id,
          status: MutationStatus.erro,
          erro: 'Protheus em modo somente leitura. Nenhum dado foi aplicado.',
        ),
    ];
  }

  void dispose() => _http.close();
}
