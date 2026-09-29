import 'dart:convert';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetti_flow_1_0/data/repositories/erp_dashboard_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';

void main() {
  test(
    'loads every history page and preserves official closure independent of warehouse and quantity',
    () async {
      final store = ProductionFlowStore();
      final cursors = <String>[];
      final repo = ErpDashboardRepository(
        store,
        baseUrl: 'http://localhost:8000',
        client: MockClient((r) async {
          if (r.url.path.endsWith('/states'))
            return http.Response('{"items":[]}', 200);
          if (r.url.path.endsWith('/abertas')) return http.Response('[]', 200);
          final cursor = r.url.queryParameters['after']!;
          cursors.add(cursor);
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'numero': cursor,
                  'item': '01',
                  'sequencia': '001',
                  'produto': 'P',
                  'quantidade': 10,
                  'produzida': 8,
                  'local': '05',
                  'encerrada': true,
                  'emissao': '01/01/2024',
                  'encerramento': '28/09/2026',
                },
              ],
              'nextCursor': cursor == '0' ? 100 : null,
            }),
            200,
          );
        }),
      );
      addTearDown(store.dispose);
      addTearDown(repo.close);
      final orders = await repo.fetchOrdens();
      expect(cursors, ['0', '100']);
      expect(orders.length, 2);
      expect(
        orders.every(
          (o) => o.encerradaNoErp && o.status == StatusOP.finalizada,
        ),
        true,
      );
      expect(orders.first.dataEncerramento, '28/09/2026');
      expect(orders.first.progresso, 80);
      expect(orders.first.copyWith().encerradaNoErp, true);
    },
  );
  test('history failure never publishes a misleading partial list', () async {
    final store = ProductionFlowStore();
    final repo = ErpDashboardRepository(
      store,
      baseUrl: 'http://localhost:8000',
      client: MockClient(
        (r) async => http.Response(
          r.url.path.endsWith('/abertas') ? '[]' : '{}',
          r.url.path.endsWith('/abertas') ? 200 : 503,
        ),
      ),
    );
    addTearDown(store.dispose);
    addTearDown(repo.close);
    await expectLater(repo.fetchOrdens(), throwsStateError);
  });

  test(
    'dispatch completion requires produced quantity and zero material balance',
    () async {
      final store = ProductionFlowStore();
      final rows = [
        for (final values in [
          ['10', 10, 0],
          ['10', 9, 0],
          ['10', 10, 1],
          ['05', 10, 0],
          ['10', 10, null],
        ])
          {
            'numero': '${values}',
            'item': '01',
            'sequencia': '001',
            'produto': 'P',
            'quantidade': 10,
            'local': values[0],
            'produzida': values[1],
            'materiaisPendentes': values[2],
            'modPendente': 3,
          },
      ];
      final repo = ErpDashboardRepository(
        store,
        baseUrl: 'http://localhost:8000',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(
              r.url.path.endsWith('/states')
                  ? {'items': []}
                  : r.url.path.endsWith('/encerradas')
                  ? {'items': [], 'nextCursor': null}
                  : rows,
            ),
            200,
          ),
        ),
      );
      addTearDown(store.dispose);
      addTearDown(repo.close);
      final orders = await repo.fetchOrdens();
      expect(orders.map((o) => o.status), [
        StatusOP.finalizada,
        StatusOP.emAndamento,
        StatusOP.emAndamento,
        StatusOP.emAndamento,
        StatusOP.emAndamento,
      ]);
    },
  );

  test(
    'real OP identity and decimals are preserved; mutations are blocked',
    () async {
      final store = ProductionFlowStore();
      final repo = ErpDashboardRepository(
        store,
        baseUrl: 'http://localhost:8000',
        client: MockClient((r) async {
          if (r.url.path.endsWith('/states'))
            return http.Response('{"items":[]}', 200);
          if (r.url.path.endsWith('/encerradas'))
            return http.Response('{"items":[],"nextCursor":null}', 200);
          expect(r.method, 'GET');
          expect(r.url.path, '/api/v1/ops/abertas');
          return http.Response(
            jsonEncode([
              {
                'numero': '123456',
                'item': '01',
                'sequencia': '001',
                'produto': 'PROD',
                'quantidade': 2.5,
                'produzida': 1,
                'local': '05',
                'emissao': '29/09/2026',
                'previsao': '30/09/2026',
              },
            ]),
            200,
          );
        }),
      );
      addTearDown(store.dispose);
      addTearDown(repo.close);
      final orders = await repo.fetchOrdens();
      expect(orders.single.numero, '12345601001');
      expect(orders.single.qtd, 2.5);
      expect(orders.single.erpReadOnly, true);
      await expectLater(
        repo.avancarStatus(orders.single.numero),
        throwsStateError,
      );
    },
  );
  test(
    'execution snapshot joins full key and never changes ERP status',
    () async {
      final store = ProductionFlowStore();
      var fail = false;
      final repo = ErpDashboardRepository(
        store,
        baseUrl: 'http://localhost:8000',
        client: MockClient((r) async {
          if (r.url.path.endsWith('/states'))
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'key': {
                      'filial': '04',
                      'numero': '123456',
                      'item': '01',
                      'sequencia': '001',
                      'grade': '',
                    },
                    'produto': 'P',
                    'emissao': '20260929',
                    'stage': 'testing',
                    'status': 'completed',
                    'actor': 'operator',
                    'note': '',
                    'updatedAt': '2026-09-29T12:00:00Z',
                  },
                ],
              }),
              fail ? 503 : 200,
            );
          if (r.url.path.endsWith('/encerradas'))
            return http.Response('{"items":[],"nextCursor":null}', 200);
          return http.Response(
            jsonEncode([
              for (final seq in ['001', '002'])
                {
                  'numero': '123456',
                  'item': '01',
                  'sequencia': seq,
                  'produto': 'P',
                  'quantidade': 10,
                  'produzida': 0,
                  'local': '05',
                  'emissao': '29/09/2026',
                },
            ]),
            200,
          );
        }),
      );
      addTearDown(store.dispose);
      addTearDown(repo.close);
      final orders = await repo.fetchOrdens();
      expect(orders.first.execution?.status, 'completed');
      expect(orders.first.status, StatusOP.naoIniciada);
      expect(orders.last.execution, isNull);
      fail = true;
      await expectLater(repo.fetchOrdens(), throwsStateError);
    },
  );
  test('API failure is not converted into an empty list', () async {
    final store = ProductionFlowStore();
    final repo = ErpDashboardRepository(
      store,
      baseUrl: 'http://localhost:8000',
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    addTearDown(store.dispose);
    addTearDown(repo.close);
    await expectLater(repo.fetchOrdens(), throwsStateError);
  });
}
