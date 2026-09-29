import 'ordem_producao.dart';
import 'production_flow.dart';
import '../../shared/models/warehouse_routing.dart';

class DashboardOrderGroup {
  const DashboardOrderGroup(this.title, this.orders, {this.stage});
  final String title;
  final List<OrdemProducao> orders;
  final ProductionStage? stage;
}

/// A completed stage stays in its last recorded stage; it does not close the OP.
List<DashboardOrderGroup> executionOrderGroups(List<OrdemProducao> orders) => [
  DashboardOrderGroup(
    'Sem execução registrada',
    orders.where((o) => o.execution == null && !o.encerradaNoErp).toList(),
  ),
  for (final stage in ProductionStage.productionFlow.where(
    (s) => s != ProductionStage.storage && s != ProductionStage.completed,
  ))
    DashboardOrderGroup(
      stage.label,
      orders
          .where((o) => !o.encerradaNoErp && o.execution?.stage == stage)
          .toList(),
      stage: stage,
    ),
  if (orders.any((o) => o.encerradaNoErp))
    DashboardOrderGroup(
      'Encerradas no Protheus',
      orders.where((o) => o.encerradaNoErp).toList(),
    ),
];

const _sectorWarehouses = <String, List<String>>{
  'Almoxarifado / SMD / PTH': ['01', '03', '04'],
  'Sub MEC / Produção': ['05'],
  'Suporte': ['06', '07'],
  'Expedição': ['10'],
  'Terceiros': ['70', '71', '72', '73'],
};

String erpOrderSectorLabel(String warehouse) {
  if (warehouse.trim().isEmpty) return 'Sem armazém informado';
  final code = WarehouseRouting.normalizeCode(warehouse);
  for (final sector in _sectorWarehouses.entries) {
    if (sector.value.contains(code)) return sector.key;
  }
  return 'Armazém $code · sem mapeamento';
}

/// C2_LOCAL indica o setor cadastrado na OP, não a etapa física de execução.
/// O fluxo local tem apontamentos próprios e continua agrupado por etapa.
List<DashboardOrderGroup> dashboardOrderGroups(List<OrdemProducao> orders) {
  final remote = <String, List<OrdemProducao>>{};
  for (final order in orders.where((o) => o.erpReadOnly)) {
    final code = erpOrderSectorLabel(order.armazem);
    remote.putIfAbsent(code, () => []).add(order);
  }
  final codes = [
    ..._sectorWarehouses.keys.where(remote.containsKey),
    ...(remote.keys.where((key) => !_sectorWarehouses.containsKey(key)).toList()
      ..sort()),
  ];
  final local = orders.where((o) => !o.erpReadOnly).toList();
  return [
    for (final code in codes) DashboardOrderGroup(code, remote[code]!),
    if (local.isNotEmpty || remote.isEmpty)
      for (final stage in ProductionStage.productionFlow)
        DashboardOrderGroup(
          '${remote.isEmpty ? '' : 'Fluxo local · '}${stage.label}',
          local.where((o) => o.stage == stage).toList(),
          stage: stage,
        ),
  ];
}
