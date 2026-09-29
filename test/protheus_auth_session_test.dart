import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_auth_session.dart';

void main() {
  test(
    '503 retries reads once, preserves auth and never retries writes',
    () async {
      final auth = ProtheusAuthSession(
        baseUrl: 'http://localhost:8000',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'access_token': 'test',
              'token_type': 'Bearer',
              'username': 'user',
              'expiresAt': DateTime.now().millisecondsSinceEpoch / 1000 + 300,
            }),
            200,
          ),
        ),
      );
      addTearDown(auth.dispose);
      await auth.login('user', 'password');
      var reads = 0, writes = 0;
      final client = auth.createClient(
        inner: MockClient((r) async {
          if (r.method == 'POST') {
            writes++;
            return http.Response('{}', 503);
          }
          reads++;
          return http.Response('{}', reads == 1 ? 503 : 200);
        }),
      );
      addTearDown(client.close);
      final url = Uri.parse('http://localhost:8000/api/v1/ops/abertas');
      expect((await client.get(url)).statusCode, 200);
      expect(reads, 2);
      expect((await client.post(url)).statusCode, 503);
      expect(writes, 1);
      expect(auth.isAuthenticated, true);
    },
  );
  test('login retries temporary validation failure once', () async {
    var calls = 0;
    final auth = ProtheusAuthSession(
      baseUrl: 'http://localhost:8000',
      client: MockClient((r) async {
        calls++;
        return http.Response(
          jsonEncode({
            'access_token': 'test',
            'token_type': 'Bearer',
            'username': 'user',
            'expiresAt': DateTime.now().millisecondsSinceEpoch / 1000 + 300,
          }),
          calls == 1 ? 503 : 200,
        );
      }),
    );
    addTearDown(auth.dispose);
    await auth.login('user', 'password');
    expect(calls, 2);
    expect(auth.isAuthenticated, true);
  });

  testWidgets('session renews automatically before its five minute expiry', (
    tester,
  ) async {
    var renewals = 0;
    final backend = MockClient((request) async {
      if (request.url.path.endsWith('/refresh')) renewals++;
      return http.Response(
        jsonEncode({
          'access_token': 'token-$renewals',
          'token_type': 'Bearer',
          'username': 'user',
          'refreshAvailable': true,
          'expiresAt': DateTime.now().millisecondsSinceEpoch / 1000 + 300,
        }),
        200,
      );
    });
    final auth = ProtheusAuthSession(
      baseUrl: 'http://localhost:8000',
      client: backend,
    );
    await auth.login('user', 'password');
    await tester.pump(const Duration(minutes: 4, seconds: 1));
    await tester.pump();
    expect(renewals, 1);
    expect(auth.isAuthenticated, true);
    auth.dispose();
  });
  test(
    'refresh uses no password and subsequent requests use rotated bearer',
    () async {
      var refreshes = 0;
      final backend = MockClient((r) async {
        final refresh = r.url.path.endsWith('/refresh');
        if (refresh) {
          refreshes++;
          expect(r.headers['Authorization'], 'Bearer old');
          expect(r.headers.containsKey('password'), false);
        }
        return http.Response(
          jsonEncode({
            'access_token': refresh ? 'new' : 'old',
            'token_type': 'Bearer',
            'username': 'user',
            'refreshAvailable': true,
            'expiresAt': DateTime.now().millisecondsSinceEpoch / 1000 + 300,
          }),
          200,
        );
      });
      final auth = ProtheusAuthSession(
        baseUrl: 'http://localhost:8000',
        client: backend,
      );
      addTearDown(auth.dispose);
      await auth.login('user', 'password');
      await Future.wait([auth.refresh(), auth.refresh()]);
      expect(refreshes, 1);
      final client = auth.createClient(
        inner: MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer new');
          return http.Response('{}', 200);
        }),
      );
      await client.get(Uri.parse('http://localhost:8000/api/v1/health'));
      client.close();
    },
  );
  test(
    'login uses ERP credentials, client sends bearer and logout revokes it',
    () async {
      final requests = <http.Request>[];
      final backend = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/login')) {
          expect(request.headers['password'], 'ERP-password');
          return http.Response(
            jsonEncode({
              'access_token': 'jwt-test',
              'token_type': 'Bearer',
              'username': 'operador',
              'expiresAt': DateTime.now().millisecondsSinceEpoch / 1000 + 300,
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });
      final auth = ProtheusAuthSession(
        baseUrl: 'http://localhost:8000',
        apiKey: 'key',
        client: backend,
      );
      addTearDown(auth.dispose);
      await auth.login('operador', 'ERP-password');
      final client = auth.createClient(inner: backend);
      await client.get(Uri.parse('http://localhost:8000/api/v1/health'));
      expect(requests.last.headers['Authorization'], 'Bearer jwt-test');
      expect(requests.last.headers['X-API-Token'], 'key');
      await auth.logout();
      expect(requests.last.url.path, endsWith('/logout'));
      expect(auth.isAuthenticated, false);
      await expectLater(
        client.get(Uri.parse('http://localhost:8000/api/v1/health')),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test('401 clears session and never retries a request', () async {
    var calls = 0;
    final backend = MockClient((request) async {
      calls++;
      return request.url.path.endsWith('/login')
          ? http.Response(
              jsonEncode({
                'access_token': 'token',
                'token_type': 'Bearer',
                'username': 'user',
                'expiresAt': DateTime.now().millisecondsSinceEpoch / 1000 + 300,
              }),
              200,
            )
          : http.Response('{}', 401);
    });
    final auth = ProtheusAuthSession(
      baseUrl: 'http://localhost:8000',
      client: backend,
    );
    addTearDown(auth.dispose);
    await auth.login('user', 'password');
    await auth
        .createClient(inner: backend)
        .get(Uri.parse('http://localhost:8000/api/v1/health'));
    expect(auth.isAuthenticated, false);
    expect(calls, 2);
  });

  test(
    'credentials cannot go to remote HTTP; bearer cannot go to another origin',
    () async {
      final auth = ProtheusAuthSession(baseUrl: 'http://remote.test:8000');
      addTearDown(auth.dispose);
      await expectLater(
        auth.login('user', 'password'),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        auth.createClient().get(Uri.parse('https://other.test/api/v1/health')),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test('failed login never falls back to a local account', () async {
    final auth = ProtheusAuthSession(
      baseUrl: 'http://localhost:8000',
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    addTearDown(auth.dispose);
    await expectLater(
      auth.login('admin', '9999'),
      throwsA(isA<AuthException>()),
    );
    expect(auth.isAuthenticated, false);
  });
}
