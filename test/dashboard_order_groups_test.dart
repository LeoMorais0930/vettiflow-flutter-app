import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/dashboard_order_groups.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';

OrdemProducao op(String local, {bool remote = true}) => OrdemProducao(
  numero: local,
  produto: 'P',
  qtd: 1,
  responsavel: '',
  dataAbertura: '',
  prazo: '',
  status: StatusOP.naoIniciada,
  progresso: 0,
  mes: '',
  armazem: local,
  erpReadOnly: remote,
);

void main() {
  test(
    'every ERP order is grouped once by its registered warehouse, never a guessed stage',
    () {
      final rows = [
        '01',
        '03',
        '04',
        '05',
        '06',
        '07',
        '10',
        '70',
        '99',
        '',
      ].map(op).toList();
      final groups = dashboardOrderGroups(rows);
      expect(groups.expand((g) => g.orders).length, rows.length);
      expect(
        groups.map((g) => g.title),
        containsAll([
          'Almoxarifado / SMD / PTH',
          'Sub MEC / Produção',
          'Suporte',
          'Expedição',
          'Terceiros',
          'Armazém 99 · sem mapeamento',
          'Sem armazém informado',
        ]),
      );
      expect(groups.every((g) => g.stage == null), true);
    },
  );
  test('groups the DEV distribution without losing orders', () {
    const counts = {
      '01': 2,
      '03': 19,
      '04': 3,
      '05': 141,
      '06': 2,
      '07': 2,
      '10': 40,
      '70': 8,
    };
    final groups = dashboardOrderGroups([
      for (final entry in counts.entries)
        for (var i = 0; i < entry.value; i++) op(entry.key),
    ]);
    expect(groups.map((g) => g.orders.length), [24, 141, 4, 40, 8]);
    expect(groups.expand((g) => g.orders).length, 217);
    for (final code in ['71', '72', '73']) {
      expect(erpOrderSectorLabel(code), 'Terceiros');
    }
  });
  test('normalizes warehouse codes and keeps local pointing separate', () {
    final groups = dashboardOrderGroups([
      op(' 5 '),
      op('05'),
      op('05', remote: false),
    ]);
    expect(groups.first.title, 'Sub MEC / Produção');
    expect(groups.first.orders.length, 2);
    expect(groups.expand((g) => g.orders).length, 3);
    expect(
      groups
          .where((g) => g.stage != null)
          .expand((g) => g.orders)
          .single
          .erpReadOnly,
      false,
    );
  });
}
