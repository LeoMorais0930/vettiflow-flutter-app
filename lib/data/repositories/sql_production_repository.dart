import 'dart:convert';
import 'package:http/http.dart' as http;
import 'local_json_persistence.dart';

class SqlProductionException implements Exception {
  const SqlProductionException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Only explicit commands use this client. It never consumes the old queue.
class SqlProductionRepository {
  SqlProductionRepository({
    required this.baseUrl,
    this.apiToken = '',
    http.Client? client,
    this.persistence,
  }) : _client = client ?? http.Client() {
    try {
      final raw = persistence?.read();
      if (raw != null && raw.isNotEmpty) {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        _pending = (saved['pending'] as Map?)?.cast<String, dynamic>();
        _results.addAll(
          (saved['results'] as Map? ?? {}).map(
            (key, value) => MapEntry(
              key.toString(),
              (value as Map).cast<String, dynamic>(),
            ),
          ),
        );
      }
    } catch (_) {
      _storageError = true;
    }
  }

  final String baseUrl, apiToken;
  final http.Client _client;
  final LocalJsonPersistence? persistence;
  Map<String, dynamic>? _pending;
  final _results = <String, Map<String, dynamic>>{};
  bool _storageError = false;
  Map<String, dynamic>? get pending =>
      _pending == null ? null : Map.of(_pending!);
  Map<String, dynamic>? savedResult(String id) => _results[id];

  void _save() {
    if (_storageError) {
      throw const SqlProductionException(
        'O histórico local de envios não pôde ser lido. Consulte os pedidos antes de gravar novamente.',
      );
    }
    final encoded = jsonEncode({'pending': _pending, 'results': _results});
    persistence?.write(encoded);
    if (persistence != null && persistence!.read() != encoded) {
      throw const SqlProductionException(
        'Não foi possível salvar o pedido localmente. O envio foi interrompido; preserve este identificador.',
      );
    }
  }

  Uri _uri(String path) => Uri.parse(
    '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/api/v1/dev/producao-sql/$path',
  );
  Map<String, String> _headers([String? writeKey]) => {
    'Content-Type': 'application/json',
    if (apiToken.isNotEmpty) 'X-API-Token': apiToken,
    'X-VettiFlow-Write-Key': ?writeKey,
  };

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data;
    try {
      data = (jsonDecode(utf8.decode(response.bodyBytes)) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      throw const SqlProductionException(
        'Resposta inválida. Consulte o identificador antes de reenviar.',
      );
    }
    if (response.statusCode != 200) {
      throw SqlProductionException(
        data['detail'] is String
            ? data['detail'] as String
            : 'Confira os campos da operação.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> status() async => _decode(
    await _client
        .get(_uri('status'), headers: _headers())
        .timeout(const Duration(seconds: 15)),
  );

  Future<Map<String, dynamic>> send(
    Map<String, dynamic> body, {
    required String writeKey,
    bool preview = false,
  }) async {
    final wasPending = _pending != null;
    if (_pending != null && jsonEncode(_pending) != jsonEncode(body)) {
      throw const SqlProductionException(
        'Há um pedido pendente. Consulte ou repita exatamente aquele pedido.',
      );
    }
    if (!preview) {
      _pending = Map.of(body);
      _save(); // Persist request BEFORE network; never save the write credential.
    }
    Map<String, dynamic> data;
    try {
      data = _decode(
        await _client
            .post(
              _uri('comandos'),
              headers: _headers(writeKey),
              body: jsonEncode({...body, 'simular': preview}),
            )
            .timeout(const Duration(seconds: 60)),
      );
    } on SqlProductionException catch (error) {
      if (!preview &&
          !wasPending &&
          const [401, 409, 422].contains(error.statusCode)) {
        _pending = null;
        _save();
      }
      rethrow;
    }
    if (data['id'] != body['id'] ||
        !const ['previa', 'aplicada'].contains(data['status'])) {
      throw const SqlProductionException(
        'Resultado não confirmado para este pedido. Consulte o identificador.',
      );
    }
    if (data['status'] == 'aplicada') {
      _results[body['id'] as String] = data;
      _pending = null;
      _save();
    }
    return data;
  }

  Future<Map<String, dynamic>> consult(
    String id, {
    required String writeKey,
  }) async {
    final data = _decode(
      await _client
          .get(
            _uri('comandos/${Uri.encodeComponent(id)}'),
            headers: _headers(writeKey),
          )
          .timeout(const Duration(seconds: 15)),
    );
    if (data['id'] != id || data['status'] != 'aplicada') {
      throw const SqlProductionException(
        'Resposta não confirma a aplicação deste pedido.',
      );
    }
    _results[id] = data;
    if (_pending?['id'] == id) _pending = null;
    _save();
    return data;
  }

  void close() => _client.close();
}
