import 'operator.dart';

enum AppSector {
  warehouse('Almoxarifado', '/almoxarifado'),
  smd('SMD', '/smd'),
  production('Produção', '/producao'),
  support('Suporte', '/suporte'),
  expedition('Expedição', '/expedicao');

  const AppSector(this.label, this.route);
  final String label, route;
}

/// Permissões locais da interface. A API ainda precisa de autorização individual.
extension OperatorAccess on Operator {
  bool get isAdministrator => area == WorkArea.system && canManageAssignments;
  bool get isProductionManager =>
      area == WorkArea.production && canManageAssignments;
  bool get canOpenDashboard =>
      isAdministrator || canManageAssignments && area != WorkArea.smd;

  bool get isSectorOwner => switch (area) {
    WorkArea.production => username == 'tatiane',
    WorkArea.warehouse => username == 'vera',
    WorkArea.smd => username == 'paula' || username == 'paulad',
    WorkArea.support => username == 'bruno',
    WorkArea.system => isAdministrator,
  };

  bool canOperate(AppSector sector) {
    if (isAdministrator) return true;
    return switch (sector) {
      AppSector.warehouse => area == WorkArea.warehouse,
      AppSector.smd => area == WorkArea.smd,
      AppSector.support => area == WorkArea.support,
      AppSector.production =>
        area == WorkArea.production &&
            (isProductionManager || stage != WorkStage.expedition),
      AppSector.expedition =>
        isProductionManager ||
            area == WorkArea.production && stage == WorkStage.expedition,
    };
  }

  bool canView(AppSector sector) =>
      isAdministrator ||
      canOperate(sector) &&
          effectivePermission != OperatorPermission.operation ||
      sector == AppSector.smd && isProductionManager;
  bool canUseSector(AppSector sector) => canOperate(sector) || canView(sector);
  Iterable<AppSector> get visibleSectors => AppSector.values.where(canView);
  String get homeRoute => area == WorkArea.smd
      ? '/smd/apontar'
      : canOpenDashboard
      ? '/dashboard'
      : switch (stage) {
          WorkStage.warehouse => '/almoxarifado/materiais',
          WorkStage.support => '/suporte/operacao',
          WorkStage.expedition => '/expedicao/operacao',
          _ => stage.route,
        };

  bool canAccessRoute(String route) {
    if (route == '/producao/sql-dev') {
      return isProductionManager || isAdministrator;
    }
    if (route == '/login') return true;
    if (route == '/dashboard') return canOpenDashboard;
    if (route == '/colaboradores') return canManageAssignments;
    if (route == '/tv') return isAdministrator || stage == WorkStage.tv;
    for (final sector in AppSector.values) {
      if (route == sector.route || route == '${sector.route}/relatorios') {
        return canView(sector);
      }
      if (route.startsWith('${sector.route}/')) {
        final action = route.substring(sector.route.length + 1);
        return const {
              'operacao',
              'materiais',
              'apontar',
              'preparos',
              'fluxo-local',
            }.contains(action) &&
            canUseSector(sector);
      }
    }
    final internal = switch (route) {
      '/firmware' => WorkStage.firmware,
      '/soldagem' => WorkStage.soldering,
      '/teste' => WorkStage.testing,
      '/fechamento' => WorkStage.closing,
      _ => null,
    };
    if (internal != null) {
      return isAdministrator ||
          isProductionManager ||
          area == WorkArea.production && stage == internal;
    }
    return isAdministrator;
  }
}
