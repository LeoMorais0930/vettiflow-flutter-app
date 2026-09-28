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

void main() {
  test('health info exposes database and read-only mode', () async {
    final client = ProtheusSyncClient(
      baseUrl: 'http://api.local',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/health');
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

    final health = await client.healthInfo();

    expect(health.ok, isTrue);
    expect(health.database, 'HMLp12');
    expect(health.company, '010');
    expect(health.readOnly, isTrue);
  });

  testWidgets(
    'Protheus queue is explicitly read-only and has no write action',
    (tester) async {
      final queue = PendingMutationStore()
        ..enqueue(
          (id, criadoEm) => TransferenciaMutation(
            id: id,
            filial: '04',
            criadoEm: criadoEm,
            autor: 'Tatiane',
            produto: '100-010',
            produtoDescricao: 'PARAFUSO',
            quantidade: 12,
            localOrigem: '01',
            localDestino: '05',
          ),
        );
      final client = ProtheusSyncClient(
        baseUrl: 'http://api.local',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'ok': true,
              'banco': 'VettiP12',
              'aplicando': false,
              'readOnly': true,
              'empresa': '010',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PendingMutationStore>.value(value: queue),
            Provider<ProtheusSyncClient>.value(value: client),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const FilaProtheusPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modo somente leitura'), findsWidgets);
      expect(find.textContaining('VettiP12'), findsWidgets);
      expect(find.text('Enviar API'), findsNothing);
      expect(find.text('Aplicar ERP'), findsNothing);
      expect(
        find.text('Rascunhos locais sem envio ao Protheus'),
        findsOneWidget,
      );
    },
  );
}
