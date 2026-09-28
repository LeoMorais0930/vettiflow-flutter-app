import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/app/app_routes.dart';
import 'package:vetti_flow_1_0/data/models/protheus_inventory_audit.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_inventory_audit_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_inventory_audit_page.dart';

void main() {
  test('app registers dedicated Protheus inventory audit route', () {
    expect(vettiFlowRoutes().keys, contains(ProtheusInventoryAuditPage.rota));
  });

  test('inventory audit snapshot separates special movement types', () {
    final snapshot = ProtheusInventoryAuditSnapshot.fromJson(_auditJson());

    expect(snapshot.filial, '04');
    expect(snapshot.movimentos, hasLength(4));
    expect(snapshot.movimentos.map((item) => item.tipo), [
      'estorno_op',
      'retorno_op',
      'devolucao_manual',
      'requisicao_manual',
    ]);
    expect(snapshot.movimentos.first.label, 'ER0/999');
    expect(snapshot.movimentos.first.usuario, 'LEONARDO');
    expect(snapshot.movimentos.first.motivo, 'RETORNO TESTE');
    expect(snapshot.resumoPorTipo.first.quantidadeMovimentos, 1);
  });

  test(
    'API inventory audit repository sends read-only filters and token',
    () async {
      final repository = ApiProtheusInventoryAuditRepository(
        baseUrl: 'http://api.local',
        apiToken: 'token-teste',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/auditoria-estoque');
          expect(request.url.queryParameters['filial'], '04');
          expect(request.url.queryParameters['documento'], '016214010');
          expect(request.url.queryParameters['op'], '01621401001');
          expect(request.url.queryParameters['produto'], '575-0863');
          expect(request.url.queryParameters['tipo'], 'estorno_op');
          expect(request.url.queryParameters['limit'], '10');
          expect(request.headers['X-API-Token'], 'token-teste');
          return http.Response(jsonEncode(_auditJson()), 200);
        }),
      );

      final snapshot = await repository.fetchAuditMovements(
        filial: '04',
        documento: '016214010',
        op: '01621401001',
        produto: '575-0863',
        tipo: 'estorno_op',
        limit: 10,
      );

      expect(snapshot.movimentos.first.cf, 'ER0');
      expect(snapshot.movimentos.first.tipoLabel, 'Estorno de OP');
    },
  );

  testWidgets('inventory audit page shows official movements read-only', (
    tester,
  ) async {
    await tester.pumpWidget(
      Provider<ProtheusInventoryAuditRepository>.value(
        value: _FakeInventoryAuditRepository(
          ProtheusInventoryAuditSnapshot.fromJson(_auditJson()),
        ),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProtheusInventoryAuditPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Auditoria de estoque Protheus'), findsOneWidget);
    expect(find.text('Somente leitura'), findsWidgets);
    expect(find.text('ER0/999'), findsOneWidget);
    expect(find.text('DE1/499'), findsOneWidget);
    expect(find.text('DE0/400'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('RE0/501'),
      180,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('RE0/501'), findsOneWidget);
    expect(find.textContaining('016214010'), findsWidgets);
    expect(find.textContaining('LEONARDO'), findsWidgets);
    expect(find.textContaining('RETORNO TESTE'), findsWidgets);
  });
}

Map<String, Object?> _auditJson() => {
  'filial': '04',
  'movimentos': [
    {
      'cf': 'ER0',
      'tm': '999',
      'tipo': 'estorno_op',
      'tipoLabel': 'Estorno de OP',
      'documento': '016214010',
      'op': '01621401001',
      'produto': '575-0863',
      'produtoDescricao': 'SUB MEC SMART MODULO SIRENE SF',
      'quantidade': 10,
      'local': '10',
      'data': '09/09/2026',
      'numSeq': '398619',
      'usuario': 'LEONARDO',
      'motivo': 'RETORNO TESTE',
      'observacao': 'Estorno conferido',
      'estorno': true,
    },
    {
      'cf': 'DE1',
      'tm': '499',
      'tipo': 'retorno_op',
      'tipoLabel': 'Retorno de OP',
      'documento': '016214010',
      'op': '01621401001',
      'produto': '100-010',
      'produtoDescricao': 'PARAFUSO 2,9 X 6,5 MM ZI',
      'quantidade': 10,
      'local': '05',
      'data': '09/09/2026',
      'numSeq': '398619',
      'usuario': 'LEONARDO',
      'motivo': 'RETORNO TESTE',
      'observacao': '',
      'estorno': false,
    },
    {
      'cf': 'DE0',
      'tm': '400',
      'tipo': 'devolucao_manual',
      'tipoLabel': 'Devolucao manual',
      'documento': 'DEV000123',
      'op': '',
      'produto': '100-010',
      'produtoDescricao': 'PARAFUSO 2,9 X 6,5 MM ZI',
      'quantidade': 3,
      'local': '01',
      'data': '09/09/2026',
      'numSeq': '398620',
      'usuario': 'LEONARDO',
      'motivo': 'SOBRA',
      'observacao': '',
      'estorno': false,
    },
    {
      'cf': 'RE0',
      'tm': '501',
      'tipo': 'requisicao_manual',
      'tipoLabel': 'Requisicao manual',
      'documento': 'REQ000123',
      'op': '',
      'produto': '100-010',
      'produtoDescricao': 'PARAFUSO 2,9 X 6,5 MM ZI',
      'quantidade': 2,
      'local': '01',
      'data': '09/09/2026',
      'numSeq': '398621',
      'usuario': 'LEONARDO',
      'motivo': 'AJUSTE',
      'observacao': '',
      'estorno': false,
    },
  ],
  'resumoPorTipo': [
    {
      'tipo': 'estorno_op',
      'tipoLabel': 'Estorno de OP',
      'quantidadeMovimentos': 1,
    },
    {
      'tipo': 'retorno_op',
      'tipoLabel': 'Retorno de OP',
      'quantidadeMovimentos': 1,
    },
    {
      'tipo': 'devolucao_manual',
      'tipoLabel': 'Devolucao manual',
      'quantidadeMovimentos': 1,
    },
    {
      'tipo': 'requisicao_manual',
      'tipoLabel': 'Requisicao manual',
      'quantidadeMovimentos': 1,
    },
  ],
  'pendenciasPesquisa': [],
};

class _FakeInventoryAuditRepository
    implements ProtheusInventoryAuditRepository {
  const _FakeInventoryAuditRepository(this.snapshot);

  final ProtheusInventoryAuditSnapshot snapshot;

  @override
  Future<ProtheusInventoryAuditSnapshot> fetchAuditMovements({
    String filial = '04',
    String documento = '',
    String op = '',
    String produto = '',
    String tipo = '',
    int limit = 20,
  }) async {
    expect(filial, '04');
    expect(limit, 50);
    return snapshot;
  }
}
