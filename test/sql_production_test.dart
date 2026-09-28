import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/sql_production_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/ui/production/sql_production_page.dart';
import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:vetti_flow_1_0/data/repositories/local_json_persistence.dart';

class BrokenPersistence extends LocalJsonPersistence {
  const BrokenPersistence() : super('test-only');
  @override
  String? read() => null;
  @override
  void write(String payload) {}
}

void main() {
  test('production manager can enter the SQL route', () {
    final assignments = OperatorAssignmentStore()
      ..authenticate('tatiane', '1001');
    expect(
      assignments.currentOperator!.canAccessRoute('/producao/sql-dev'),
      isTrue,
    );
  });

  test('failed durable storage prevents a network write', () async {
    var calls = 0;
    final repository = SqlProductionRepository(
      baseUrl: 'http://api.local',
      persistence: const BrokenPersistence(),
      client: MockClient((_) async {
        calls++;
        return http.Response('{"id":"x","status":"aplicada"}', 200);
      }),
    );
    await expectLater(
      repository.send({'id': 'x'}, writeKey: 'key'),
      throwsA(isA<SqlProductionException>()),
    );
    expect(calls, 0);
    repository.close();
  });

  test('uncertain request survives retry with an incorrect key', () async {
    var calls = 0;
    final repository = SqlProductionRepository(
      baseUrl: 'http://api.local',
      client: MockClient((_) async {
        if (++calls == 1)
          throw http.ClientException('connection lost after commit');
        return http.Response('{"detail":"Invalid key"}', 401);
      }),
    );
    final body = {'id': 'uncertain'};
    await expectLater(
      repository.send(body, writeKey: 'key'),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(
      repository.send(body, writeKey: 'wrong'),
      throwsA(isA<SqlProductionException>()),
    );
    expect(repository.pending, body);
    await expectLater(
      repository.send({'id': 'another'}, writeKey: 'key'),
      throwsA(isA<SqlProductionException>()),
    );
    repository.close();
  });
  test(
    'preview and apply preserve the request ID and use a separate write key',
    () async {
      final requests = <http.Request>[];
      final repository = SqlProductionRepository(
        baseUrl: 'http://api.local',
        apiToken: 'read-key',
        client: MockClient((request) async {
          requests.add(request);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': body['id'],
              'status': body['simular'] == true ? 'previa' : 'aplicada',
            }),
            200,
          );
        }),
      );
      final body = {'id': 'same-id', 'operacao': 'abrir'};
      await repository.send(body, writeKey: 'private-key', preview: true);
      await repository.send(body, writeKey: 'private-key');
      expect(requests.length, 2);
      expect(requests.first.headers['X-API-Token'], 'read-key');
      expect(requests.first.headers['X-VettiFlow-Write-Key'], 'private-key');
      expect(jsonDecode(requests.last.body)['id'], 'same-id');
      expect(requests.last.body, isNot(contains('private-key')));
      repository.close();
    },
  );

  test('failed response is not reported as applied', () async {
    final repository = SqlProductionRepository(
      baseUrl: 'http://api.local',
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'detail': 'Saldo insuficiente'}), 409),
      ),
    );
    await expectLater(
      repository.send({'id': 'x'}, writeKey: 'key'),
      throwsA(isA<SqlProductionException>()),
    );
    repository.close();
  });

  testWidgets(
    'manager previews before applying with the same immutable payload',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bodies = <Map<String, dynamic>>[];
      final repository = SqlProductionRepository(
        baseUrl: 'http://api.local',
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({'enabled': true, 'reasons': []}),
              200,
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          bodies.add(body);
          return http.Response(
            jsonEncode({
              'id': body['id'],
              'status': body['simular'] == true ? 'previa' : 'aplicada',
              'protheusRef': 'V0000101001',
              'ordens': [],
              'empenhos': [],
              'movimentos': [],
            }),
            200,
          );
        }),
      );
      addTearDown(repository.close);
      final assignments = OperatorAssignmentStore()
        ..authenticate('tatiane', '1001');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: assignments),
            Provider.value(value: repository),
          ],
          child: const MaterialApp(home: SqlProductionPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('sql-product')), 'PA1');
      await tester.enterText(find.byKey(const Key('sql-quantity')), '10');
      await tester.enterText(find.byKey(const Key('sql-write-key')), 'secret');
      await tester.tap(find.text('Conferir operação'));
      await tester.pumpAndSettle();
      expect(bodies.single['simular'], isTrue);
      await tester.ensureVisible(find.text('Gravar no DEV'));
      await tester.tap(find.text('Gravar no DEV'));
      await tester.pumpAndSettle();
      expect(bodies.last['id'], bodies.first['id']);
      expect(bodies.last['simular'], isFalse);
      expect(find.textContaining('V0000101001'), findsWidgets);
      expect(find.text('Gravar no DEV'), findsNothing);
    },
  );

  testWidgets('without a signed-in manager there are no write controls', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SqlProductionPage()));
    await tester.pumpAndSettle();
    expect(find.text('Conferir operação'), findsNothing);
    expect(find.textContaining('gestor'), findsOneWidget);
  });
}
