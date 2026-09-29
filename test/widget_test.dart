import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_read_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/app/app_routes.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_request.dart';
import 'package:vetti_flow_1_0/data/repositories/flow_op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_database.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_cubit.dart';
import 'package:vetti_flow_1_0/ui/dashboard/dashboard_page.dart';
import 'package:vetti_flow_1_0/ui/dashboard/views/operator_assignments_view.dart';
import 'package:vetti_flow_1_0/ui/dashboard/views/reports_view.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/nova_op_dialog.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/op_detail_panel.dart';
import 'package:vetti_flow_1_0/ui/smd/smd_page.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_page.dart';

import 'fakes/mock_op_repository.dart';

void main() {
  test('every work stage has a registered app route', () {
    final routes = vettiFlowRoutes();

    for (final stage in WorkStage.values) {
      expect(
        routes.keys,
        contains(stage.route),
        reason: '${stage.label} precisa abrir ${stage.route}',
      );
    }
  });

  test('dashboard operator routes to dashboard', () {
    final operator = Operator.authenticate('tatiane', '1001');

    expect(operator, isNotNull);
    expect(operator!.stage, WorkStage.dashboard);
    expect(operator.stage.route, '/dashboard');
  });

  test('tv operator routes to VettiFlow TV', () {
    final operator = Operator.authenticate('tv', '2026');

    expect(operator, isNotNull);
    expect(operator!.stage, WorkStage.tv);
    expect(operator.stage.route, '/tv');
  });

  test('Paula has manager dashboard and SMD pointing credentials', () {
    final manager = Operator.authenticate('paula', '1003');
    final pointer = Operator.authenticate('paula', '4001');

    expect(manager, isNotNull);
    expect(manager!.stage, WorkStage.dashboard);
    expect(manager.stage.route, '/dashboard');
    expect(manager.canManageAssignments, isTrue);
    expect(manager.managesArea, WorkArea.smd);

    expect(pointer, isNotNull);
    expect(pointer!.stage, WorkStage.smd);
    expect(pointer.stage.route, '/smd');
    expect(pointer.canManageAssignments, isFalse);
  });

  test('coordinators and production users have real credentials', () {
    final assignments = OperatorAssignmentStore();

    final tatianeDashboard = assignments.authenticate('tatiane', '1001');
    final tatianeProduction = assignments.authenticate('tatiane', '2001');
    final sabrina = assignments.authenticate('sabrina', '3002');

    expect(tatianeDashboard, isNotNull);
    expect(tatianeDashboard!.stage, WorkStage.dashboard);
    expect(tatianeProduction, isNotNull);
    expect(tatianeProduction!.canManageAssignments, isTrue);
    expect(sabrina, isNotNull);

    assignments.assignStage('sabrina', WorkStage.firmware);
    expect(
      assignments.authenticate('sabrina', '3002')!.stage,
      WorkStage.firmware,
    );
    expect(assignments.findByPin('3002')!.stage, WorkStage.firmware);
  });

  test('assignment managers only see their own sector', () {
    final assignments = OperatorAssignmentStore();

    assignments.authenticate('tatiane', '1001');
    expect(assignments.currentManagedArea, WorkArea.production);
    expect(
      assignments.visibleAssignableOperators.every(
        (operator) => operator.area == WorkArea.production,
      ),
      isTrue,
    );
    assignments.assignStage('rose', WorkStage.firmware);
    expect(
      assignments.authenticate('rose', '4005')!.stage,
      WorkStage.warehouse,
    );

    assignments.authenticate('bruno', '1004');
    expect(assignments.currentManagedArea, WorkArea.support);
    expect(
      assignments.visibleAssignableOperators.map((operator) => operator.name),
      containsAll(['Bruno', 'Douglas', 'David', 'Vinicius', 'Matheus']),
    );

    expect(assignments.stagesFor(Operator.findByPin('4001')!), [WorkStage.smd]);
    assignments.assignStage('paula', WorkStage.firmware);
    expect(assignments.findByPin('4001')!.stage, WorkStage.smd);

    assignments.authenticate('vera', '1005');
    expect(assignments.currentManagedArea, WorkArea.warehouse);
    expect(
      assignments.visibleAssignableOperators.map((operator) => operator.name),
      containsAll(['Vera', 'Luis', 'Rose']),
    );
  });

  testWidgets('mobile team tab uses operator dropdown and stage picker', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final assignments = OperatorAssignmentStore()
      ..authenticate('tatiane', '1001')
      ..assignStage('sabrina', WorkStage.testing);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<OperatorAssignmentStore>.value(
            value: assignments,
          ),
          ChangeNotifierProvider<WarehouseRequestStore>(
            create: (_) => WarehouseRequestStore(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: OperatorAssignmentsView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atribuição local e solicitações'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mobile-operator-selector')), findsOneWidget);
    expect(find.byKey(const Key('mobile-stage-picker')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('mobile-operator-selector')),
    );
    await tester.tap(find.byKey(const Key('mobile-operator-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sabrina').last);
    await tester.pumpAndSettle();

    expect(find.text('Teste'), findsWidgets);

    await tester.tap(find.byKey(const Key('mobile-stage-picker')));
    await tester.pumpAndSettle();

    expect(find.text('Escolher etapa'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-stage-soldering')));
    await tester.pumpAndSettle();

    final sabrina = assignments.visibleAssignableOperators.firstWhere(
      (operator) => operator.username == 'sabrina',
    );
    expect(assignments.stageFor(sabrina), WorkStage.soldering);
  });

  testWidgets('shared top bar auto-compacts on narrow width', (tester) async {
    await _setViewport(tester, const Size(390, 180));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VettiTopBar(
            title: 'Teste de Producao',
            operatorName: 'Operador com nome comprido',
            operatorRole: 'Teste de producao',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teste de Producao'), findsOneWidget);
    expect(find.byTooltip('Sair'), findsOneWidget);
  });

  testWidgets('cancel OP confirmation uses readable mobile layout', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, String>? returns;

    final op = OrdemProducao(
      numero: 'OP-2026-564351',
      produto: '730-0863 - SMART ALARM - MONITORADA CENTRAL',
      qtd: 280,
      responsavel: 'Tatiane',
      dataAbertura: '04/08/2026',
      prazo: '—',
      status: StatusOP.emAndamento,
      progresso: 50,
      mes: 'ago',
      armazem: '05',
      materiaisDetalhados: const [
        MaterialOpDetalhe(
          codigo: '407-004',
          descricao: 'RESISTOR SMD 22K / 0603',
          quantidadePorUnidade: 2,
          quantidadeTotal: 560,
          filial: '04',
          armazem: '03',
          movimentaEstoque: true,
        ),
        MaterialOpDetalhe(
          codigo: '100-010',
          descricao: 'PARAFUSO 2,9 X 6,5 MM ZI',
          quantidadePorUnidade: 1,
          quantidadeTotal: 280,
          filial: '04',
          armazem: '01',
          movimentaEstoque: true,
        ),
        MaterialOpDetalhe(
          codigo: 'MOD-001',
          descricao: 'MAO DE OBRA',
          quantidadePorUnidade: 1,
          quantidadeTotal: 280,
          filial: '04',
          armazem: '05',
          movimentaEstoque: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: OpDetailPanel(
            op: op,
            confirmCancel: true,
            isDesktop: false,
            onClose: () {},
            onAdvance: ({int quantidadeArmazenada = 0}) {},
            onRegress: () {},
            onAskCancel: () {},
            onConfirmCancel: (value, _) => returns = value,
            onCancelNo: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Cancelar OP e devolver empenhos'), findsOneWidget);
    expect(find.text('Retorno por item'), findsOneWidget);
    expect(find.textContaining('407-004'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('cancel-op-operator-pin')));
    await tester.enterText(
      find.byKey(const Key('cancel-op-operator-pin')),
      '4003',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmar cancelamento'));
    await tester.tap(find.text('Confirmar cancelamento'));
    await tester.pumpAndSettle();

    expect(returns?['407-004'], '03');
    expect(returns?['100-010'], '01');
  });

  testWidgets('OP detail shows signatures and hides other sector details', (
    tester,
  ) async {
    final op = OrdemProducao(
      numero: 'OP-AUD-001',
      produto: '730-0863 - SMART ALARM',
      qtd: 50,
      responsavel: 'Paula',
      dataAbertura: '04/08/2026',
      prazo: '—',
      status: StatusOP.emAndamento,
      progresso: 20,
      mes: 'ago',
      stage: ProductionStage.smd,
      materiais: const [('Componente sensivel', 1)],
      tempoTotal: '28min',
      tempoEtapaAtual: '10min',
      pausas: const [
        ResumoPausaOp(
          etapa: 'SMD',
          motivo: 'Banheiro',
          operador: 'Paula',
          tempo: '11s',
          iniciadaEm: '04/08 14:06',
          status: 'Retomada',
        ),
      ],
      assinaturas: const [
        ResumoAssinaturaOp(
          tipo: 'Movimentação',
          etapa: 'SMD',
          operador: 'Paula',
          pin: '**01',
          quando: '04/08 14:10',
          detalhe: 'Concluiu a etapa e liberou a OP',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: OpDetailPanel(
            op: op,
            confirmCancel: false,
            isDesktop: false,
            canEdit: false,
            showSensitiveDetails: false,
            onClose: () {},
            onAdvance: ({int quantidadeArmazenada = 0}) {},
            onRegress: () {},
            onAskCancel: () {},
            onConfirmCancel: (_, _) {},
            onCancelNo: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ASSINATURAS E MOVIMENTAÇÕES'), findsOneWidget);
    expect(find.text('PIN **01'), findsOneWidget);
    expect(find.text('MATERIAIS (BOM)'), findsNothing);
    expect(find.text('TEMPO E PAUSAS'), findsNothing);
    expect(
      find.textContaining('visíveis apenas para o gestor'),
      findsOneWidget,
    );
  });

  test('stores a partial quantity when finishing an OP', () async {
    final repository = MockOpRepository();

    await repository.avancarStatus('OP-2026-0179', quantidadeArmazenada: 25);
    final armazenadas = await repository.fetchOrdensArmazenadas();

    expect(armazenadas.first.numero, 'OP-2026-0179');
    expect(armazenadas.first.quantidadeArmazenada, 25);
    expect(armazenadas.first.tipoLabel, 'Armazenada parcial');
  });

  testWidgets('new OP dialog submits the selected priority', (tester) async {
    NovaOrdemDTO? created;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NovaOpDialog(
            produtos: const ['CR4 - Modulo de 4 zonas com fio'],
            responsaveis: const ['Tatiane'],
            onCreate: (dto) => created = dto,
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('nova-op-due-date')),
      '10/07/2026',
    );
    await tester.ensureVisible(find.text('Media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alta').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Criar OP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar OP'));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.prioridade, 'Alta');
  });

  test(
    'flow repository creates dashboard OPs with selected priority',
    () async {
      final store = ProductionFlowStore(seedOrders: _demoOrders());
      final repository = FlowOpRepository(store);

      final created = await repository.criarOrdem(
        const NovaOrdemDTO(
          produto: 'CR4 - Modulo de 4 zonas com fio',
          qtd: 25,
          responsavel: 'Tatiane',
          prazo: '10/07/2026',
          prioridade: 'Alta',
        ),
      );

      final flowOrder = store.orders.firstWhere(
        (order) => order.number == created.numero,
      );

      expect(flowOrder.priority, 'Alta');
      expect(flowOrder.isHighPriority, isTrue);
      expect(flowOrder.responsavel, isNull);
      expect(created.responsavel, '—');
    },
  );

  test(
    'responsibility is assigned on start and cleared on stage handoff',
    () async {
      final store = ProductionFlowStore(
        seedOrders: [
          ProductionOrderFlow(
            number: 'OP-RESP-001',
            productCode: '575-0845',
            productName: 'SUB MEC SMART MODULO SIRENE SF',
            quantity: 120,
            currentStage: ProductionStage.smd,
            status: ProductionRunStatus.waiting,
            priority: 'Alta',
            createdAt: DateTime(2026, 8, 4, 8),
            updatedAt: DateTime(2026, 8, 4, 8),
          ),
        ],
      );

      await store.startStage(
        'OP-RESP-001',
        operatorName: 'Paula',
        operatorPin: '4001',
      );
      final started = store.orders.single;
      expect(started.responsavel, 'Paula');

      await store.completeStage(
        'OP-RESP-001',
        operatorName: 'Paula',
        operatorPin: '4001',
      );
      final handedOff = store.orders.single;
      expect(handedOff.currentStage, ProductionStage.firmware);
      expect(handedOff.responsavel, isNull);
    },
  );

  test('firmware defects are carried to testing and preserved', () async {
    final store = ProductionFlowStore(
      seedOrders: [
        ProductionOrderFlow(
          number: 'OP-DEF-001',
          productCode: '730-0863',
          productName: 'SMART ALARM - MONITORADA CENTRAL',
          quantity: 50,
          currentStage: ProductionStage.firmware,
          status: ProductionRunStatus.waiting,
          priority: 'Media',
          createdAt: DateTime(2026, 8, 4, 8),
          updatedAt: DateTime(2026, 8, 4, 8),
        ),
      ],
    );

    await store.completeStage(
      'OP-DEF-001',
      operatorName: 'Juliana',
      operatorPin: '3001',
      defects: const [
        DefectRecord(code: 'A', title: 'Nao gravou', quantity: 3),
      ],
    );

    final inTesting = store.orders.single;
    expect(inTesting.currentStage, ProductionStage.soldering);
    expect(inTesting.testDefects.single.quantity, 3);

    await store.completeStage('OP-DEF-001');
    await store.completeTesting(
      'OP-DEF-001',
      defects: const [DefectRecord(code: 'T1', title: 'Nao liga', quantity: 2)],
    );

    final finishedTesting = store.orders.single;
    expect(finishedTesting.testDefects.map((defect) => defect.code), [
      'A',
      'T1',
    ]);
  });

  test('custom planned stages follow the selected order', () async {
    final store = ProductionFlowStore(
      seedOrders: [
        ProductionOrderFlow(
          number: 'OP-ROUTE-001',
          productCode: '730-0863',
          productName: 'SMART ALARM - MONITORADA CENTRAL',
          quantity: 20,
          currentStage: ProductionStage.firmware,
          status: ProductionRunStatus.waiting,
          priority: 'Media',
          createdAt: DateTime(2026, 8, 4, 8),
          updatedAt: DateTime(2026, 8, 4, 8),
        ),
      ],
    );

    await store.updatePlannedStages('OP-ROUTE-001', const [
      ProductionStage.firmware,
      ProductionStage.testing,
      ProductionStage.soldering,
      ProductionStage.expedition,
    ]);
    await store.completeStage('OP-ROUTE-001');

    final testing = store.orders.single;
    expect(testing.currentStage, ProductionStage.testing);

    await store.completeTesting('OP-ROUTE-001', defects: const []);

    final soldering = store.orders.single;
    expect(soldering.currentStage, ProductionStage.soldering);
    expect(soldering.plannedStages, const [
      ProductionStage.firmware,
      ProductionStage.testing,
      ProductionStage.soldering,
      ProductionStage.expedition,
    ]);
  });

  test(
    'stage pause records operator pin, reason and optional quantity',
    () async {
      final store = ProductionFlowStore(seedOrders: _demoOrders());
      final order = store.ordersAtStage(ProductionStage.firmware).first;

      await store.startStage(
        order.number,
        operatorName: 'Juliana',
        operatorPin: '3001',
      );
      await store.pauseStage(
        order.number,
        operatorName: 'Juliana',
        operatorPin: '3001',
        reason: PauseReason.cafe,
        producedQuantity: 18,
      );

      final paused = store.orders.firstWhere((op) => op.number == order.number);
      final session = paused.operatorSessions.singleWhere(
        (item) => item.operatorPin == '3001',
      );

      expect(paused.pauseEvents, hasLength(1));
      expect(paused.pauseEvents.single.reason, PauseReason.cafe);
      expect(paused.pauseEvents.single.operatorPin, '3001');
      expect(session.producedQuantity, 18);
      expect(session.pausedAt, isNotNull);
      expect(paused.status, ProductionRunStatus.paused);

      await store.startStage(
        order.number,
        operatorName: 'Juliana',
        operatorPin: '3001',
      );
      final resumed = store.orders.firstWhere(
        (op) => op.number == order.number,
      );
      expect(resumed.pauseEvents.single.resumedAt, isNotNull);
      expect(
        resumed.pauseEvents.single.pauseDuration(DateTime.now()).inMilliseconds,
        greaterThanOrEqualTo(0),
      );
    },
  );

  test('OP stage advances only after all active operators complete', () async {
    final store = ProductionFlowStore(seedOrders: _demoOrders());
    final order = store.ordersAtStage(ProductionStage.soldering).first;

    await store.startStage(
      order.number,
      operatorName: 'Bryan',
      operatorPin: '3003',
    );
    await store.startStage(
      order.number,
      operatorName: 'Katlyn',
      operatorPin: '3007',
    );

    await store.completeStage(
      order.number,
      operatorName: 'Bryan',
      operatorPin: '3003',
    );

    final waitingForKatlyn = store.orders.firstWhere(
      (op) => op.number == order.number,
    );
    expect(waitingForKatlyn.currentStage, ProductionStage.soldering);
    expect(waitingForKatlyn.status, ProductionRunStatus.active);
    expect(
      waitingForKatlyn.operatorSessions
          .singleWhere((item) => item.operatorPin == '3003')
          .completedAt,
      isNotNull,
    );
    expect(
      waitingForKatlyn.operatorSessions
          .singleWhere((item) => item.operatorPin == '3003')
          .workedDuration(DateTime.now())
          .inMilliseconds,
      greaterThanOrEqualTo(0),
    );
    expect(
      waitingForKatlyn.operatorSessions
          .singleWhere((item) => item.operatorPin == '3007')
          .completedAt,
      isNull,
    );

    await store.completeStage(
      order.number,
      operatorName: 'Katlyn',
      operatorPin: '3007',
    );

    final completed = store.orders.firstWhere(
      (op) => op.number == order.number,
    );
    expect(completed.currentStage, ProductionStage.testing);
    expect(completed.status, ProductionRunStatus.waiting);
  });

  test('stage movement is persisted to the configured database', () async {
    final database = _RecordingProductionFlowDatabase();
    final store = ProductionFlowStore(
      database: database,
      seedOrders: [
        ProductionOrderFlow(
          number: 'OP-2026-564400',
          productCode: '575-0845',
          productName: 'SUB MEC SMART MODULO SIRENE SF',
          quantity: 120,
          currentStage: ProductionStage.warehouse,
          status: ProductionRunStatus.waiting,
          priority: 'Alta',
          createdAt: DateTime(2026, 8, 3, 8),
          updatedAt: DateTime(2026, 8, 3, 8),
        ),
      ],
    );

    await store.startStage(
      'OP-2026-564400',
      operatorName: 'Vera',
      operatorPin: '4003',
    );
    await store.completeStage(
      'OP-2026-564400',
      operatorName: 'Vera',
      operatorPin: '4003',
      observation: 'Separado completo',
    );

    final persisted = database.savedOrders.last;
    expect(persisted.number, 'OP-2026-564400');
    expect(persisted.currentStage, ProductionStage.smd);
    expect(persisted.lastObservation, 'Separado completo');
    expect(persisted.operatorSessions.single.operatorName, 'Vera');
    expect(persisted.operatorSessions.single.operatorPin, '4003');
    expect(persisted.operatorSessions.single.completedAt, isNotNull);
    expect(database.eventTypes.last, 'updated');
  });

  test(
    'SMD stage advances to production firmware after Paula points it',
    () async {
      final database = _RecordingProductionFlowDatabase();
      final store = ProductionFlowStore(
        database: database,
        seedOrders: [
          ProductionOrderFlow(
            number: 'OP-2026-564401',
            productCode: '575-0845',
            productName: 'SUB MEC SMART MODULO SIRENE SF',
            quantity: 120,
            currentStage: ProductionStage.smd,
            status: ProductionRunStatus.waiting,
            priority: 'Alta',
            createdAt: DateTime(2026, 8, 4, 8),
            updatedAt: DateTime(2026, 8, 4, 8),
          ),
        ],
      );

      await store.startStage(
        'OP-2026-564401',
        operatorName: 'Paula',
        operatorPin: '4001',
      );
      await store.completeStage(
        'OP-2026-564401',
        operatorName: 'Paula',
        operatorPin: '4001',
      );

      final persisted = database.savedOrders.last;
      expect(persisted.currentStage, ProductionStage.firmware);
      expect(persisted.operatorSessions.single.stage, ProductionStage.smd);
      expect(persisted.operatorSessions.single.operatorName, 'Paula');
    },
  );

  test('OP creation is persisted to the configured database', () async {
    final database = _RecordingProductionFlowDatabase();
    final store = ProductionFlowStore(database: database);

    final created = await store.createOrder(
      productCode: '575-0845',
      productName: 'SUB MEC SMART MODULO SIRENE SF',
      quantity: 120,
      priority: 'Alta',
      operatorName: 'Tatiane',
      operatorPin: '2001',
      responsavel: 'Tatiane',
      orderWarehouse: '05',
      components: const [
        ProductionComponent(
          code: '550-0845',
          description: 'Componente mecanico',
          quantity: 1,
          stock: 897,
          filial: '04',
          armazem: '05',
          currentStock: 897,
        ),
      ],
    );

    expect(database.savedOrders.single.number, created.number);
    expect(database.savedOrders.single.currentStage, ProductionStage.warehouse);
    expect(database.savedOrders.single.orderWarehouse, '05');
    expect(
      database.savedCatalogItems.single.components.single.code,
      '550-0845',
    );
    expect(database.eventTypes.single, 'created');
  });

  test('two apps on the same database never share an OP number', () async {
    // O cenario real: duas maquinas apontando para o mesmo banco. Antes da
    // sequence cada app carregava seu proprio contador e os dois chegavam no
    // mesmo `OP-<ano>-N` — e o upsert do `saveOrder` sobrescrevia a OP de quem
    // gravou primeiro, em silencio.
    final database = _RecordingProductionFlowDatabase()..nextSequence = 900100;
    final vitor = ProductionFlowStore(database: database);
    final leonardo = ProductionFlowStore(database: database);

    Future<String> createOn(ProductionFlowStore store, String operator) async {
      final order = await store.createOrder(
        productCode: '575-0845',
        productName: 'SUB MEC SMART MODULO SIRENE SF',
        quantity: 10,
        priority: 'Media',
        operatorName: operator,
        orderWarehouse: '05',
      );
      return order.number;
    }

    final numbers = [
      await createOn(vitor, 'Vitor'),
      await createOn(leonardo, 'Leonardo'),
      await createOn(vitor, 'Vitor'),
    ];

    expect(numbers.toSet(), hasLength(3));
    expect(numbers, [
      endsWith('-900100'),
      endsWith('-900101'),
      endsWith('-900102'),
    ]);
    expect(database.sequenceCalls, 3);
  });

  test(
    'OP number falls back to the local counter without a database',
    () async {
      // Banco fora do ar: `nextOrderSequence` devolve null e a OP ainda nasce,
      // com numero local, para o app seguir funcionando offline.
      final database = _RecordingProductionFlowDatabase();
      final store = ProductionFlowStore(database: database);

      final created = await store.createOrder(
        productCode: '575-0845',
        productName: 'SUB MEC SMART MODULO SIRENE SF',
        quantity: 10,
        priority: 'Media',
        operatorName: 'Tatiane',
        orderWarehouse: '05',
      );

      expect(created.number, startsWith('OP-'));
      expect(database.sequenceCalls, 1);
      expect(database.savedOrders.single.number, created.number);
    },
  );

  test(
    'cancel order sends stock return choices to the configured database',
    () async {
      final database = _RecordingProductionFlowDatabase();
      final store = ProductionFlowStore(database: database);
      final created = await store.createOrder(
        productCode: '730-0863',
        productName: 'SMART ALARM - MONITORADA CENTRAL',
        quantity: 4,
        priority: 'Media',
        operatorName: 'Tatiane',
        operatorPin: '2001',
        orderWarehouse: '05',
        components: const [
          ProductionComponent(
            code: '100-010',
            description: 'PARAFUSO 2,9 X 6,5 MM ZI',
            quantity: 3,
            stock: 7514,
            filial: '04',
            armazem: '01',
            currentStock: 7514,
          ),
          ProductionComponent(
            code: 'MOD-001',
            description: 'MAO DE OBRA',
            quantity: 1,
            stock: -999,
            filial: '04',
            armazem: '05',
          ),
        ],
      );

      await store.cancelOrder(
        created.number,
        returnWarehouses: const {'100-010': '05'},
        operatorName: 'Tatiane',
        operatorPin: '2001',
      );

      expect(
        store.orders.any((order) => order.number == created.number),
        isFalse,
      );
      expect(database.deletedNumbers.single, created.number);
      expect(database.deletedOrders.single.number, created.number);
      expect(database.deletedOrders.single.orderWarehouse, '05');
      expect(
        database.deletedCatalogItems.single.components.first.code,
        '100-010',
      );
      expect(database.deletedReturnWarehouses.single, {'100-010': '05'});
    },
  );

  testWidgets('shows the initial login screen', (tester) async {
    await tester.pumpWidget(_testApp());

    expect(find.text('Entrar no sistema'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('navigates from login to firmware screen', (tester) async {
    await tester.pumpWidget(_testApp());

    await tester.enterText(find.byType(TextFormField).first, 'juliana');
    await tester.enterText(find.byType(TextFormField).last, '3001');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Gravacao de Firmware'), findsOneWidget);
    expect(find.text('OP-00564-345'), findsWidgets);
  });

  testWidgets('navigates from login to tv dashboard', (tester) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());

    await tester.enterText(find.byType(TextFormField).first, 'tv');
    await tester.enterText(find.byType(TextFormField).last, '2026');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('VETTIFLOW TV'), findsOneWidget);
    expect(find.text('Producao em andamento'), findsOneWidget);
  });

  testWidgets('firmware screen renders on mobile viewport', (tester) async {
    await _setViewport(tester, const Size(430, 932));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/firmware'));
    await tester.pumpAndSettle();

    expect(find.text('OPs disponiveis'), findsOneWidget);
    // Mobile: cards aparecem, acoes so no bottom sheet ao tocar.
    expect(find.text('OP-00564-345'), findsOneWidget);
  });

  testWidgets('firmware screen renders on desktop viewport', (tester) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/firmware'));
    await tester.pumpAndSettle();

    expect(find.text('Quantidade'), findsOneWidget);
    expect(find.text('Acoes da OP'), findsOneWidget);
  });

  testWidgets('soldering screen renders core actions', (tester) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/soldagem'));
    await tester.pumpAndSettle();

    expect(find.text('Soldagem'), findsWidgets);
    expect(find.text('OPs para soldagem'), findsOneWidget);
    expect(find.text('Pausar OP'), findsOneWidget);
    expect(find.text('Enviar para proxima etapa'), findsOneWidget);

    await tester.ensureVisible(find.text('Pausar OP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pausar OP'));
    await tester.pumpAndSettle();

    expect(find.text('Motivo da pausa'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '3003');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Pausar'));
    await tester.pumpAndSettle();

    expect(find.text('Retomar OP'), findsOneWidget);
    expect(find.text('Enviar para proxima etapa'), findsOneWidget);
  });

  testWidgets('pause reason outro requires an explanation', (tester) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/soldagem'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pausar OP'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pause-reason-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outro').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pause-custom-reason')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('pause-pin')), '3003');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Pausar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe o motivo da pausa.'), findsOneWidget);
    expect(find.text('Pausar OP'), findsWidgets);
  });

  testWidgets('dashboard shows stored tab and stored orders', (tester) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = MockOpRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductionFlowStore>(
            create: (_) => ProductionFlowStore(seedOrders: _demoOrders()),
          ),
          ChangeNotifierProvider<OperatorAssignmentStore>(
            create: (_) => OperatorAssignmentStore(),
          ),
          ChangeNotifierProvider<WarehouseRequestStore>(
            create: (_) => WarehouseRequestStore(),
          ),
          RepositoryProvider<OpRepository>.value(value: repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider(
            create: (_) => DashboardCubit(repository),
            child: const DashboardPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Armazenadas'), findsOneWidget);

    await tester.tap(find.text('Armazenadas'));
    await tester.pumpAndSettle();

    expect(find.text('OPs armazenadas'), findsOneWidget);
    expect(find.text('OP-2026-0172'), findsOneWidget);
  });

  testWidgets('dashboard reports tab renders production report panels', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = MockOpRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductionFlowStore>(
            create: (_) => ProductionFlowStore(seedOrders: _demoOrders()),
          ),
          ChangeNotifierProvider<OperatorAssignmentStore>(
            create: (_) => OperatorAssignmentStore(),
          ),
          ChangeNotifierProvider<WarehouseRequestStore>(
            create: (_) => WarehouseRequestStore(),
          ),
          RepositoryProvider<OpRepository>.value(value: repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider(
            create: (_) => DashboardCubit(repository),
            child: const DashboardPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Relatórios'));
    await tester.pumpAndSettle();

    expect(find.text('Relatórios de Produção'), findsOneWidget);
    expect(find.text('Tempo por etapa'), findsWidgets);
    expect(find.text('Produção e defeitos por produto'), findsOneWidget);
    expect(find.text('Detalhamento das OPs'), findsOneWidget);
  });

  testWidgets('reports collaborator time panel fits mobile width', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 640));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final order = ProductionOrderFlow(
      number: 'OP-2026-564351',
      productCode: '730-0863',
      productName: 'SMART ALARM - MONITORADA CENTRAL',
      quantity: 50,
      currentStage: ProductionStage.testing,
      status: ProductionRunStatus.active,
      priority: 'Alta',
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(minutes: 5)),
      pauseEvents: [
        ProductionPauseEvent(
          stage: ProductionStage.smd,
          operatorName: 'Paula',
          operatorPin: '4001',
          reason: PauseReason.banheiro,
          createdAt: now.subtract(const Duration(seconds: 11)),
        ),
      ],
      operatorSessions: [
        ProductionOperatorSession(
          stage: ProductionStage.expedition,
          operatorName: 'Gisele',
          operatorPin: '3020',
          startedAt: now.subtract(const Duration(hours: 1, minutes: 18)),
        ),
        ProductionOperatorSession(
          stage: ProductionStage.testing,
          operatorName: 'Giovana',
          operatorPin: '3004',
          startedAt: now.subtract(const Duration(hours: 1, minutes: 31)),
        ),
        ProductionOperatorSession(
          stage: ProductionStage.soldering,
          operatorName: 'Katlyn',
          operatorPin: '3007',
          startedAt: now.subtract(const Duration(minutes: 4)),
          completedAt: now.subtract(const Duration(minutes: 3)),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ProductionFlowStore>(
        create: (_) => ProductionFlowStore(seedOrders: [order]),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(14),
              child: ReportsView(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tempo por colaborador'), findsOneWidget);
    expect(find.text('Pausas e saidas'), findsOneWidget);
    expect(find.text('Paula'), findsOneWidget);
    expect(find.text('Banheiro'), findsOneWidget);
    expect(find.text('Gisele'), findsOneWidget);
    expect(find.text('Expedicao'), findsWidgets);
    expect(find.text('rodando'), findsWidgets);
  });

  testWidgets('reports scope timing details to the manager area', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 8, 4, 10);
    final store = ProductionFlowStore(
      seedOrders: [
        ProductionOrderFlow(
          number: 'OP-SCOPE-001',
          productCode: '730-0863',
          productName: 'SMART ALARM',
          quantity: 10,
          currentStage: ProductionStage.firmware,
          status: ProductionRunStatus.waiting,
          priority: 'Media',
          createdAt: now,
          updatedAt: now,
          timings: {
            ProductionStage.warehouse: ProductionStageTiming(
              startedAt: now.subtract(const Duration(hours: 3)),
              completedAt: now.subtract(const Duration(hours: 2)),
            ),
            ProductionStage.smd: ProductionStageTiming(
              startedAt: now.subtract(const Duration(hours: 2)),
              completedAt: now.subtract(const Duration(hours: 1)),
            ),
          },
          operatorSessions: [
            ProductionOperatorSession(
              stage: ProductionStage.warehouse,
              operatorName: 'Vera',
              operatorPin: '4003',
              startedAt: now.subtract(const Duration(hours: 3)),
              completedAt: now.subtract(const Duration(hours: 2)),
            ),
            ProductionOperatorSession(
              stage: ProductionStage.smd,
              operatorName: 'Paula',
              operatorPin: '4001',
              startedAt: now.subtract(const Duration(hours: 2)),
              completedAt: now.subtract(const Duration(hours: 1)),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ProductionFlowStore>.value(
        value: store,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReportsView(visibleArea: WorkArea.warehouse),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Almoxarifado'), findsWidgets);
    expect(find.text('Vera'), findsWidgets);
    expect(find.text('Paula'), findsNothing);
  });

  for (final username in ['paula', 'leandro']) {
    testWidgets('$username sees official SMD orders from the read API', (
      tester,
    ) async {
      await _setViewport(tester, const Size(1366, 768));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final user = Operator.all.firstWhere((o) => o.username == username);
      final assignments = OperatorAssignmentStore()
        ..authenticate(user.username, user.password);
      final repository = WarehouseReadRepository(
        baseUrl: 'http://api',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.queryParameters['local'], '03');
          expect(request.url.queryParameters['view'], 'orders');
          return http.Response(
            jsonEncode({
              'total': 1,
              'items': [
                {
                  'id': 'SC2:1',
                  'op': '01600101001',
                  'code': '500-0001',
                  'description': 'Placa SMD',
                  'quantity': 120,
                  'produced': 20,
                  'unit': 'PC',
                  'closed': 0,
                  'date': '20260804',
                },
              ],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: assignments),
            Provider.value(value: repository),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const SmdPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('01600101001'), findsOneWidget);
      expect(find.textContaining('Restante: 100'), findsOneWidget);
      expect(find.text('Concluir apontamento'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      assignments.dispose();
    });
  }

  testWidgets('warehouse pointing screen does not offer OP creation', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductionFlowStore>(
            create: (_) => ProductionFlowStore(),
          ),
          ChangeNotifierProvider<OperatorAssignmentStore>(
            create: (_) =>
                OperatorAssignmentStore()..authenticate('vera', '4003'),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const WarehousePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criar OP'), findsNothing);
    expect(find.text('Criar OP no almoxarifado'), findsNothing);
  });

  testWidgets(
    'Tatiane sees warehouse and SMD orders as read only in dashboard',
    (tester) async {
      await _setViewport(tester, const Size(1366, 768));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MockOpRepository();
      final assignments = OperatorAssignmentStore()
        ..authenticate('tatiane', '1001');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProductionFlowStore>(
              create: (_) => ProductionFlowStore(seedOrders: _demoOrders()),
            ),
            ChangeNotifierProvider<OperatorAssignmentStore>.value(
              value: assignments,
            ),
            ChangeNotifierProvider<WarehouseRequestStore>(
              create: (_) => WarehouseRequestStore(),
            ),
            RepositoryProvider<OpRepository>.value(value: repository),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: BlocProvider(
              create: (_) => DashboardCubit(repository),
              child: const DashboardPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('OP-2026-0188'));
      await tester.pumpAndSettle();

      expect(find.text('Somente visualização'), findsOneWidget);
      expect(
        find.textContaining('Tatiane pode acompanhar esta OP'),
        findsOneWidget,
      );
      expect(find.textContaining('Avançar p/'), findsNothing);
      expect(find.text('Voltar etapa'), findsNothing);
      expect(find.text('Cancelar OP'), findsNothing);
    },
  );

  testWidgets('Tatiane can still move production orders in dashboard', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ProductionFlowStore(
      seedOrders: [
        ProductionOrderFlow(
          number: 'OP-PROD-001',
          productCode: '730-0863',
          productName: 'SMART ALARM - MONITORADA CENTRAL',
          quantity: 10,
          currentStage: ProductionStage.firmware,
          status: ProductionRunStatus.waiting,
          priority: 'Media',
          createdAt: DateTime(2026, 8, 4, 8),
          updatedAt: DateTime(2026, 8, 4, 8),
        ),
      ],
    );
    final repository = FlowOpRepository(store);
    final assignments = OperatorAssignmentStore()
      ..authenticate('tatiane', '1001');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductionFlowStore>.value(value: store),
          ChangeNotifierProvider<OperatorAssignmentStore>.value(
            value: assignments,
          ),
          ChangeNotifierProvider<WarehouseRequestStore>(
            create: (_) => WarehouseRequestStore(),
          ),
          RepositoryProvider<OpRepository>.value(value: repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider(
            create: (_) => DashboardCubit(repository),
            child: const DashboardPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OP-PROD-001'));
    await tester.pumpAndSettle();

    expect(find.text('Somente visualização'), findsNothing);
    expect(find.text('Avançar p/ Soldagem'), findsOneWidget);
  });

  testWidgets('Vera can move warehouse orders from manager dashboard', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ProductionFlowStore(
      seedOrders: [
        ProductionOrderFlow(
          number: 'OP-WH-001',
          productCode: '730-0863',
          productName: 'SMART ALARM - MONITORADA CENTRAL',
          quantity: 10,
          currentStage: ProductionStage.warehouse,
          status: ProductionRunStatus.waiting,
          priority: 'Media',
          createdAt: DateTime(2026, 8, 4, 8),
          updatedAt: DateTime(2026, 8, 4, 8),
        ),
      ],
    );
    final repository = FlowOpRepository(store);
    final assignments = OperatorAssignmentStore()..authenticate('vera', '1005');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductionFlowStore>.value(value: store),
          ChangeNotifierProvider<OperatorAssignmentStore>.value(
            value: assignments,
          ),
          ChangeNotifierProvider<WarehouseRequestStore>(
            create: (_) => WarehouseRequestStore(),
          ),
          RepositoryProvider<OpRepository>.value(value: repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider(
            create: (_) => DashboardCubit(repository),
            child: const DashboardPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OP-WH-001'));
    await tester.pumpAndSettle();

    expect(find.text('Somente visualização'), findsNothing);
    expect(find.text('Avançar p/ SMD'), findsOneWidget);

    await tester.tap(find.text('Avançar p/ SMD'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '4003');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir OP'));
    await tester.pumpAndSettle();

    expect(store.ordersAtStage(ProductionStage.smd).single.number, 'OP-WH-001');
  });

  testWidgets('dashboard shows database loading while advancing an order', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ProductionFlowStore(
      seedOrders: [
        ProductionOrderFlow(
          number: 'OP-WH-LOADING-001',
          productCode: '730-0863',
          productName: 'SMART ALARM - MONITORADA CENTRAL',
          quantity: 10,
          currentStage: ProductionStage.warehouse,
          status: ProductionRunStatus.waiting,
          priority: 'Media',
          createdAt: DateTime(2026, 8, 4, 8),
          updatedAt: DateTime(2026, 8, 4, 8),
        ),
      ],
    );
    final repository = _DelayedAdvanceRepository(store);
    final assignments = OperatorAssignmentStore()..authenticate('vera', '1005');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductionFlowStore>.value(value: store),
          ChangeNotifierProvider<OperatorAssignmentStore>.value(
            value: assignments,
          ),
          ChangeNotifierProvider<WarehouseRequestStore>(
            create: (_) => WarehouseRequestStore(),
          ),
          RepositoryProvider<OpRepository>.value(value: repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider(
            create: (_) => DashboardCubit(repository),
            child: const DashboardPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OP-WH-LOADING-001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar p/ SMD'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '4003');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir OP'));
    await tester.pump();
    await repository.advanceStarted.future;
    await tester.pump();

    expect(find.text('Atualizando bancos'), findsOneWidget);
    expect(find.textContaining('assinatura de Vera'), findsOneWidget);

    repository.releaseAdvance.complete();
    await tester.pumpAndSettle();

    expect(find.text('Atualizando bancos'), findsNothing);
    expect(
      store.ordersAtStage(ProductionStage.smd).single.number,
      'OP-WH-LOADING-001',
    );
  });

  testWidgets('Paula can move SMD orders from manager dashboard to firmware', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ProductionFlowStore(
      seedOrders: [
        ProductionOrderFlow(
          number: 'OP-SMD-DASH-001',
          productCode: '575-0845',
          productName: 'SUB MEC SMART MODULO SIRENE SF',
          quantity: 120,
          currentStage: ProductionStage.smd,
          status: ProductionRunStatus.waiting,
          priority: 'Alta',
          createdAt: DateTime(2026, 8, 4, 8),
          updatedAt: DateTime(2026, 8, 4, 8),
        ),
      ],
    );
    final repository = FlowOpRepository(store);
    final assignments = OperatorAssignmentStore()
      ..authenticate('paula', '1003');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductionFlowStore>.value(value: store),
          ChangeNotifierProvider<OperatorAssignmentStore>.value(
            value: assignments,
          ),
          ChangeNotifierProvider<WarehouseRequestStore>(
            create: (_) => WarehouseRequestStore(),
          ),
          RepositoryProvider<OpRepository>.value(value: repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider(
            create: (_) => DashboardCubit(repository),
            child: const DashboardPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OP-SMD-DASH-001'));
    await tester.pumpAndSettle();

    expect(find.text('Somente visualização'), findsNothing);
    expect(find.text('Avançar p/ Gravacao'), findsOneWidget);

    await tester.tap(find.text('Avançar p/ Gravacao'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1003');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir OP'));
    await tester.pumpAndSettle();

    expect(
      store.ordersAtStage(ProductionStage.firmware).single.number,
      'OP-SMD-DASH-001',
    );
  });

  testWidgets('Vera confirms and rejects warehouse requests from dashboard', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = MockOpRepository();
    final assignments = OperatorAssignmentStore()..authenticate('vera', '1005');
    final requests = WarehouseRequestStore(
      seedRequests: [
        WarehouseConfirmationRequest(
          id: 'OP-001-100-010-01',
          orderNumber: 'OP-001',
          productCode: '730-0863',
          productName: 'SMART ALARM - MONITORADA CENTRAL',
          componentCode: '100-010',
          componentDescription: 'PARAFUSO 2,9 X 6,5 MM ZI',
          quantity: 24,
          filial: '04',
          orderWarehouse: '05',
          requestedWarehouse: '01',
          requestedBy: 'Tatiane',
          createdAt: DateTime(2026, 8, 4, 9),
          updatedAt: DateTime(2026, 8, 4, 9),
        ),
        WarehouseConfirmationRequest(
          id: 'OP-002-100-020-01',
          orderNumber: 'OP-002',
          productCode: '730-0863',
          productName: 'SMART ALARM - MONITORADA CENTRAL',
          componentCode: '100-020',
          componentDescription: 'ITEM SEM SALDO REAL',
          quantity: 5,
          filial: '04',
          orderWarehouse: '05',
          requestedWarehouse: '01',
          requestedBy: 'Tatiane',
          createdAt: DateTime(2026, 8, 4, 10),
          updatedAt: DateTime(2026, 8, 4, 10),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductionFlowStore>(
            create: (_) => ProductionFlowStore(seedOrders: _demoOrders()),
          ),
          ChangeNotifierProvider<OperatorAssignmentStore>.value(
            value: assignments,
          ),
          ChangeNotifierProvider<WarehouseRequestStore>.value(value: requests),
          RepositoryProvider<OpRepository>.value(value: repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider(
            create: (_) => DashboardCubit(repository),
            child: const DashboardPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Responsáveis'));
    await tester.pumpAndSettle();

    expect(find.text('Requisições de armazém'), findsOneWidget);
    expect(find.textContaining('100-010'), findsOneWidget);
    expect(find.text('Fazer requisição'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('warehouse-request-confirm-OP-001-100-010-01')),
    );
    await tester.pumpAndSettle();
    expect(
      requests.requests
          .firstWhere((request) => request.id == 'OP-001-100-010-01')
          .status,
      WarehouseRequestStatus.confirmed,
    );

    await tester.tap(
      find.byKey(const Key('warehouse-request-reject-OP-002-100-020-01')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('warehouse-request-reject-submit')));
    await tester.pumpAndSettle();
    expect(find.text('A explicacao e obrigatoria.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('warehouse-request-reject-note')),
      'Saldo fisico nao existe no 01',
    );
    await tester.tap(find.byKey(const Key('warehouse-request-reject-submit')));
    await tester.pumpAndSettle();

    final rejected = requests.requests.firstWhere(
      (request) => request.id == 'OP-002-100-020-01',
    );
    expect(rejected.status, WarehouseRequestStatus.rejected);
    expect(rejected.responseNote, 'Saldo fisico nao existe no 01');
  });

  testWidgets('warehouse delivery dialog requires and returns operator PIN', (
    tester,
  ) async {
    WarehouseDeliveryConfirmation? confirmation;
    const request = WarehouseRequest(
      number: 'REQ-64352',
      operation: 'OP-2026-564352',
      product: '575-0845 - SUB MEC SMART MODULO SIRENE SF',
      requestedBy: 'Tatiane',
      priority: 'Media',
      createdAt: '16:13',
      status: 'Em separacao',
      items: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              confirmation = await showWarehouseDeliveryDialog(
                context,
                request: request,
              );
            },
            child: const Text('Abrir entrega'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir entrega'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar entrega'));
    await tester.pumpAndSettle();

    expect(find.text('Informe o PIN.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('warehouse-delivery-pin')),
      '4003',
    );
    await tester.enterText(
      find.byKey(const Key('warehouse-delivery-observation')),
      'Separado completo',
    );
    await tester.tap(find.text('Confirmar entrega'));
    await tester.pumpAndSettle();

    expect(confirmation?.operatorPin, '4003');
    expect(confirmation?.observation, 'Separado completo');
  });

  testWidgets('expedition dispatches partial and full stored quantity', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/expedicao/fluxo-local'));
    await tester.pumpAndSettle();

    expect(find.text('Armazenadas'), findsOneWidget);

    await tester.tap(find.text('Armazenadas'));
    await tester.pumpAndSettle();

    expect(find.text('OPs armazenadas'), findsOneWidget);
    expect(find.text('Expedidas'), findsOneWidget);
    expect(find.text('OP-00563-992'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Expedir').first);
    await tester.pumpAndSettle();

    expect(find.text('Expedir armazenada'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '80');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Expedir').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('100 un'), findsWidgets);
    expect(find.textContaining('80 un'), findsWidgets);
    expect(find.textContaining('Armazenamento'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Expedir').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Expedir').last);
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma OP armazenada.'), findsWidgets);
  });

  testWidgets('expedition finish preview shows stored and dispatched split', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/expedicao/fluxo-local'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Iniciar conferencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar conferencia'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Finalizar despacho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar despacho'));
    await tester.pumpAndSettle();

    expect(find.text('Disponivel'), findsOneWidget);
    expect(find.text('Vai armazenar'), findsOneWidget);
    expect(find.text('Sera expedido'), findsOneWidget);
    expect(find.text('300 un'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pumpAndSettle();

    expect(find.text('100 un'), findsOneWidget);
    expect(find.text('200 un'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '3006');
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Finalizar'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Finalizar'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Armazenadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Armazenadas'));
    await tester.pumpAndSettle();

    expect(find.text('OP-00564-352'), findsWidgets);
    expect(find.textContaining('100 un'), findsWidgets);
    expect(find.textContaining('200 un'), findsWidgets);
  });

  testWidgets('tv dashboard rotates through production panels', (tester) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/tv'));
    await tester.pumpAndSettle();

    expect(find.text('VETTIFLOW TV'), findsOneWidget);
    expect(find.text('Producao em andamento'), findsOneWidget);

    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();

    expect(find.text('Fluxo por etapa'), findsOneWidget);
  });

  testWidgets('tv dashboard fits compact desktop viewport', (tester) async {
    await _setViewport(tester, const Size(1024, 600));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/tv'));
    await tester.pumpAndSettle();

    expect(find.text('VETTIFLOW TV'), findsOneWidget);
    expect(find.text('Producao em andamento'), findsOneWidget);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

List<ProductionOrderFlow> _demoOrders() {
  final now = DateTime.now();
  return [
    ProductionOrderFlow(
      number: 'OP-00564-345',
      productCode: 'CR4',
      productName: 'Modulo de 4 zonas com fio',
      quantity: 3000,
      currentStage: ProductionStage.firmware,
      status: ProductionRunStatus.waiting,
      priority: 'Alta',
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(minutes: 24)),
    ),
    ProductionOrderFlow(
      number: 'OP-00564-348',
      productCode: 'SMARTALARM32-V6',
      productName: 'Central SmartAlarm32 V6.68',
      quantity: 500,
      currentStage: ProductionStage.soldering,
      status: ProductionRunStatus.active,
      priority: 'Media',
      createdAt: now.subtract(const Duration(hours: 4)),
      updatedAt: now.subtract(const Duration(minutes: 8)),
      timings: {
        ProductionStage.soldering: ProductionStageTiming(
          startedAt: now.subtract(const Duration(minutes: 18)),
        ),
      },
    ),
    ProductionOrderFlow(
      number: 'OP-00564-350',
      productCode: 'INFRA-LONGO',
      productName: 'Sensor infravermelho alcance longo',
      quantity: 650,
      currentStage: ProductionStage.testing,
      status: ProductionRunStatus.paused,
      priority: 'Baixa',
      createdAt: now.subtract(const Duration(hours: 5)),
      updatedAt: now.subtract(const Duration(minutes: 4)),
      timings: {
        ProductionStage.testing: ProductionStageTiming(
          startedAt: now.subtract(const Duration(minutes: 35)),
          pausedAt: now.subtract(const Duration(minutes: 4)),
        ),
      },
    ),
    ProductionOrderFlow(
      number: 'OP-00564-351',
      productCode: 'SMART-TECLADO',
      productName: 'Teclado inteligente',
      quantity: 450,
      currentStage: ProductionStage.closing,
      status: ProductionRunStatus.waiting,
      priority: 'Media',
      createdAt: now.subtract(const Duration(hours: 5)),
      updatedAt: now.subtract(const Duration(minutes: 6)),
    ),
    ProductionOrderFlow(
      number: 'OP-00564-352',
      productCode: 'SIRENE-SF',
      productName: 'Sirene sem fio',
      quantity: 300,
      currentStage: ProductionStage.expedition,
      status: ProductionRunStatus.waiting,
      priority: 'Media',
      createdAt: now.subtract(const Duration(hours: 6)),
      updatedAt: now.subtract(const Duration(minutes: 2)),
      orderWarehouse: '05',
    ),
    ProductionOrderFlow(
      number: 'OP-00563-992',
      productCode: 'MAG-CURTO',
      productName: 'Sensor magnetico alcance curto',
      quantity: 900,
      currentStage: ProductionStage.storage,
      status: ProductionRunStatus.completed,
      priority: 'Baixa',
      createdAt: now.subtract(const Duration(hours: 8)),
      updatedAt: now.subtract(const Duration(minutes: 30)),
      storedQuantity: 180,
      dispatchedQuantity: 720,
    ),
  ];
}

Widget _testApp({String initialRoute = '/login'}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProductionFlowStore>(
        create: (_) => ProductionFlowStore(seedOrders: _demoOrders()),
      ),
      ChangeNotifierProvider<OperatorAssignmentStore>(
        create: (_) => OperatorAssignmentStore(),
      ),
      ChangeNotifierProvider<WarehouseRequestStore>(
        create: (_) => WarehouseRequestStore(),
      ),
      RepositoryProvider<OpRepository>(create: (_) => MockOpRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      initialRoute: initialRoute,
      routes: vettiFlowRoutes(),
    ),
  );
}

class _RecordingProductionFlowDatabase implements ProductionFlowDatabase {
  final savedOrders = <ProductionOrderFlow>[];
  final savedCatalogItems = <ProductionCatalogItem>[];
  final eventTypes = <String>[];
  final deletedNumbers = <String>[];
  final deletedOrders = <ProductionOrderFlow>[];
  final deletedCatalogItems = <ProductionCatalogItem>[];
  final deletedReturnWarehouses = <Map<String, String>>[];

  /// Numeros que o "banco" devolveu. `null` faz o store cair no contador local.
  int? nextSequence;
  var sequenceCalls = 0;

  @override
  Future<int?> nextOrderSequence() async {
    sequenceCalls++;
    final reserved = nextSequence;
    if (reserved != null) nextSequence = reserved + 1;
    return reserved;
  }

  @override
  Future<void> deleteOrder(
    String number, {
    ProductionOrderFlow? order,
    ProductionCatalogItem? catalogItem,
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) async {
    deletedNumbers.add(number);
    if (order != null) deletedOrders.add(order);
    if (catalogItem != null) deletedCatalogItems.add(catalogItem);
    deletedReturnWarehouses.add(Map.of(returnWarehouses));
  }

  @override
  Future<ProductionFlowSnapshot> loadSnapshot() async {
    return const ProductionFlowSnapshot(orders: [], catalogItems: []);
  }

  @override
  Future<void> saveOrder(
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem, {
    required String eventType,
  }) async {
    await Future<void>.delayed(Duration.zero);
    savedOrders.add(order);
    savedCatalogItems.add(catalogItem);
    eventTypes.add(eventType);
  }
}

class _DelayedAdvanceRepository extends FlowOpRepository {
  _DelayedAdvanceRepository(super.store);

  final advanceStarted = Completer<void>();
  final releaseAdvance = Completer<void>();

  @override
  Future<void> avancarStatus(
    String numero, {
    int quantidadeArmazenada = 0,
    String? operatorName,
    String? operatorPin,
  }) async {
    if (!advanceStarted.isCompleted) advanceStarted.complete();
    await releaseAdvance.future;
    return super.avancarStatus(
      numero,
      quantidadeArmazenada: quantidadeArmazenada,
      operatorName: operatorName,
      operatorPin: operatorPin,
    );
  }
}
