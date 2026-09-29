import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetti_flow_1_0/data/repositories/flow_access_repository.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/flow_access_panel.dart';

void main() {
  testWidgets(
    'directory searches real logins and selection does not grant access',
    (tester) async {
      final queried = <String>[];
      final repo = FlowAccessRepository(
        client: MockClient((r) async {
          expect(r.method, 'GET');
          if (r.url.path.endsWith('/me')) {
            return http.Response('{"canManage":true,"stages":[]}', 200);
          }
          if (r.url.path.endsWith('/users')) {
            return http.Response('{"items":[]}', 200);
          }
          if (r.url.path.endsWith('/directory')) {
            return http.Response(
              jsonEncode({
                'items': [
                  {'id': '1', 'username': 'paulad', 'name': 'Paula Daniela'},
                  {
                    'id': '2',
                    'username': 'andressa.camargo',
                    'name': 'Andressa Camargo',
                  },
                ],
                'sourceDatabase': 'HMLp12',
                'queriedAt': '2026-09-29T12:00:00Z',
              }),
              200,
            );
          }
          queried.add(r.url.path);
          return http.Response(
            '{"username":"andressa.camargo","stages":[],"version":0,"isAdmin":false,"history":[]}',
            200,
          );
        }),
      );
      addTearDown(repo.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FlowAccessPanel(repository: repo),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Usuários ativos do Protheus (2)'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('flow-directory-search')),
        'CAMARGO',
      );
      await tester.pumpAndSettle();
      expect(find.text('Paula Daniela'), findsNothing);
      await tester.tap(find.text('Andressa Camargo'));
      await tester.pumpAndSettle();
      expect(queried.single, '/api/v1/flow/access/users/andressa.camargo');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('flow-access-username')))
            .controller!
            .text,
        'andressa.camargo',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('conflict requires a new read and never retries a permission write', (
    tester,
  ) async {
    var writes = 0;
    final repo = FlowAccessRepository(
      client: MockClient((r) async {
        if (r.url.path.endsWith('/me')) {
          return http.Response('{"canManage":true,"stages":[]}', 200);
        }
        if (r.url.path.endsWith('/directory')) {
          return http.Response(
            '{"items":[],"sourceDatabase":"DEV","queriedAt":"2026-09-29T12:00:00Z"}',
            200,
          );
        }
        if (r.url.path.endsWith('/users')) {
          return http.Response('{"items":[]}', 200);
        }
        if (r.method == 'PUT') {
          writes++;
          return http.Response('{"detail":"Consulte novamente"}', 409);
        }
        return http.Response(
          '{"username":"operador","stages":[],"version":0,"isAdmin":false,"history":[]}',
          200,
        );
      }),
    );
    addTearDown(repo.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: FlowAccessPanel(repository: repo)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('flow-access-username')),
      'operador',
    );
    await tester.tap(find.text('Consultar usuário'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Teste'));
    await tester.tap(find.widgetWithText(FilterChip, 'Teste'));
    await tester.ensureVisible(find.text('Salvar permissões'));
    await tester.tap(find.text('Salvar permissões'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Consulte novamente'), findsOneWidget);
    expect(find.text('Salvar permissões'), findsNothing);
  });
  testWidgets(
    'admin loads version before editing and saves only selected stages',
    (tester) async {
      Map? saved;
      final repo = FlowAccessRepository(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/me')) {
            return http.Response('{"canManage":true,"stages":[]}', 200);
          }
          if (r.url.path.endsWith('/directory')) {
            return http.Response(
              '{"items":[],"sourceDatabase":"DEV","queriedAt":"2026-09-29T12:00:00Z"}',
              200,
            );
          }
          if (r.url.path.endsWith('/users')) {
            return http.Response('{"items":[]}', 200);
          }
          if (r.method == 'PUT') saved = jsonDecode(r.body) as Map;
          return http.Response(
            jsonEncode({
              'username': 'operador',
              'stages': saved?['stages'] ?? ['testing'],
              'version': saved == null ? 2 : 3,
              'isAdmin': false,
              'history': [],
            }),
            200,
          );
        }),
      );
      addTearDown(repo.close);
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FlowAccessPanel(repository: repo),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('flow-access-username')),
        'operador',
      );
      await tester.tap(find.text('Consultar usuário'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Teste'));
      await tester.tap(find.widgetWithText(FilterChip, 'Teste'));
      await tester.tap(find.widgetWithText(FilterChip, 'Soldagem'));
      await tester.ensureVisible(find.text('Salvar permissões'));
      await tester.tap(find.text('Salvar permissões'));
      await tester.pumpAndSettle();
      expect(saved, {
        'stages': ['soldering'],
        'expectedVersion': 2,
      });
      expect(find.text('Permissões salvas no servidor.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('non-admin sees own stages without management controls', (
    tester,
  ) async {
    final repo = FlowAccessRepository(
      client: MockClient((r) async {
        expect(r.url.path.endsWith('/me'), true);
        return http.Response('{"canManage":false,"stages":["testing"]}', 200);
      }),
    );
    addTearDown(repo.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FlowAccessPanel(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Salvar permissões'), findsNothing);
    expect(find.textContaining('Teste'), findsOneWidget);
  });
}
