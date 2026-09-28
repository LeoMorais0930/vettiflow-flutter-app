import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/protheus_op_movements.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_op_movement_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/op_detail_panel.dart';

void main() {
  test('API repository decodes official Protheus OP movements', () async {
    final requests = <String>[];
    final repository = ApiProtheusOpMovementRepository(
      baseUrl: 'http://api.local',
      httpClient: MockClient((request) async {
        requests.add('${request.method} ${request.url}');
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/ops/01621401001/movimentos');
        expect(request.url.queryParameters['filial'], '04');
        return http.Response(jsonEncode(_snapshotJson()), 200);
      }),
    );

    final snapshot = await repository.fetchSnapshot(
      '01621401001',
      filial: '04',
    );

    expect(requests, hasLength(1));
    expect(snapshot.op, '01621401001');
    expect(snapshot.statusLabel, 'Apontada parcial');
    expect(snapshot.ordem?.local, '05');
    expect(snapshot.totalProduzido, 100);
    expect(snapshot.totalConsumido, 150);
    expect(snapshot.hasReversal, isTrue);
    expect(snapshot.movimentos.map((item) => item.cf), [
      'PR0',
      'RE1',
      'ER0',
      'DE1',
    ]);
    expect(snapshot.movimentos.first.label, 'PR0/001');
    expect(snapshot.movimentos.first.perda, 2);
    expect(snapshot.movimentos.first.ganho, 1);
  });

  testWidgets('OP detail shows official Protheus movements read-only', (
    tester,
  ) async {
    final op = OrdemProducao(
      numero: '01621401001',
      produto: '575-0863 - SMART ALARM',
      qtd: 150,
      responsavel: 'Tatiane',
      dataAbertura: '09/09/2026',
      prazo: '10/09/2026',
      status: StatusOP.emAndamento,
      progresso: 60,
      mes: 'set',
      stage: ProductionStage.closing,
      materiais: const [('PARAFUSO', 1)],
    );

    await tester.pumpWidget(
      Provider<ProtheusOpMovementRepository>.value(
        value: _FakeMovementsRepository(
          ProtheusOpSnapshot.fromJson(_snapshotJson()),
        ),
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

    expect(find.text('MOVIMENTOS OFICIAIS PROTHEUS'), findsOneWidget);
    expect(
      find.textContaining('Status oficial: Apontada parcial'),
      findsOneWidget,
    );
    expect(find.text('PR0/001'), findsOneWidget);
    expect(find.text('RE1/999'), findsOneWidget);
    expect(find.text('ER0/999'), findsOneWidget);
    expect(find.text('DE1/499'), findsOneWidget);
    expect(find.textContaining('Doc 016214010'), findsWidgets);
    expect(find.textContaining('Seq 398619'), findsWidgets);
    expect(find.textContaining('Perda 2'), findsOneWidget);
    expect(find.textContaining('Ganho 1'), findsOneWidget);
    expect(find.text('Somente leitura'), findsWidgets);
  });
}

Map<String, Object?> _snapshotJson() => {
  'op': '01621401001',
  'filial': '04',
  'statusOficial': 'apontada_parcial',
  'ordem': {
    'numero': '01621401001',
    'produto': '575-0863',
    'quantidadePlanejada': 150,
    'quantidadeProduzida': 100,
    'local': '05',
    'encerrada': false,
  },
  'empenhos': [
    {
      'produto': '100-010',
      'local': '05',
      'quantidadeOriginal': 150,
      'quantidadeRestante': 50,
    },
  ],
  'movimentos': [
    {
      'cf': 'PR0',
      'tm': '001',
      'produto': '575-0863',
      'local': '10',
      'quantidade': 100,
      'documento': '016214010',
      'numSeq': '398619',
      'data': '09/09/2026',
      'perda': 2,
      'ganho': 1,
      'estorno': false,
    },
    {
      'cf': 'RE1',
      'tm': '999',
      'produto': '100-010',
      'local': '05',
      'quantidade': 150,
      'documento': '016214010',
      'numSeq': '398619',
      'data': '09/09/2026',
      'perda': 0,
      'ganho': 0,
      'estorno': false,
    },
    {
      'cf': 'ER0',
      'tm': '999',
      'produto': '575-0863',
      'local': '10',
      'quantidade': 20,
      'documento': '016214010',
      'numSeq': '398619',
      'data': '09/09/2026',
      'perda': 0,
      'ganho': 0,
      'estorno': true,
    },
    {
      'cf': 'DE1',
      'tm': '499',
      'produto': '100-010',
      'local': '05',
      'quantidade': 30,
      'documento': '016214010',
      'numSeq': '398619',
      'data': '09/09/2026',
      'perda': 0,
      'ganho': 0,
      'estorno': true,
    },
  ],
};

class _FakeMovementsRepository implements ProtheusOpMovementRepository {
  const _FakeMovementsRepository(this.snapshot);

  final ProtheusOpSnapshot snapshot;

  @override
  Future<ProtheusOpSnapshot> fetchSnapshot(
    String op, {
    String filial = '04',
  }) async {
    expect(op, '01621401001');
    expect(filial, '04');
    return snapshot;
  }
}
