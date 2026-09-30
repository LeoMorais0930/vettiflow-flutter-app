import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_publisher.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_cubit.dart';
import 'fakes/mock_op_repository.dart';

class CreationRepo extends MockOpRepository {
  ProtheusPublishOutcome? outcome;
  @override
  ProtheusPublishOutcome? get ultimoEnvioProtheus => outcome;
}

void main() {
  test('only confirmed ERP creation schedules commitment review', () async {
    final repo = CreationRepo();
    final cubit = DashboardCubit(repo);
    addTearDown(cubit.close);
    const dto = NovaOrdemDTO(produto: 'Teste', qtd: 10, responsavel: '');
    for (final result in <ProtheusPublishOutcome?>[
      null,
      const ProtheusPublishOutcome.simulada(mutationId: 'x'),
      const ProtheusPublishOutcome.naFila(mutationId: 'x', motivo: 'offline'),
    ]) {
      repo.outcome = result;
      await cubit.createOP(dto);
      expect(cubit.state.revisarEmpenhosOp, isEmpty);
    }
    repo.outcome = const ProtheusPublishOutcome.gravada(
      mutationId: 'x',
      protheusRef: '01642901001',
    );
    await cubit.createOP(dto);
    expect(cubit.state.revisarEmpenhosOp, '01642901001');
    cubit.consumirRevisaoEmpenhos();
    expect(cubit.state.revisarEmpenhosOp, isEmpty);
  });
}
