import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/app/app_routes.dart';
import 'package:vetti_flow_1_0/data/models/protheus_write_readiness.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_write_readiness_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_write_readiness_page.dart';

void main() {
  test('app registers Protheus write governance route', () {
    expect(vettiFlowRoutes().keys, contains(ProtheusWriteReadinessPage.rota));
  });

  test('write readiness snapshot keeps Protheus writes disabled', () {
    final snapshot = ProtheusWriteReadinessSnapshot.fromJson(_readinessJson());

    expect(snapshot.readOnly, isTrue);
    expect(snapshot.writeEnabled, isFalse);
    expect(snapshot.status, 'bloqueada_por_politica');
    expect(snapshot.statusLabel, 'Escrita desabilitada');
    expect(snapshot.blockedOperations, contains('sql_direto'));
    expect(snapshot.candidateRoutines, contains('MATA250'));
    expect(snapshot.futureRequirements.first, contains('Projeto separado'));
  });

  test('API write readiness repository sends GET and token', () async {
    final repository = ApiProtheusWriteReadinessRepository(
      baseUrl: 'http://api.local',
      apiToken: 'token-teste',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/write-readiness');
        expect(request.headers['X-API-Token'], 'token-teste');
        return http.Response(jsonEncode(_readinessJson()), 200);
      }),
    );

    final snapshot = await repository.fetchReadiness();

    expect(snapshot.writeEnabled, isFalse);
    expect(snapshot.blockedOperations, contains('desmontagem'));
  });

  testWidgets('write readiness page shows disabled governance', (tester) async {
    await tester.pumpWidget(
      Provider<ProtheusWriteReadinessRepository>.value(
        value: _FakeWriteReadinessRepository(
          ProtheusWriteReadinessSnapshot.fromJson(_readinessJson()),
        ),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProtheusWriteReadinessPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Governanca Protheus'), findsOneWidget);
    expect(find.text('Somente leitura'), findsWidgets);
    expect(find.text('Escrita desabilitada'), findsWidgets);
    expect(find.textContaining('sql_direto'), findsOneWidget);
    expect(find.textContaining('MSExecAuto'), findsWidgets);
    expect(find.textContaining('MATA250'), findsWidgets);
  });
}

Map<String, Object?> _readinessJson() => {
  'readOnly': true,
  'writeEnabled': false,
  'status': 'bloqueada_por_politica',
  'database': 'HMLp12',
  'blockedOperations': [
    'abertura_op',
    'apontamento_op',
    'transferencia',
    'desmontagem',
    'sql_direto',
  ],
  'futureRequirements': [
    'Projeto separado para wrapper oficial Protheus.',
    'Validar MSExecAuto/rotina oficial somente depois de aprovacao.',
  ],
  'candidateRoutines': ['MATA250', 'MATA680', 'MATA681'],
};

class _FakeWriteReadinessRepository
    implements ProtheusWriteReadinessRepository {
  const _FakeWriteReadinessRepository(this.snapshot);

  final ProtheusWriteReadinessSnapshot snapshot;

  @override
  Future<ProtheusWriteReadinessSnapshot> fetchReadiness() async {
    return snapshot;
  }
}
