import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/repositories/flow_tracking_repository.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/flow_tracking_card.dart';

void main() {
  testWidgets('starts and pauses linked OP with server identity and reason', (
    tester,
  ) async {
    var version = 0;
    String status = 'waiting';
    String? stage;
    final commands = <Map>[];
    var dashboardUpdates = 0;
    final repo = FlowTrackingRepository(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          final command = jsonDecode(request.body) as Map;
          commands.add(command);
          version++;
          stage = command['stage'];
          status = command['action'] == 'pause' ? 'paused' : 'active';
        }
        return http.Response(
          jsonEncode({
            'state': {'version': version, 'stage': stage, 'status': status},
            'events': [],
            'allowedStages': ['firmware'],
          }),
          200,
        );
      }),
    );
    addTearDown(repo.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FlowTrackingCard(
              onChanged: () => dashboardUpdates++,
              repository: repo,
              op: const OrdemProducao(
                numero: '12345601001',
                produto: 'P',
                qtd: 10,
                responsavel: 'ERP',
                dataAbertura: '',
                prazo: '',
                status: StatusOP.emAndamento,
                progresso: 0,
                mes: '',
                erpReadOnly: true,
                erpKey: {
                  'filial': '04',
                  'numero': '123456',
                  'item': '01',
                  'sequencia': '001',
                  'grade': '',
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gravacao').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar etapa'));
    await tester.pumpAndSettle();
    expect(find.text('Gravacao · Em execução'), findsOneWidget);
    expect(commands.single.containsKey('actor'), false);
    expect((commands.single['key'] as Map)['sequencia'], '001');
    await tester.tap(find.text('Pausar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Falta de material');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(commands.last['note'], 'Falta de material');
    expect(commands.last['expectedVersion'], 1);
    expect(find.text('Retomar'), findsOneWidget);
    expect(dashboardUpdates, 2); // Start and pause refresh the dashboard.
    expect(tester.takeException(), isNull);
  });
  test(
    'retries use same command id; invalid responses preserve status for caller',
    () async {
      final ids = <String>[];
      final repo = FlowTrackingRepository(
        client: MockClient((r) async {
          ids.add((jsonDecode(r.body) as Map)['requestId']);
          return http.Response('{"detail":"A OP foi atualizada"}', 409);
        }),
      );
      addTearDown(repo.close);
      final command = {'requestId': FlowTrackingRepository.requestId()};
      await expectLater(
        repo.send(command),
        throwsA(
          isA<FlowTrackingException>().having((e) => e.status, 'status', 409),
        ),
      );
      await expectLater(
        repo.send(command),
        throwsA(isA<FlowTrackingException>()),
      );
      expect(ids[0], ids[1]);
    },
  );
}
