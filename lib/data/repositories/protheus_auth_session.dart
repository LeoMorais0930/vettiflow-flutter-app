import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Senha não é retida; JWT permanece somente em memória.
class ProtheusAuthSession extends ChangeNotifier {
  ProtheusAuthSession({
    required this.baseUrl,
    this.apiKey = '',
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String baseUrl, apiKey;
  final http.Client _client;
  String? _token, username;
  DateTime? expiresAt;
  Timer? _timer, _refreshTimer;
  Future<void>? _refreshing;
  bool _canRefresh = false;
  int _generation = 0;
  bool _disposed = false;
  String? message;

  bool get isAuthenticated =>
      _token != null &&
      expiresAt != null &&
      DateTime.now().isBefore(expiresAt!);
  Map<String, String> get _keyHeaders => {
    if (apiKey.isNotEmpty) 'X-API-Token': apiKey,
  };
  bool get _safeTransport {
    final uri = Uri.parse(baseUrl);
    return uri.userInfo.isEmpty &&
        (uri.scheme == 'https' ||
            uri.scheme == 'http' &&
                const ['localhost', '127.0.0.1', '::1'].contains(uri.host));
  }

  Future<http.Response> _post(String path, Map<String, String> headers) async {
    final request = http.Request('POST', Uri.parse('$baseUrl$path'))
      ..followRedirects = false
      ..headers.addAll(headers);
    return http.Response.fromStream(await _client.send(request));
  }

  Future<void> login(String user, String password) async {
    clear();
    final generation = _generation;
    if (!_safeTransport) {
      throw const AuthException(
        'Configure HTTPS para acessar a API fora deste computador.',
      );
    }
    try {
      Future<http.Response> attempt() => _post('/api/v1/auth/protheus/login', {
        ..._keyHeaders,
        'username': user.trim(),
        'password': password,
      }).timeout(const Duration(seconds: 45));
      var response = await attempt();
      if (response.statusCode == 503) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (_disposed || generation != _generation) return;
        response = await attempt();
      }
      if (response.statusCode != 200) {
        throw AuthException(
          response.statusCode == 401 || response.statusCode == 403
              ? 'Acesso recusado. Confira o usuário, a senha Protheus e a chave da API.'
              : response.statusCode == 503
              ? 'A validação no Protheus está temporariamente indisponível. Aguarde e tente entrar novamente.'
              : 'O Protheus não confirmou o login. Tente novamente ou confira a conexão.',
        );
      }
      _accept(jsonDecode(response.body) as Map<String, dynamic>, generation);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Não foi possível conectar ao Protheus. Confira a API e tente novamente.',
      );
    }
  }

  void _accept(Map<String, dynamic> data, int generation) {
    final token = data['access_token'];
    final seconds = data['expiresAt'];
    final identity = data['username'];
    if (token is! String ||
        token.isEmpty ||
        seconds is! num ||
        !seconds.isFinite ||
        identity is! String ||
        identity.isEmpty ||
        data['token_type'] != 'Bearer') {
      throw const AuthException('Resposta de login inválida.');
    }
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      (seconds * 1000).floor(),
    );
    if (!expiry.isAfter(DateTime.now())) {
      throw const AuthException('A sessão retornada já expirou.');
    }
    if (_disposed || generation != _generation) return;
    _token = token;
    username = identity;
    expiresAt = expiry;
    _timer?.cancel();
    _refreshTimer?.cancel();
    _timer = Timer(
      expiry.difference(DateTime.now()),
      () => clear('Sua sessão expirou. Entre novamente.'),
    );
    _canRefresh = data['refreshAvailable'] == true;
    if (_canRefresh) {
      final delay =
          expiry.difference(DateTime.now()) - const Duration(seconds: 60);
      _refreshTimer = Timer(
        delay.isNegative ? const Duration(seconds: 1) : delay,
        refresh,
      );
    }
    notifyListeners();
  }

  Future<void> refresh() {
    if (_refreshing != null) return _refreshing!;
    if (!_canRefresh || !isAuthenticated) return Future.value();
    final future = _renew();
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
  }

  Future<void> _renew() async {
    final generation = _generation;
    final token = _token;
    try {
      final response = await _post('/api/v1/auth/protheus/refresh', {
        ..._keyHeaders,
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 45));
      if (_disposed || generation != _generation) {
        if (response.statusCode == 200) {
          final lateToken = (jsonDecode(response.body) as Map)['access_token'];
          if (lateToken is String) await _revokeRemote(lateToken);
        }
        return;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        clear('Sua sessão foi encerrada. Entre novamente.');
        return;
      }
      if (response.statusCode != 200) {
        throw const AuthException('Renovação indisponível.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['username'] != username) {
        throw const AuthException('Identidade inesperada.');
      }
      _accept(data, generation);
    } catch (_) {
      // Mantém somente o prazo já autorizado; indisponibilidade não amplia a sessão.
      if (!_disposed && generation == _generation && isAuthenticated) {
        _refreshTimer = Timer(const Duration(seconds: 15), refresh);
      }
    }
  }

  Future<void> logout() async {
    final token = _token;
    clear();
    if (token == null) return;
    await _revokeRemote(token);
  }

  Future<void> _revokeRemote(String token) async {
    try {
      await _post('/api/v1/auth/protheus/logout', {
        ..._keyHeaders,
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 25));
    } catch (_) {
      // Logout local prevalece mesmo sem rede; servidor mantém seu prazo limitado.
    }
  }

  void clear([String? reason]) {
    _generation++;
    _timer?.cancel();
    _refreshTimer?.cancel();
    _canRefresh = false;
    _token = null;
    username = null;
    expiresAt = null;
    message = reason;
    if (!_disposed) notifyListeners();
  }

  http.Client createClient({http.Client? inner}) =>
      _SessionClient(this, inner ?? http.Client());
  @override
  void dispose() {
    _disposed = true;
    clear();
    _client.close();
    super.dispose();
  }
}

class _SessionClient extends http.BaseClient {
  _SessionClient(this.auth, this.inner);
  final ProtheusAuthSession auth;
  final http.Client inner;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _send(request, true);

  Future<http.StreamedResponse> _send(
    http.BaseRequest request,
    bool canRetry,
  ) async {
    if (request.url.origin != Uri.parse(auth.baseUrl).origin ||
        !auth._safeTransport) {
      throw const AuthException('Destino da API não autorizado.');
    }
    await auth._refreshing;
    if (!auth.isAuthenticated) {
      auth.clear('Entre novamente para continuar.');
      throw const AuthException('Sessão ausente ou expirada.');
    }
    final token = auth._token;
    request.headers.addAll({
      ...auth._keyHeaders,
      'Authorization': 'Bearer $token',
    });
    request.followRedirects = false;
    final response = await inner.send(request);
    if (canRetry && request.method == 'GET' && response.statusCode == 503) {
      await response.stream.drain<void>();
      await Future<void>.delayed(const Duration(seconds: 1));
      final retry = http.Request('GET', request.url)
        ..headers.addAll(request.headers);
      return _send(retry, false);
    }
    if (response.statusCode == 401 && auth._token == token) {
      auth.clear('Sua sessão foi encerrada. Entre novamente.');
    }
    return response;
  }

  @override
  void close() => inner.close();
}
