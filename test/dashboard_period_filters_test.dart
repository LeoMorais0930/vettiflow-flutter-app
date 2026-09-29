import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_state.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';

OrdemProducao row(String date) => OrdemProducao(
  numero: date,
  produto: 'P',
  qtd: 1,
  responsavel: '',
  dataAbertura: date,
  prazo: '',
  status: StatusOP.emAndamento,
  progresso: 0,
  mes: 'jan',
);
void main() {
  test(
    'official closures use closing date, not old emission, and have their own filter',
    () {
      final year = DateTime.now().year;
      final closed = row('01/01/2024').copyWith(
        encerradaNoErp: true,
        dataEncerramento: '28/09/$year',
        status: StatusOP.finalizada,
      );
      final state = DashboardState(ordens: [closed, row('01/01/$year')]);
      expect(state.ordensFiltradas.length, 2);
      final filtered = state.copyWith(
        filtroSituacao: 'encerradas_erp',
        filtroPeriodo: '$year-09',
      );
      expect(filtered.ordensFiltradas.single, closed);
      expect(filtered.kpiCounts[StatusOP.finalizada], 1);
      expect(
        state.copyWith(filtroSituacao: 'abertas').ordensFiltradas.length,
        1,
      );
      expect(
        state.copyWith(filtroSituacao: 'concluidas_painel').ordensFiltradas,
        isEmpty,
      );
    },
  );

  test(
    'current year is default; history is explicit and month includes year',
    () {
      final year = DateTime.now().year;
      final state = DashboardState(
        ordens: [row('01/01/$year'), row('01/01/2024'), row('')],
      );
      expect(state.ordensFiltradas.length, 1);
      expect(state.kpiCounts[StatusOP.emAndamento], 1);
      expect(state.copyWith(filtroPeriodo: 'todos').ordensFiltradas.length, 3);
      expect(
        state
            .copyWith(filtroPeriodo: '2024-01')
            .ordensFiltradas
            .single
            .dataAbertura,
        '01/01/2024',
      );
    },
  );
  test('sector and completion filters agree with KPIs', () {
    final source = row('01/01/${DateTime.now().year}');
    final state = DashboardState(
      ordens: [
        source.copyWith(armazem: '10', status: StatusOP.finalizada),
        source.copyWith(armazem: '05'),
      ],
    );
    final filtered = state.copyWith(filtroSetor: 'Expedição');
    expect(filtered.ordensFiltradas.length, 1);
    expect(filtered.kpiCounts[StatusOP.finalizada], 1);
    expect(
      filtered.copyWith(mostrarConcluidas: false).ordensFiltradas,
      isEmpty,
    );
    expect(state.periodOptions, contains('ano_atual'));
  });
}
