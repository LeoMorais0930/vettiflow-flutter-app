import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/flow_execution.dart';
import 'package:vetti_flow_1_0/data/models/dashboard_order_groups.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';

void main() {
  test(
    'matches full identity and source fingerprint, never guesses from warehouse',
    () {
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
        'stage': 'testing',
        'status': 'paused',
        'actor': 'operador',
        'note': 'Falta peça',
        'updatedAt': '2026-09-29T12:00:00Z',
      });
      final op = OrdemProducao(
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
        erpKey: execution.key,
      );
      expect(execution.matches(op), true);
      expect(execution.matches(op.copyWith(produto: 'OTHER')), false);
      expect(execution.matches(op.copyWith(dataAbertura: '28/09/2026')), false);
      final tracked = op.copyWith(execution: execution);
      expect(tracked.copyWith().execution, execution);
      expect(
        dashboardOrderGroups([tracked]).single.title,
        'Sub MEC / Produção',
      );
      final groups = executionOrderGroups([
        tracked,
        op.copyWith(numero: 'other'),
      ]);
      expect(groups.expand((g) => g.orders).length, 2);
      expect(groups.firstWhere((g) => g.title == 'Teste').orders, [tracked]);
      expect(
        groups
            .firstWhere((g) => g.title == 'Sem execução registrada')
            .orders
            .length,
        1,
      );
      expect(tracked.status, StatusOP.emAndamento);
    },
  );
}
