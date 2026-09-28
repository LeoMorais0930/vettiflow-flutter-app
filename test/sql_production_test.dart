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

class MemoryPersistence extends LocalJsonPersistence {
  MemoryPersistence() : super('test-only');
  String? value;
  @override
  String? read() => value;
  @override
  void write(String payload) => value = payload;
}

Future<void> mountSqlPage(
  WidgetTester tester,
  SqlProductionRepository repository,
) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
}

void main() {
  test(
    'restart restores an uncertain request and consultation persists the receipt',
    () async {
      final storage = MemoryPersistence();
      final first = SqlProductionRepository(
        baseUrl: 'http://api.local',
        persistence: storage,
        client: MockClient((_) async => throw http.ClientException('timeout')),
      );
      await expectLater(
        first.send({'id': 'restore', 'operacao': 'abrir'}, writeKey: 'secret'),
        throwsA(isA<http.ClientException>()),
      );
      expect(storage.value, isNot(contains('secret')));
      first.close();
      final second = SqlProductionRepository(
        baseUrl: 'http://api.local',
        persistence: storage,
        client: MockClient(
          (_) async =>
              http.Response('{"id":"restore","status":"aplicada"}', 200),
        ),
      );
      expect(second.pending!['id'], 'restore');
      await second.consult('restore', writeKey: 'secret');
      expect(second.pending, isNull);
      second.close();
      final third = SqlProductionRepository(
        baseUrl: 'http://api.local',
        persistence: storage,
      );
      expect(third.savedResult('restore')!['status'], 'aplicada');
      third.close();
    },
  );

  test(
    'corrupt history and mismatched responses cannot confirm a write',
    () async {
      final storage = MemoryPersistence()..value = '{broken';
      final broken = SqlProductionRepository(
        baseUrl: 'http://api.local',
        persistence: storage,
      );
      await expectLater(
        broken.send({'id': 'x'}, writeKey: 'key'),
        throwsA(isA<SqlProductionException>()),
      );
      broken.close();
      for (final response in [
        'not JSON',
        '{"id":"other","status":"aplicada"}',
      ]) {
        final repo = SqlProductionRepository(
          baseUrl: 'http://api.local',
          client: MockClient((_) async => http.Response(response, 200)),
        );
        await expectLater(
          repo.send({'id': 'x'}, writeKey: 'key'),
          throwsA(isA<SqlProductionException>()),
        );
        expect(repo.pending!['id'], 'x');
        await expectLater(
          repo.consult('x', writeKey: 'key'),
          throwsA(isA<SqlProductionException>()),
        );
        repo.close();
      }
    },
  );

  for (final (operation, label) in [
    ('alterar', 'Alterar quantidade da OP'),
    ('apontar', 'Apontar produção'),
    ('transferir', 'Transferir estoque existente'),
  ]) {
    testWidgets(
      '$operation builds the proper command, shows movements and starts another operation',
      (tester) async {
        Map<String, dynamic>? sent;
        final repository = SqlProductionRepository(
          baseUrl: 'http://api.local',
          client: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response('{"enabled":true}', 200);
            }
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'id': sent!['id'],
                'status': 'previa',
                'ordens': [
                  {'op': 'V0000101001', 'produto': 'PA1', 'quantidade': '1'},
                ],
                'empenhos': [
                  {'produto': 'MP1', 'quantidade': '2', 'local': '05'},
                ],
                'movimentos': [
                  {
                    'produto': 'PA1',
                    'quantidade': '1',
                    'local': '05',
                    'cf': 'PR0',
                  },
                ],
              }),
              200,
            );
          }),
        );
        addTearDown(repository.close);
        await mountSqlPage(tester, repository);
        await tester.tap(find.text('Abrir OP'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        if (operation == 'transferir') {
          await tester.enterText(find.byKey(const Key('sql-product')), 'MP1');
        } else {
          await tester.enterText(
            find.widgetWithText(
              TextFormField,
              'Referência completa da OP no Protheus',
            ),
            'V0000101001',
          );
        }
        await tester.enterText(find.byKey(const Key('sql-write-key')), 'key');
        await tester.tap(find.text('Conferir operação'));
        await tester.pumpAndSettle();
        expect(sent!['operacao'], operation);
        expect(
          sent![switch (operation) {
            'alterar' => 'novaQuantidade',
            'apontar' => 'quantidadeApontada',
            _ => 'quantidadeTransferida',
          }],
          '1',
        );
        expect(find.textContaining('Empenho: MP1'), findsOneWidget);
        await tester.ensureVisible(find.text('Nova operação'));
        await tester.tap(find.text('Nova operação'));
        await tester.pumpAndSettle();
        expect(find.text('Conferir operação'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'restored pending operation displays its original data and can be consulted',
    (tester) async {
      final storage = MemoryPersistence()
        ..value = jsonEncode({
          'pending': {
            'id': 'recover',
            'operacao': 'transferir',
            'produtoTransferido': 'MP1',
            'quantidadeTransferida': '2',
            'origem': '01',
            'destino': '05',
            'data': '2026-09-28',
            'autor': 'Tatiane',
          },
          'results': {},
        });
      final repository = SqlProductionRepository(
        baseUrl: 'http://api.local',
        persistence: storage,
        client: MockClient(
          (request) async => http.Response(
            request.url.path.endsWith('/status')
                ? '{"enabled":true}'
                : '{"id":"recover","status":"aplicada"}',
            200,
          ),
        ),
      );
      addTearDown(repository.close);
      await mountSqlPage(tester, repository);
      expect(find.text('Reenviar mesmo pedido'), findsOneWidget);
      expect(find.text('MP1'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('sql-write-key')), 'key');
      await tester.tap(find.text('Consultar pedido'));
      await tester.pumpAndSettle();
      expect(find.text('Operação registrada no DEV'), findsOneWidget);
      expect(repository.pending, isNull);
    },
  );

  testWidgets(
    'empty key and failed preview show errors without an apply button',
    (tester) async {
      final repository = SqlProductionRepository(
        baseUrl: 'http://api.local',
        client: MockClient(
          (request) async => http.Response(
            request.method == 'GET'
                ? '{"enabled":true}'
                : '{"detail":"Saldo insuficiente"}',
            request.method == 'GET' ? 200 : 409,
          ),
        ),
      );
      addTearDown(repository.close);
      await mountSqlPage(tester, repository);
      await tester.enterText(find.byKey(const Key('sql-product')), 'PA1');
      await tester.tap(find.text('Conferir operação'));
      await tester.pumpAndSettle();
      expect(find.text('Informe a chave de escrita do DEV.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('sql-write-key')), 'key');
      await tester.tap(find.text('Conferir operação'));
      await tester.pumpAndSettle();
      expect(find.text('Saldo insuficiente'), findsOneWidget);
      expect(find.text('Gravar no DEV'), findsNothing);
    },
  );
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
        if (++calls == 1) {
          throw http.ClientException('connection lost after commit');
        }
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
