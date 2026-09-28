import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/app/app_routes.dart';
import 'package:vetti_flow_1_0/data/models/protheus_dismantlings.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_dismantling_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_dismantlings_page.dart';

void main() {
  test('app registers dedicated Protheus dismantling route', () {
    expect(vettiFlowRoutes().keys, contains(ProtheusDismantlingsPage.rota));
  });

  test('dismantling snapshot decodes paired RE7/DE7 structure', () {
    final snapshot = ProtheusDismantlingSnapshot.fromJson(_dismantlingJson());

    expect(snapshot.filial, '04');
    expect(snapshot.desmontagens, hasLength(1));
    expect(snapshot.desmontagens.single.documento, 'Q000004AV');
    expect(snapshot.desmontagens.single.produtoOrigem, '575-0863');
    expect(snapshot.desmontagens.single.localOrigem, '05');
    expect(snapshot.desmontagens.single.statusLabel, 'Pareada');
    expect(
      snapshot.desmontagens.single.componentesRetornados.single.produto,
      '100-010',
    );
    expect(
      snapshot.desmontagens.single.componentesRetornados.single.local,
      '01',
    );
    expect(snapshot.desmontagens.single.movimentos.map((item) => item.label), [
      'RE7/999',
      'DE7/499',
    ]);
  });

  test(
    'API dismantling repository sends read-only filters and token',
    () async {
      final repository = ApiProtheusDismantlingRepository(
        baseUrl: 'http://api.local',
        apiToken: 'token-teste',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/desmontagens');
          expect(request.url.queryParameters['filial'], '04');
          expect(request.url.queryParameters['documento'], 'Q000004AV');
          expect(request.url.queryParameters['produto'], '575-0863');
          expect(request.url.queryParameters['limit'], '10');
          expect(request.headers['X-API-Token'], 'token-teste');
          return http.Response(jsonEncode(_dismantlingJson()), 200);
        }),
      );

      final snapshot = await repository.fetchDismantlings(
        filial: '04',
        documento: 'Q000004AV',
        produto: '575-0863',
        limit: 10,
      );

      expect(snapshot.desmontagens.single.documento, 'Q000004AV');
      expect(snapshot.desmontagens.single.produtoOrigem, '575-0863');
      expect(
        snapshot.desmontagens.single.componentesRetornados.single.produto,
        '100-010',
      );
    },
  );

  testWidgets('dismantling page shows official returns read-only', (
    tester,
  ) async {
    await tester.pumpWidget(
      Provider<ProtheusDismantlingRepository>.value(
        value: _FakeDismantlingRepository(
          ProtheusDismantlingSnapshot.fromJson(_dismantlingJson()),
        ),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProtheusDismantlingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Desmontagens Protheus'), findsOneWidget);
    expect(find.text('Somente leitura'), findsWidgets);
    expect(find.text('Q000004AV'), findsOneWidget);
    expect(find.textContaining('575-0863'), findsWidgets);
    expect(find.textContaining('100-010'), findsWidgets);
    expect(find.text('RE7/999'), findsOneWidget);
    expect(find.text('DE7/499'), findsOneWidget);
  });
}

Map<String, Object?> _dismantlingJson() => {
  'filial': '04',
  'desmontagens': [
    {
      'documento': 'Q000004AV',
      'produtoOrigem': '575-0863',
      'produtoOrigemDescricao': 'SUB MEC SMART MODULO SIRENE SF',
      'quantidadeOrigem': 1,
      'localOrigem': '05',
      'data': '09/09/2026',
      'status': 'pareada',
      'componentesRetornados': [
        {
          'produto': '100-010',
          'produtoDescricao': 'PARAFUSO 2,9 X 6,5 MM ZI',
          'quantidade': 4,
          'local': '01',
          'documento': 'Q000004AV',
          'data': '09/09/2026',
        },
      ],
      'movimentos': [
        {
          'cf': 'RE7',
          'tm': '999',
          'produto': '575-0863',
          'local': '05',
          'quantidade': 1,
          'documento': 'Q000004AV',
          'data': '09/09/2026',
        },
        {
          'cf': 'DE7',
          'tm': '499',
          'produto': '100-010',
          'local': '01',
          'quantidade': 4,
          'documento': 'Q000004AV',
          'data': '09/09/2026',
        },
      ],
    },
  ],
  'divergencias': [],
};

class _FakeDismantlingRepository implements ProtheusDismantlingRepository {
  const _FakeDismantlingRepository(this.snapshot);

  final ProtheusDismantlingSnapshot snapshot;

  @override
  Future<ProtheusDismantlingSnapshot> fetchDismantlings({
    String filial = '04',
    String documento = '',
    String produto = '',
    int limit = 20,
  }) async {
    expect(filial, '04');
    expect(limit, 20);
    return snapshot;
  }
}
