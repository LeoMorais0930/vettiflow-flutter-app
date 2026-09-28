import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:vetti_flow_1_0/data/repositories/local_json_persistence.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/ui/dashboard/views/operator_assignments_view.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/route_access.dart';

Operator person(String name) =>
    Operator.all.firstWhere((o) => o.username == name);
Operator login(OperatorAssignmentStore store, String name) {
  final actor = person(name);
  return store.authenticate(actor.username, actor.password)!;
}

class MemoryPermissions extends LocalJsonPersistence {
  MemoryPermissions() : super('test.permissions');
  String? payload;
  bool fail = false;
  final listeners = <void Function(String?)>[];
  @override
  String? read() => payload;
  @override
  void write(String value) {
    if (!fail) payload = value;
  }

  @override
  void listen(void Function(String?) callback) => listeners.add(callback);
  void notifyTabs() {
    for (final callback in listeners) {
      callback(payload);
    }
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('operadores entram no trabalho sem consultas, relatórios ou equipe', () {
    final store = OperatorAssignmentStore();
    addTearDown(store.dispose);
    for (final (name, home) in [
      ('juliana', '/firmware'),
      ('luis', '/almoxarifado/materiais'),
      ('leandro', '/smd/apontar'),
      ('douglas', '/suporte/operacao'),
      ('rafaela', '/expedicao/operacao'),
    ]) {
      final actor = login(store, name);
      expect(actor.homeRoute, home);
      expect(actor.canAccessRoute(home), true);
      expect(actor.visibleSectors, isEmpty);
      expect(actor.canAccessRoute('/colaboradores'), false);
      expect(store.visibleAssignableOperators, isEmpty);
      for (final sector in AppSector.values) {
        expect(actor.canAccessRoute(sector.route), false);
        expect(actor.canAccessRoute('${sector.route}/relatorios'), false);
      }
      expect(
        () => store.setPermission(name, OperatorPermission.manager),
        throwsStateError,
      );
    }
  });

  for (final (owner, target, sector) in [
    ('tatiane', 'juliana', AppSector.production),
    ('vera', 'luis', AppSector.warehouse),
    ('paula', 'leandro', AppSector.smd),
    ('bruno', 'douglas', AppSector.support),
  ]) {
    test(
      '$owner permite consulta, nomeia gestor e revoga apenas no próprio setor',
      () {
        final memory = MemoryPermissions();
        final store = OperatorAssignmentStore(persistence: memory);
        addTearDown(store.dispose);
        final manager = login(store, owner);
      expect(manager.canAccessRoute('/colaboradores'), true);
      if (owner == 'paula') {
        expect(manager.canAccessRoute('/dashboard'), false);
      }
        store.setPermission(target, OperatorPermission.consultation);
        final restored = OperatorAssignmentStore(persistence: memory);
        addTearDown(restored.dispose);
        var actor = login(restored, target);
        expect(actor.canView(sector), true);
        expect(actor.canAccessRoute('${sector.route}/relatorios'), true);
        expect(actor.canManageAssignments, false);
        expect(actor.canAccessRoute('/admin/armazens'), false);
        expect(actor.canAccessRoute('/gestao/relatorios'), false);
        expect(actor.canAccessRoute(actor.homeRoute), true);
        final foreign = owner == 'vera' ? 'juliana' : 'luis';
        expect(
          () => store.setPermission(foreign, OperatorPermission.manager),
          throwsStateError,
        );
        expect(
          () => store.setPermission(owner, OperatorPermission.operation),
          throwsStateError,
        );
        store.setPermission(target, OperatorPermission.manager);
        memory.notifyTabs();
        actor = restored.currentOperator!;
        expect(actor.canManageAssignments, true);
        expect(actor.managesArea, manager.area);
        expect(
          restored.visibleAssignableOperators.every(
            (o) => o.area == manager.area,
          ),
          true,
        );
        expect(
          () => restored.setPermission(owner, OperatorPermission.operation),
          throwsStateError,
        );
        expect(
          () =>
              restored.setPermission(foreign, OperatorPermission.consultation),
          throwsStateError,
        );
        store.setPermission(target, OperatorPermission.operation);
        memory.notifyTabs();
        actor = restored.currentOperator!;
        expect(actor.canView(sector), false);
        expect(actor.canManageAssignments, false);
        expect(actor.canAccessRoute(actor.homeRoute), true);
        expect(restored.findByPin(person(target).pin)!.canView(sector), false);
      },
    );
  }

  test(
    'revogação também cobre contas antigas de gestor e escrita falha não libera acesso',
    () {
      final memory = MemoryPermissions();
      final store = OperatorAssignmentStore(persistence: memory);
      addTearDown(store.dispose);
      login(store, 'tatiane');
      store.setPermission('andressa', OperatorPermission.operation);
      for (final account in Operator.all.where(
        (o) => o.username == 'andressa',
      )) {
        final actor = store.authenticate(account.username, account.password)!;
        expect(actor.canView(AppSector.production), false);
        expect(actor.canAccessRoute(actor.homeRoute), true);
        expect(actor.homeRoute, '/firmware');
      }
      login(store, 'tatiane');
      memory.fail = true;
      expect(
        () => store.setPermission('juliana', OperatorPermission.manager),
        throwsStateError,
      );
      expect(store.resolve(person('juliana')).canManageAssignments, false);
      expect(jsonDecode(memory.payload!)['permissions']['juliana'], isNull);
    },
  );

  testWidgets(
    'rota de consulta recusa operador antes de construir seu conteúdo',
    (tester) async {
      final store = OperatorAssignmentStore();
      addTearDown(store.dispose);
      login(store, 'luis');
      var builds = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(
            home: RouteAccess(
              route: '/almoxarifado',
              builder: (_) {
                builds++;
                return const Text('Dados da consulta');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(builds, 0);
      expect(
        find.text('Este setor não faz parte do seu acesso.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Vera libera consulta pela tela de colaboradores em tela estreita',
    (tester) async {
      final store = OperatorAssignmentStore();
      final requests = WarehouseRequestStore();
      addTearDown(store.dispose);
      addTearDown(requests.dispose);
      login(store, 'vera');
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider.value(value: requests),
          ],
          child: const MaterialApp(home: CollaboratorsPage()),
        ),
      );
      await tester.pumpAndSettle();
      final selector = find.byKey(const Key('mobile-operator-selector'));
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Luis').last);
      await tester.pumpAndSettle();
      final permission = find.byType(DropdownButton<OperatorPermission>);
      await tester.ensureVisible(permission);
      await tester.tap(permission);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Operação e consultas').last);
      await tester.pumpAndSettle();
      expect(store.resolve(person('luis')).canView(AppSector.warehouse), true);
      expect(find.text('Acesso de Luis atualizado.'), findsOneWidget);
      expect(find.textContaining('Senha/PIN'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
