import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/ui/dashboard/views/kanban_view.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/sector_shortcuts.dart';

void main() {
  testWidgets('ERP orders have a separate column when their stage is unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KanbanView(
            ordens: const [
              OrdemProducao(
                numero: 'ERP01',
                produto: 'Produto ERP',
                qtd: 1,
                responsavel: 'Protheus',
                dataAbertura: '',
                prazo: '',
                status: StatusOP.naoIniciada,
                progresso: 0,
                mes: '',
                erpReadOnly: true,
              ),
            ],
            onOpenOP: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sem armazém informado'), findsOneWidget);
    expect(find.text('ERP01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Protheus administrator sees and opens all sectors on narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = OperatorAssignmentStore()
        ..acceptProtheusIdentity('leonardo.morais');
      addTearDown(store.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(
            home: const Scaffold(body: SectorShortcuts()),
            routes: {
              for (final sector in AppSector.values)
                sector.route: (_) => Scaffold(
                  appBar: AppBar(),
                  body: Text('Tela ${sector.label}'),
                ),
            },
          ),
        ),
      );
      for (final sector in AppSector.values) {
        expect(store.currentOperator!.canAccessRoute(sector.route), true);
        await tester.tap(find.widgetWithText(OutlinedButton, sector.label));
        await tester.pumpAndSettle();
        expect(find.text('Tela ${sector.label}'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );
}
