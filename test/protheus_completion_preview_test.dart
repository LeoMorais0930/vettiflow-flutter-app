import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/protheus_completion_preview.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_completion_preview_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/op_detail_panel.dart';

void main() {
  test('completion preview decodes expected PR0 and RE1 movements', () {
    final snapshot = ProtheusCompletionPreviewSnapshot.fromJson(_previewJson());

    expect(snapshot.op, '01621401001');
    expect(snapshot.readOnly, isTrue);
    expect(snapshot.rotinaStatus, 'pendente_pesquisa');
    expect(snapshot.quantidadeSolicitada, 50);
    expect(snapshot.quantidadeRestante, 50);
    expect(snapshot.movimentosPrevistos.map((item) => item.label), [
      'PR0/001',
      'RE1/999',
    ]);
    expect(snapshot.saldosComponentes.single.suficiente, isTrue);
    expect(snapshot.pendenciasPesquisa, contains('Confirmar rotina oficial.'));
  });

  test(
    'API completion preview repository sends GET filters and token',
    () async {
      final repository = ApiProtheusCompletionPreviewRepository(
        baseUrl: 'http://api.local',
        apiToken: 'token-teste',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.path,
            '/api/v1/ops/01621401001/apontamento-preview',
          );
          expect(request.url.queryParameters['filial'], '04');
          expect(request.url.queryParameters['quantidade'], '50');
          expect(request.url.queryParameters['armazem'], '10');
          expect(request.headers['X-API-Token'], 'token-teste');
          return http.Response(jsonEncode(_previewJson()), 200);
        }),
      );

      final snapshot = await repository.fetchPreview(
        '01621401001',
        filial: '04',
        quantidade: 50,
        armazem: '10',
      );

      expect(snapshot.movimentosPrevistos.first.cf, 'PR0');
      expect(snapshot.movimentosPrevistos.last.cf, 'RE1');
    },
  );

  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'OP detail at $width shows official completion preview read-only',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final op = OrdemProducao(
          numero: '01621401001',
          produto: '575-0863 - SMART ALARM',
          qtd: 50,
          responsavel: 'Tatiane',
          dataAbertura: '09/09/2026',
          prazo: '10/09/2026',
          status: StatusOP.emAndamento,
          progresso: 60,
          mes: 'set',
          stage: ProductionStage.closing,
          armazem: '05',
          erpReadOnly: true,
        );

        final fixture = _previewJson();
        (fixture['movimentosPrevistos'] as List).add({
          'cf': 'RE1',
          'tm': '999',
          'produto': 'MOD001',
          'produtoDescricao': 'Mão de obra',
          'local': '05',
          'quantidade': 50,
          'documentoReferencia': '',
        });
        final repository = _FakeCompletionPreviewRepository(
          ProtheusCompletionPreviewSnapshot.fromJson(fixture),
        );
        await tester.pumpWidget(
          Provider<ProtheusCompletionPreviewRepository>.value(
            value: repository,
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: OpDetailPanel(
                  op: op,
                  confirmCancel: false,
                  isDesktop: width >= 920,
                  canEdit: false,
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

        expect(repository.armazens, isEmpty);
        await tester.ensureVisible(
          find.text('Prévia de apontamento e materiais'),
        );
        await tester.tap(find.text('Prévia de apontamento e materiais'));
        await tester.pumpAndSettle();
        expect(find.text('PREVIA DE APONTAMENTO PROTHEUS'), findsOneWidget);
        expect(find.text('Somente leitura'), findsWidgets);
        expect(find.text('PR0/001'), findsOneWidget);
        expect(find.text('RE1/999'), findsOneWidget);
        expect(find.textContaining('Local 10'), findsOneWidget);
        expect(find.textContaining('Local 05'), findsOneWidget);
        expect(find.text('Detalhes técnicos da integração'), findsOneWidget);

        // Armazem do acabado vem sugerido e aceita edicao, como na MATA250.
        final campo = find.byKey(const ValueKey('completion-preview-armazem'));
        expect(tester.widget<TextField>(campo).controller!.text, '05');
        expect(find.text('Sugerido pelo Protheus: 05'), findsOneWidget);
        await tester.enterText(campo, '10');
        await tester.ensureVisible(find.text('Simular'));
        await tester.tap(find.text('Simular'));
        await tester.pumpAndSettle();
        expect(repository.armazens, [null, '10']);
        expect(find.textContaining('RE1 · MOD001'), findsNothing);
        await tester.ensureVisible(find.text('Mostrar MOD (mão de obra)'));
        await tester.tap(find.text('Mostrar MOD (mão de obra)'));
        await tester.pumpAndSettle();
        expect(find.text('MOD · MÃO DE OBRA'), findsOneWidget);
        expect(find.textContaining('MOD001'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Map<String, Object?> _previewJson() => {
  'op': '01621401001',
  'filial': '04',
  'readOnly': true,
  'rotinaStatus': 'pendente_pesquisa',
  'rotinasCandidatas': ['MATA250', 'MATA680', 'MATA681'],
  'quantidadeSolicitada': 50,
  'quantidadeRestante': 50,
  'armazemPadrao': '05',
  'ordem': {
    'numero': '01621401001',
    'produto': '575-0863',
    'produtoDescricao': 'SUB MEC SMART MODULO SIRENE SF',
    'quantidadePlanejada': 150,
    'quantidadeProduzida': 100,
    'local': '05',
    'encerrada': false,
  },
  'movimentosPrevistos': [
    {
      'cf': 'PR0',
      'tm': '001',
      'produto': '575-0863',
      'produtoDescricao': 'SUB MEC SMART MODULO SIRENE SF',
      'local': '10',
      'quantidade': 50,
      'documentoReferencia': '016214010',
    },
    {
      'cf': 'RE1',
      'tm': '999',
      'produto': '100-010',
      'produtoDescricao': 'PARAFUSO 2,9 X 6,5 MM ZI',
      'local': '05',
      'quantidade': 50,
      'documentoReferencia': '016214010',
    },
  ],
  'saldosComponentes': [
    {
      'produto': '100-010',
      'produtoDescricao': 'PARAFUSO 2,9 X 6,5 MM ZI',
      'local': '05',
      'saldoAtual': 80,
      'quantidadePrevista': 50,
      'suficiente': true,
    },
  ],
  'divergencias': [],
  'pendenciasPesquisa': ['Confirmar rotina oficial.'],
};

class _FakeCompletionPreviewRepository
    implements ProtheusCompletionPreviewRepository {
  _FakeCompletionPreviewRepository(this.snapshot);

  final ProtheusCompletionPreviewSnapshot snapshot;
  final List<String?> armazens = [];

  @override
  Future<ProtheusCompletionPreviewSnapshot> fetchPreview(
    String op, {
    String filial = '04',
    num? quantidade,
    String? armazem,
  }) async {
    expect(op, '01621401001');
    expect(filial, '04');
    expect(quantidade, 50);
    armazens.add(armazem);
    return snapshot;
  }
}
