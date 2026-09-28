import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/route_access.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/ui/auth/login_page.dart';
import 'package:vetti_flow_1_0/ui/reports/warehouse_report_page.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart';
import 'package:vetti_flow_1_0/ui/closing/closing_page.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_cubit.dart';
import 'package:vetti_flow_1_0/ui/dashboard/dashboard_page.dart';
import 'package:vetti_flow_1_0/ui/dashboard/views/operator_assignments_view.dart';
import 'package:vetti_flow_1_0/ui/expedition/expedition_page.dart';
import 'package:vetti_flow_1_0/ui/expedition/expedition_read_page.dart';
import 'package:vetti_flow_1_0/ui/firmware/firmware_page.dart';
import 'package:vetti_flow_1_0/ui/protheus/fila_protheus_page.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_dismantlings_page.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_inventory_audit_page.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_write_readiness_page.dart';
import 'package:vetti_flow_1_0/ui/smd/smd_page.dart';
import 'package:vetti_flow_1_0/ui/smd/smd_work_page.dart';
import 'package:vetti_flow_1_0/ui/production/production_read_page.dart';
import 'package:vetti_flow_1_0/ui/production/production_work_page.dart';
import 'package:vetti_flow_1_0/ui/soldering/soldering_page.dart';
import 'package:vetti_flow_1_0/ui/support/support_page.dart';
import 'package:vetti_flow_1_0/ui/testing/testing_page.dart';
import 'package:vetti_flow_1_0/ui/tv/vetti_flow_tv_page.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_page.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_materials_page.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_release_page.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_read_page.dart'
    show WarehouseReadPage;

Map<String, WidgetBuilder> vettiFlowRoutes() {
  final routes = <String, WidgetBuilder>{
    '/login': (context) => const LoginPage(),
    '/colaboradores': (context) => const CollaboratorsPage(),
    '/dashboard': (context) => BlocProvider(
      create: (context) => DashboardCubit(context.read<OpRepository>()),
      child: const DashboardPage(),
    ),
    '/expedicao': (context) => const ExpeditionReadPage(),
    '/expedicao/fluxo-local': (context) => const ExpeditionPage(),
    '/fechamento': (context) => const ClosingPage(),
    '/firmware': (context) => const FirmwarePage(),
    '/smd': (context) => const SmdPage(),
    '/smd/apontar': (context) => const SmdWorkPage(),
    '/producao': (context) => const ProductionReadPage(),
    '/producao/operacao': (context) => const ProductionWorkPage(),
    '/suporte/operacao': (context) =>
        const ProductionWorkPage(destinationSector: 'support'),
    '/expedicao/operacao': (context) =>
        const ProductionWorkPage(destinationSector: 'expedition'),
    '/suporte/preparos': (context) =>
        const ProductionWorkPage(destinationSector: 'support'),
    '/expedicao/preparos': (context) =>
        const ProductionWorkPage(destinationSector: 'expedition'),
    '/soldagem': (context) => const SolderingPage(),
    '/suporte': (context) => const SupportPage(),
    '/teste': (context) => const TestingPage(),
    '/almoxarifado': (context) => const WarehousePage(),
    '/almoxarifado/materiais': (context) => const WarehouseMaterialsPage(),
    '/almoxarifado/operacao': (context) => const WarehouseReleasePage(),
    '/smd/materiais': (context) =>
        const WarehouseMaterialsPage(destinationWarehouses: ['03']),
    '/producao/materiais': (context) =>
        const WarehouseMaterialsPage(destinationWarehouses: ['05']),
    '/suporte/materiais': (context) =>
        const WarehouseMaterialsPage(destinationWarehouses: ['06', '07']),
    '/expedicao/materiais': (context) =>
        const WarehouseMaterialsPage(destinationWarehouses: ['10']),
    for (final sector in ReportSector.values)
      sector.route: (context) => WarehouseReportPage(sector: sector),
    '/admin/armazens': (context) =>
        const WarehouseReadPage(administrative: true),
    FilaProtheusPage.rota: (context) => const FilaProtheusPage(),
    ProtheusDismantlingsPage.rota: (context) =>
        const ProtheusDismantlingsPage(),
    ProtheusInventoryAuditPage.rota: (context) =>
        const ProtheusInventoryAuditPage(),
    ProtheusWriteReadinessPage.rota: (context) =>
        const ProtheusWriteReadinessPage(),
    '/tv': (context) => const VettiFlowTvPage(),
  };
  return routes.map(
    (route, builder) => MapEntry(
      route,
      route == '/login'
          ? builder
          : (context) => RouteAccess(route: route, builder: builder),
    ),
  );
}
