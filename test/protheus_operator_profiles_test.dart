import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/models/operator_access.dart';

void main() {
  test('Artur e Vitor têm acesso administrativo a todos os setores', () {
    final store = OperatorAssignmentStore();
    addTearDown(store.dispose);
    for (final login in ['artur', 'vitor.vasconcelos']) {
      store.acceptProtheusIdentity(login);
      final actor = store.currentOperator!;
      expect(actor.isAdministrator, true);
      expect(actor.visibleSectors.toSet(), AppSector.values.toSet());
      expect(actor.canAccessRoute('/colaboradores'), true);
      expect(actor.canAccessRoute('/producao/sql-dev'), true);
      expect(actor.password, isEmpty);
      expect(actor.pin, isEmpty);
    }
  });
  test('login real preserva identidade, setor e gestão confirmados', () {
    final store = OperatorAssignmentStore();
    addTearDown(store.dispose);
    for (final (login, area, manager) in [
      ('paulad', WorkArea.smd, true),
      ('andressa.camargo', WorkArea.production, true),
      ('TATIANE', WorkArea.production, true),
      ('vera', WorkArea.warehouse, true),
      ('bruno', WorkArea.support, true),
      ('vinicius', WorkArea.support, true),
      ('leandro', WorkArea.smd, false),
      ('Luis', WorkArea.warehouse, false),
      ('douglas', WorkArea.support, false),
      ('matheus', WorkArea.support, false),
      ('gabriel.fontes', WorkArea.support, false),
      ('expedicao', WorkArea.production, false),
      ('silvania.teixeira', WorkArea.warehouse, false),
      ('rosangela.prestes', WorkArea.warehouse, false),
      ('natalina.rosimeire', WorkArea.support, false),
    ]) {
      store.acceptProtheusIdentity(login);
      final actor = store.currentOperator!;
      expect(actor.username, login.toLowerCase());
      expect(actor.area, area);
      expect(actor.canManageAssignments, manager);
      expect(actor.password, isEmpty);
      expect(actor.pin, isEmpty);
    }
    store.acceptProtheusIdentity('silvania.teixeira');
    expect(store.currentOperator!.canOperate(AppSector.production), false);
    expect(store.currentOperator!.homeRoute, '/almoxarifado/materiais');
    store.acceptProtheusIdentity('expedicao');
    expect(store.currentOperator!.name, 'Bruna e Tamara');
    expect(store.currentOperator!.homeRoute, '/expedicao/operacao');
    expect(store.currentOperator!.canOperate(AppSector.expedition), true);
    expect(store.currentOperator!.canOperate(AppSector.production), false);
    expect(store.currentOperator!.canOperate(AppSector.support), false);
  });
  test('cadastro antigo não concede perfil a bloqueados ou comercial', () {
    final store = OperatorAssignmentStore();
    addTearDown(store.dispose);
    for (final login in [
      'juliana',
      'rafaela',
      'david',
      'bruna',
      'paula',
      'guilherme',
      'guilhermem',
      'giovanna.camargo',
      'giovana',
      'brayan.vieira',
      'bryan',
      'admin',
      'desconhecido',
    ]) {
      store.acceptProtheusIdentity(login);
      expect(store.currentOperator, isNull, reason: login);
    }
  });
  test('admin remoto vê apenas vínculos reais confirmados', () {
    final store = OperatorAssignmentStore();
    addTearDown(store.dispose);
    store.acceptProtheusIdentity('leonardo.morais');
    expect(store.currentOperator!.isAdministrator, true);
    final names = store.visibleAssignableOperators.map((o) => o.username);
    expect(
      names,
      containsAll(['paulad', 'andressa.camargo', 'silvania.teixeira']),
    );
    expect(names, isNot(contains('bryan')));
    expect(names, isNot(contains('juliana')));
    expect(names.toSet().length, names.length);
    store.setPermission('andressa.camargo', OperatorPermission.consultation);
    store.acceptProtheusIdentity('andressa.camargo');
    expect(store.currentOperator!.canManageAssignments, false);
  });
}
