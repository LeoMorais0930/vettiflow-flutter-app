import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_cubit.dart';
import 'fakes/mock_op_repository.dart';

class IntermittentRepository extends MockOpRepository {
  bool unavailable = true;
  @override
  Future<List<OrdemProducao>> fetchOrdens() async {
    if (unavailable) throw StateError('unavailable');
    return super.fetchOrdens();
  }
}

void main() {
  test('load failure stays visible until retry and recovery', () async {
    final repo = IntermittentRepository();
    final cubit = DashboardCubit(repo);
    addTearDown(cubit.close);
    await cubit.loadOrdens();
    expect(cubit.state.loadError, isNotEmpty);
    expect(cubit.state.databaseSyncing, false);
    repo.unavailable = false;
    await cubit.loadOrdens();
    expect(cubit.state.loadError, isEmpty);
    expect(cubit.state.ordens, isNotEmpty);
  });
}
