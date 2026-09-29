import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_settings.dart';
import 'flow_tracking_repository.dart';

class FlowAccessRepository {
  FlowAccessRepository({
    http.Client? client,
    this.baseUrl = ApiSettings.baseUrl,
  }) : _client = client ?? ApiSettings.createClient();
  final http.Client _client;
  final String baseUrl;
  Uri _uri(String path) => Uri.parse('$baseUrl/api/v1/flow/access/$path');
  Future<Map<String, dynamic>> _get(String path) async => _decode(
    await _client.get(_uri(path)).timeout(const Duration(seconds: 45)),
  );
  Future<Map<String, dynamic>> me() => _get('me');
  Future<Map<String, dynamic>> users() => _get('users');
  Future<Map<String, dynamic>> directory() => _get('directory');
  Future<Map<String, dynamic>> read(String username) =>
      _get('users/${Uri.encodeComponent(username)}');
  Future<Map<String, dynamic>> save(
    String username,
    List<String> stages,
    int version,
  ) async => _decode(
    await _client
        .put(
          _uri('users/${Uri.encodeComponent(username)}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'stages': stages, 'expectedVersion': version}),
        )
        .timeout(const Duration(seconds: 45)),
  );
  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode != 200) {
      var message =
          'Não foi possível confirmar as permissões. Consulte novamente antes de salvar.';
      try {
        final detail =
            (jsonDecode(utf8.decode(response.bodyBytes)) as Map)['detail'];
        if (detail is String) message = detail;
      } catch (_) {}
      throw FlowTrackingException(message, response.statusCode);
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  void close() => _client.close();
}
