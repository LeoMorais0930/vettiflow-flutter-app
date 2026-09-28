import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/app/app_routes.dart';
import 'package:vetti_flow_1_0/data/repositories/flow_op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/mutation_sync_service.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/local_json_persistence.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_database.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_completion_preview_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_dismantling_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_inventory_audit_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_op_movement_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_product_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_transfer_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_warehouse_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_write_readiness_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_database.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_read_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';

class VettiFlowApp extends StatelessWidget {
  const VettiFlowApp({super.key});

  static const _apiBaseUrl = String.fromEnvironment(
    'VETTIFLOW_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const _apiToken = String.fromEnvironment('VETTIFLOW_API_TOKEN');

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<WarehouseReadRepository>(
          create: (_) => WarehouseReadRepository(
            baseUrl: _apiBaseUrl,
            apiToken: _apiToken,
          ),
          dispose: (_, repository) => repository.close(),
        ),
        Provider<ProductionFlowDatabase>(
          create: (_) => const EmptyProductionFlowDatabase(),
        ),
        // A fila de mutacoes nasce antes do fluxo de producao para guardar
        // rascunhos locais. O Protheus segue somente leitura.
        ChangeNotifierProvider<PendingMutationStore>(
          create: (_) => PendingMutationStore(),
        ),
        Provider<ProtheusSyncClient>(
          create: (_) =>
              ProtheusSyncClient(baseUrl: _apiBaseUrl, apiToken: _apiToken),
          dispose: (_, client) => client.dispose(),
        ),
        ChangeNotifierProvider<MutationSyncService>(
          create: (context) => MutationSyncService(
            store: context.read<PendingMutationStore>(),
            client: context.read<ProtheusSyncClient>(),
          ),
        ),
        ChangeNotifierProvider<ProductionFlowStore>(
          create: (context) => ProductionFlowStore(
            database: context.read<ProductionFlowDatabase>(),
          ),
        ),
        ChangeNotifierProvider<OperatorAssignmentStore>(
          create: (_) => OperatorAssignmentStore(
            persistence: const LocalJsonPersistence(
              'vetti_flow.operator_access.v1',
            ),
          ),
        ),
        ChangeNotifierProvider<WarehouseRequestStore>(
          create: (_) => WarehouseRequestStore(
            database: const LocalWarehouseRequestDatabase(),
          ),
        ),
        Provider<ProtheusProductRepository>(
          create: (_) => ApiProtheusProductRepository(
            baseUrl: _apiBaseUrl,
            apiToken: _apiToken,
          ),
        ),
        Provider<ProtheusWarehouseRepository>(
          create: (_) => ApiProtheusWarehouseRepository(
            baseUrl: _apiBaseUrl,
            apiToken: _apiToken,
          ),
        ),
        Provider<ProtheusOpMovementRepository>(
          create: (_) => ApiProtheusOpMovementRepository(
            baseUrl: _apiBaseUrl,
            apiToken: _apiToken,
          ),
        ),
        Provider<ProtheusCompletionPreviewRepository>(
          create: (_) => ApiProtheusCompletionPreviewRepository(
            baseUrl: _apiBaseUrl,
            apiToken: _apiToken,
          ),
        ),
        Provider<ProtheusTransferRepository>(
          create: (_) => ApiProtheusTransferRepository(
            baseUrl: _apiBaseUrl,
            apiToken: _apiToken,
          ),
        ),
        Provider<ProtheusDismantlingRepository>(
          create: (_) => ApiProtheusDismantlingRepository(
            baseUrl: _apiBaseUrl,
            apiToken: _apiToken,
          ),
        ),
        Provider<ProtheusInventoryAuditRepository>(
          create: (_) => ApiProtheusInventoryAuditRepository(
            baseUrl: _apiBaseUrl,
            apiToken: _apiToken,
          ),
        ),
        Provider<ProtheusWriteReadinessRepository>(
          create: (_) => ApiProtheusWriteReadinessRepository(
            baseUrl: _apiBaseUrl,
            apiToken: _apiToken,
          ),
        ),
        ProxyProvider3<
          ProductionFlowStore,
          ProtheusProductRepository,
          WarehouseRequestStore,
          OpRepository
        >(
          update: (_, flowStore, protheusProducts, warehouseRequests, _) =>
              FlowOpRepository(
                flowStore,
                protheusProducts: protheusProducts,
                warehouseRequests: warehouseRequests,
              ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'VettiFlow',
        theme: AppTheme.light,
        initialRoute: '/login',
        routes: vettiFlowRoutes(),
      ),
    );
  }
}
