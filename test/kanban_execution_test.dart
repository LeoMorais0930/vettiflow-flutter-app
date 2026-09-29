import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/flow_execution.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/ui/dashboard/views/kanban_view.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/op_card.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final width in [390.0, 1280.0]) {
    testWidgets('execution filters and cards fit width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final execution = FlowExecution.fromJson({
        'key': {
          'filial': '04',
          'numero': '123',
          'item': '01',
          'sequencia': '001',
          'grade': '',
        },
        'produto': 'P',
        'emissao': '20260929',
        'stage': 'warehouse',
        'status': 'paused',
        'actor': 'operador',
        'note': 'Falta de material',
        'updatedAt': '2026-09-29T12:00:00Z',
      });
      const op = OrdemProducao(
        numero: '12301001',
        produto: 'P',
        qtd: 10,
        responsavel: '',
        dataAbertura: '29/09/2026',
        prazo: '',
        status: StatusOP.emAndamento,
        progresso: 0,
        mes: '',
        erpReadOnly: true,
        armazem: '05',
      );
      var refreshed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KanbanView(
                ordens: [
                  op.copyWith(execution: execution),
                  op.copyWith(numero: 'other'),
                ],
                onOpenOP: (_) {},
                onRefresh: () => refreshed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Execução VettiFlow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pausadas (1)'));
      await tester.pumpAndSettle();
      expect(find.byType(OpCard), findsOneWidget);
      expect(find.text('Almoxarifado · Pausada'), findsOneWidget);
      expect(find.text('Motivo: Falta de material'), findsOneWidget);
      expect(find.text('Setor: Sub MEC / Produção'), findsOneWidget);
      await tester.tap(find.text('Atualizar painel'));
      expect(refreshed, true);
      await tester.tap(find.text('Sem registro (1)'));
      await tester.pumpAndSettle();
      expect(find.byType(OpCard), findsOneWidget);
      expect(find.text('other'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
