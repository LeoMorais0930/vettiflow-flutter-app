import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'api_settings.dart';

class FlowTrackingException implements Exception {
  const FlowTrackingException(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class FlowTrackingRepository {
  FlowTrackingRepository({
    http.Client? client,
    this.baseUrl = ApiSettings.baseUrl,
  }) : _client = client ?? ApiSettings.createClient();
  final http.Client _client;
  final String baseUrl;
  Future<Map<String, dynamic>> read(Map<String, String> key) async => _decode(
    await _client
        .get(
          Uri.parse('$baseUrl/api/v1/flow/order').replace(queryParameters: key),
        )
        .timeout(const Duration(seconds: 45)),
  );
  Future<Map<String, dynamic>> send(Map<String, dynamic> command) async =>
      _decode(
        await _client
            .post(
              Uri.parse('$baseUrl/api/v1/flow/events'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(command),
            )
            .timeout(const Duration(seconds: 45)),
      );
  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode != 200) {
      String message = 'Não foi possível confirmar o apontamento.';
      try {
        final detail =
            (jsonDecode(utf8.decode(response.bodyBytes)) as Map)['detail'];
        if (detail is String) message = detail;
      } catch (_) {}
      throw FlowTrackingException(message, response.statusCode);
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  static String requestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final value = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
  }

  void close() => _client.close();
}
