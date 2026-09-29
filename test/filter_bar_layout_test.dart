import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/filter_bar.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_state.dart';

void main() {
  for (final width in [390.0, 1040.0]) {
    testWidgets('expanded filters fit at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FilterBar(
                onSituacao: (_) {},
                filtroSituacao: 'todas',
                busca: '',
                filtroPeriodo: 'todos',
                filtroResponsavel: 'todos',
                filtroProduto: 'todos',
                responsaveis: const [],
                produtos: const [],
                viewMode: ViewMode.kanban,
                hasActiveFilters: true,
                resultText: '217 de 217 OPs',
                onBusca: (_) {},
                onPeriodo: (_) {},
                onResponsavel: (_) {},
                onProduto: (_) {},
                onViewMode: (_) {},
                onLimpar: () {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in ['Período', 'Responsável', 'Produto']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        expect(rect.top, greaterThan(0));
      }
      await tester.tap(find.text('Tabela'));
      expect(tester.takeException(), isNull);
    });
  }
}
