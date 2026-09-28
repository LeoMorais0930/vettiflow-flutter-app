import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/protheus_transfers.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_op_movement_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_transfer_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/op_detail_panel.dart';

void main() {
  test('transfer snapshot decodes paired RE4/DE4 route', () {
    final snapshot = ProtheusTransferSnapshot.fromJson(_transferJson());

    expect(snapshot.filial, '04');
    expect(snapshot.transferencias, hasLength(1));
    expect(snapshot.transferencias.single.routeLabel, '01 -> 05');
    expect(snapshot.transferencias.single.statusLabel, 'Pareada');
    expect(
      snapshot.transferencias.single.movimentos.map((item) => item.label),
      ['RE4/999', 'DE4/499'],
    );
  });

  test('API transfer repository sends read-only filters and token', () async {
    final repository = ApiProtheusTransferRepository(
      baseUrl: 'http://api.local',
      apiToken: 'token-teste',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/transferencias');
        expect(request.url.queryParameters['filial'], '04');
        expect(request.url.queryParameters['produto'], '100-010');
        expect(request.url.queryParameters['localOrigem'], '01');
        expect(request.url.queryParameters['localDestino'], '05');
        expect(request.url.queryParameters['limit'], '10');
        expect(request.headers['X-API-Token'], 'token-teste');
        return http.Response(jsonEncode(_transferJson()), 200);
      }),
    );

    final snapshot = await repository.fetchTransfers(
      filial: '04',
      produto: '100-010',
      localOrigem: '01',
      localDestino: '05',
      limit: 10,
    );

    expect(snapshot.transferencias.single.documento, 'TRF000123');
    expect(snapshot.transferencias.single.localOrigem, '01');
    expect(snapshot.transferencias.single.localDestino, '05');
  });

  testWidgets('OP detail shows official sector transfers read-only', (
    tester,
  ) async {
    final op = OrdemProducao(
      numero: '01621401001',
      produto: '100-010 - PARAFUSO',
      qtd: 20,
      responsavel: 'Tatiane',
      dataAbertura: '09/09/2026',
      prazo: '10/09/2026',
      status: StatusOP.emAndamento,
      progresso: 60,
      mes: 'set',
      stage: ProductionStage.closing,
      armazem: '05',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProtheusOpMovementRepository>.value(
            value: const EmptyProtheusOpMovementRepository(),
          ),
          Provider<ProtheusTransferRepository>.value(
            value: _FakeTransferRepository(
              ProtheusTransferSnapshot.fromJson(_transferJson()),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: OpDetailPanel(
              op: op,
              confirmCancel: false,
              isDesktop: false,
              onClose: () {},
              onAdvance: ({int quantidadeArmazenada = 0}) {},
              onRegress: () {},
              onAskCancel: () {},
              onConfirmCancel: (_, _) {},
              onCancelNo: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRANSFERENCIAS OFICIAIS PROTHEUS'), findsOneWidget);
    expect(find.text('01 -> 05'), findsOneWidget);
    expect(find.text('RE4/999'), findsOneWidget);
    expect(find.text('DE4/499'), findsOneWidget);
    expect(find.textContaining('Doc TRF000123'), findsWidgets);
    expect(find.text('Somente leitura'), findsWidgets);
  });
}

Map<String, Object?> _transferJson() => {
  'filial': '04',
  'transferencias': [
    {
      'documento': 'TRF000123',
      'produto': '100-010',
      'produtoDescricao': 'PARAFUSO 2,9 X 6,5 MM ZI',
      'quantidade': 20,
      'localOrigem': '01',
      'localDestino': '05',
      'data': '09/09/2026',
      'status': 'pareada',
      'movimentos': [
        {
          'cf': 'RE4',
          'tm': '999',
          'local': '01',
          'quantidade': 20,
          'documento': 'TRF000123',
          'data': '09/09/2026',
        },
        {
          'cf': 'DE4',
          'tm': '499',
          'local': '05',
          'quantidade': 20,
          'documento': 'TRF000123',
          'data': '09/09/2026',
        },
      ],
    },
  ],
  'divergencias': [],
};

class _FakeTransferRepository implements ProtheusTransferRepository {
  const _FakeTransferRepository(this.snapshot);

  final ProtheusTransferSnapshot snapshot;

  @override
  Future<ProtheusTransferSnapshot> fetchTransfers({
    String filial = '04',
    String produto = '',
    String localOrigem = '',
    String localDestino = '',
    int limit = 20,
  }) async {
    expect(filial, '04');
    expect(produto, '100-010');
    return snapshot;
  }
}
