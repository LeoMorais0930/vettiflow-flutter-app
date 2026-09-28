import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/protheus/fila_protheus_page.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

void main() {
  testWidgets('Protheus queue opens with an empty readable state', (
    tester,
  ) async {
    final store = PendingMutationStore();
    final client = _healthClient();
    addTearDown(client.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PendingMutationStore>.value(value: store),
          Provider<ProtheusSyncClient>.value(value: client),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          routes: {FilaProtheusPage.rota: (_) => const FilaProtheusPage()},
          home: const FilaProtheusPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fila do Protheus'), findsOneWidget);
    expect(find.text('Modo somente leitura'), findsWidgets);
    expect(find.textContaining('HMLp12'), findsWidgets);
    expect(find.text('Nada pendente para o Protheus.'), findsOneWidget);
    expect(find.text('Enviar API'), findsNothing);
    expect(find.text('Aplicar ERP'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('top bar shows the Protheus queue shortcut and pending count', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 768);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = PendingMutationStore();
    store.enqueue(
      (id, criadoEm) => AberturaOpMutation(
        id: id,
        filial: '04',
        criadoEm: criadoEm,
        autor: 'Tatiane',
        produto: '730-0863',
        produtoDescricao: 'SMART ALARM',
        quantidade: 10,
        localProducao: '05',
      ),
    );
    final client = _healthClient();
    addTearDown(client.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PendingMutationStore>.value(value: store),
          Provider<ProtheusSyncClient>.value(value: client),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          routes: {FilaProtheusPage.rota: (_) => const FilaProtheusPage()},
          home: const Scaffold(
            body: VettiTopBar(
              title: 'Producao',
              operatorName: 'Tatiane',
              operatorRole: 'Gestora',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('1 rascunho local sem envio'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byTooltip('1 rascunho local sem envio'));
    await tester.pumpAndSettle();

    expect(find.text('Fila do Protheus'), findsOneWidget);
    expect(find.text('Rascunhos locais sem envio ao Protheus'), findsOneWidget);
    expect(find.textContaining('Abrir OP - 730-0863'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ProtheusSyncClient _healthClient() {
  return ProtheusSyncClient(
    baseUrl: 'http://api.local',
    httpClient: MockClient((request) async {
      return http.Response(
        jsonEncode({
          'ok': true,
          'banco': 'HMLp12',
          'aplicando': false,
          'readOnly': true,
          'empresa': '010',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}
