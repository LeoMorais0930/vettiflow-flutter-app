import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/route_access.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/sidebar.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/filter_bar.dart';
import 'package:vetti_flow_1_0/ui/dashboard/views/kanban_view.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_state.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_read_page.dart';
import 'package:vetti_flow_1_0/ui/reports/warehouse_report_page.dart';

Operator person(String username) =>
    Operator.all.firstWhere((o) => o.username == username);
OperatorAssignmentStore session(String username) {
  final actor = person(username);
  return OperatorAssignmentStore()
    ..authenticate(actor.username, actor.password);
}

Widget app(OperatorAssignmentStore session, Widget page) =>
    ChangeNotifierProvider.value(
      value: session,
      child: MaterialApp(home: page),
    );

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('acessos seguem área, posto e consulta SMD da gestão de produção', () {
    for (final username in ['tatiane', 'andressa']) {
      final actor = person(username);
      expect(actor.visibleSectors.toSet(), {
        AppSector.production,
        AppSector.expedition,
        AppSector.smd,
      });
      expect(actor.canOperate(AppSector.expedition), true);
      expect(actor.canOperate(AppSector.smd), false);
      expect(actor.canAccessRoute('/suporte/operacao'), false);
      expect(actor.canAccessRoute('/almoxarifado/relatorios'), false);
      expect(actor.canAccessRoute('/gestao/relatorios'), false);
      expect(ProductionFlowStore().canPointSmd(actor), false);
    }
    expect(person('paula').homeRoute, '/smd/apontar');
    expect(person('paula').canAccessRoute('/colaboradores'), true);
    expect(person('vera').visibleSectors.toList(), [AppSector.warehouse]);
    expect(person('luis').visibleSectors, isEmpty);
    expect(person('bruno').visibleSectors.toList(), [AppSector.support]);
    expect(person('rafaela').visibleSectors, isEmpty);
    expect(person('juliana').canAccessRoute('/teste'), false);
    expect(person('admin').visibleSectors.length, AppSector.values.length);
  });

  testWidgets('cabeçalho preserva título sem sobreposição em cinco larguras', (
    tester,
  ) async {
    final user = session('tatiane');
    addTearDown(user.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [320.0, 390.0, 920.0, 1043.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 850);
      await tester.pumpWidget(
        app(
          user,
          const Scaffold(
            body: Column(
              children: [
                VettiTopBar(title: 'Almoxarifado', operatorName: 'Tatiane'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = tester.getRect(find.text('Almoxarifado'));
      final menu = tester.getRect(find.byTooltip('Minha área e conta'));
      expect(title.right <= menu.left, true);
      expect(title.left >= 0 && title.right <= width, true);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip('Minha área e conta'));
    await tester.pumpAndSettle();
    expect(find.text('SMD · consulta'), findsOneWidget);
    expect(find.text('Suporte'), findsNothing);
  });

  testWidgets(
    'painel da Tatiane tem somente seus setores e URL de suporte é bloqueada',
    (tester) async {
      final user = session('tatiane');
      addTearDown(user.dispose);
      await tester.pumpWidget(
        app(
          user,
          Scaffold(
            body: Sidebar(viewMode: ViewMode.kanban, onViewMode: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SMD · consulta'), findsOneWidget);
      expect(find.text('Almoxarifado'), findsNothing);
      expect(find.text('Suporte'), findsNothing);
      var built = false;
      await tester.pumpWidget(
        app(
          user,
          RouteAccess(
            route: '/suporte/operacao',
            builder: (_) {
              built = true;
              return const Text('Conteúdo restrito');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(built, false);
      expect(
        find.text('Este setor não faz parte do seu acesso.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'consulta estreita troca abas sem cortar nomes e recolhe filtros',
    (tester) async {
      final user = session('vera');
      addTearDown(user.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(app(user, const WarehouseReadPage()));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      expect(find.text('Inventário'), findsOneWidget);
      await tester.tap(find.text('Inventário'));
      await tester.pumpAndSettle();
      expect(find.text('Inventário'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Mais opções'));
      await tester.pumpAndSettle();
      expect(find.text('Liberação de OPs'), findsOneWidget);
      expect(find.text('Relatórios'), findsOneWidget);
    },
  );

  testWidgets('relatório começa resumido e abre filtros por grupo', (
    tester,
  ) async {
    final user = session('vera');
    addTearDown(user.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(app(user, const WarehouseReportPage()));
    await tester.pumpAndSettle();
    expect(find.text('Gerar prévia'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-product')), findsNothing);
    await tester.tap(find.text('Ajustar filtros'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-query')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-product')), findsNothing);
    await tester.ensureVisible(find.text('Produto, OP e operador'));
    await tester.tap(find.text('Produto, OP e operador'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-product')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtros do painel expandem sem cortes e limpar atualiza busca', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(690, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var search = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ListView(
              children: [
                FilterBar(
                  busca: search,
                  filtroPeriodo: 'todos',
                  filtroResponsavel: 'todos',
                  filtroProduto: 'todos',
                  responsaveis: const ['Responsável com nome completo'],
                  produtos: const ['Produto com descrição longa'],
                  viewMode: ViewMode.kanban,
                  hasActiveFilters: search.isNotEmpty,
                  resultText: '0 de 0 OPs',
                  onBusca: (value) => setState(() => search = value),
                  onPeriodo: (_) {},
                  onResponsavel: (_) {},
                  onProduto: (_) {},
                  onViewMode: (_) {},
                  onLimpar: () => setState(() => search = ''),
                ),
                KanbanView(ordens: const [], onOpenOP: (_) {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(
      tester.widget<Scrollbar>(find.byType(Scrollbar).last).thumbVisibility,
      true,
    );
    await tester.enterText(find.byType(TextField), 'OP 123');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<String>), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
