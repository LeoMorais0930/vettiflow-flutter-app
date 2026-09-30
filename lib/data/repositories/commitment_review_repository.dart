import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_settings.dart';

class CommitmentReviewRepository {
  CommitmentReviewRepository({
    http.Client? client,
    this.baseUrl = ApiSettings.baseUrl,
  }) : _client = client ?? ApiSettings.createClient();
  final http.Client _client;
  final String baseUrl;
  Uri _uri(String op, String filial) => Uri.parse(
    '$baseUrl/api/v1/ops/${Uri.encodeComponent(op)}/revisao-empenhos',
  ).replace(queryParameters: {'filial': filial});
  Future<Map<String, dynamic>> load(String op, String filial) async => _decode(
    await _client.get(_uri(op, filial)).timeout(const Duration(seconds: 45)),
  );
  Future<Map<String, dynamic>> save(
    String op,
    String filial,
    Map<String, dynamic> body,
  ) async => _decode(
    await _client
        .put(
          _uri(op, filial),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45)),
  );
  Future<Map<String, dynamic>> submit(
    String op,
    String filial,
    Map<String, dynamic> body,
  ) async {
    final uri = _uri(op, filial);
    return _decode(
      await _client
          .post(
            uri.replace(path: '${uri.path}/enviar'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45)),
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError(
        data['detail'] is String
            ? data['detail'] as String
            : 'Não foi possível salvar a revisão.',
      );
    }
    return data;
  }

  void close() => _client.close();
}
