import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'local_json_persistence.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/models/operator_access.dart';

class OperatorAssignmentStore extends ChangeNotifier {
  OperatorAssignmentStore({this.persistence})
    : _assignments = {
        for (final operator in _assignableOperators)
          operator.username: operator.stage,
      } {
    _restore(persistence?.read());
    persistence?.listen((raw) {
      if (_disposed) return;
      _restore(raw);
      notifyListeners();
    });
  }

  final LocalJsonPersistence? persistence;
  final _permissions = <String, OperatorPermission>{};
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _restore(String? raw) {
    final permissions = <String, OperatorPermission>{};
    final stages = {
      for (final actor in _assignableOperators) actor.username: actor.stage,
    };
    try {
      if (raw != null) {
        final json = jsonDecode(raw) as Map;
        if (json['version'] == 1) {
          for (final actor in assignableOperators) {
            final level = (json['permissions'] as Map?)?[actor.username];
            for (final candidate in OperatorPermission.values) {
              if (candidate.name == level && !actor.isSectorOwner) {
                permissions[actor.username] = candidate;
              }
            }
            final stage = (json['stages'] as Map?)?[actor.username];
            for (final candidate in stagesFor(actor)) {
              if (candidate.name == stage) stages[actor.username] = candidate;
            }
          }
        }
      }
    } on FormatException {
      // Um arquivo inválido não concede novos acessos.
    } on TypeError {
      permissions.clear();
    }
    _permissions
      ..clear()
      ..addAll(permissions);
    _assignments
      ..clear()
      ..addAll(stages);
  }

  void _save(
    Map<String, OperatorPermission> permissions,
    Map<String, WorkStage> stages,
  ) {
    final storage = persistence;
    if (storage == null) return;
    final payload = jsonEncode({
      'version': 1,
      'permissions': permissions.map((key, value) => MapEntry(key, value.name)),
      'stages': stages.map((key, value) => MapEntry(key, value.name)),
    });
    storage.write(payload);
    if (storage.read() != payload) {
      throw StateError('Não foi possível salvar os acessos neste dispositivo.');
    }
  }

  OperatorPermission permissionFor(Operator actor) {
    if (actor.isSectorOwner) return OperatorPermission.manager;
    return _permissions[actor.username] ??
        (Operator.all.any(
              (base) =>
                  base.username == actor.username && base.canManageAssignments,
            )
            ? OperatorPermission.manager
            : OperatorPermission.operation);
  }

  bool canSetPermission(Operator target) {
    final manager = currentOperator;
    return manager != null &&
        (manager.isAdministrator ||
            manager.isSectorOwner && manager.area == target.area) &&
        !target.isSectorOwner &&
        target.area != WorkArea.system &&
        target.username != manager.username;
  }

  void setPermission(String username, OperatorPermission permission) {
    final target = assignableOperators
        .where((o) => o.username == username)
        .firstOrNull;
    if (target == null || !canSetPermission(target)) {
      throw StateError('Você não pode alterar o acesso deste colaborador.');
    }
    if (persistence != null) _restore(persistence!.read());
    final updated = {..._permissions, username: permission};
    _save(updated, _assignments);
    _permissions
      ..clear()
      ..addAll(updated);
    notifyListeners();
  }

  static const assignableStages = [
    WorkStage.smd,
    WorkStage.firmware,
    WorkStage.soldering,
    WorkStage.testing,
    WorkStage.closing,
    WorkStage.expedition,
    WorkStage.warehouse,
    WorkStage.support,
  ];

  static const productionStages = [
    WorkStage.firmware,
    WorkStage.soldering,
    WorkStage.testing,
    WorkStage.closing,
    WorkStage.expedition,
  ];

  static const smdStages = [WorkStage.smd];

  static const warehouseStages = [WorkStage.warehouse];

  static const supportStages = [WorkStage.support];

  static List<Operator> get assignableOperators {
    final seen = <String>{};
    return [
      for (final operator in _assignableOperators)
        if (seen.add(operator.username)) operator,
    ];
  }

  static List<Operator> get dashboardOperators => Operator.all
      .where((operator) => operator.canManageAssignments)
      .where((operator) => operator.stage == WorkStage.dashboard)
      .toList();

  static Iterable<Operator> get _assignableOperators =>
      Operator.all.where((operator) => operator.usesAssignedStage);

  final Map<String, WorkStage> _assignments;
  Operator? _currentOperator;

  Operator? get currentOperator =>
      _currentOperator == null ? null : resolve(_currentOperator!);
  void logout() {
    _currentOperator = null;
    notifyListeners();
  }

  WorkArea? get currentManagedArea => currentOperator?.managesArea;

  String get currentAreaLabel =>
      currentManagedArea?.label ?? 'Todos os setores';

  List<Operator> get visibleAssignableOperators {
    if (currentOperator?.canManageAssignments != true) return [];
    final area = currentManagedArea;
    if (area == null) return assignableOperators.map(resolve).toList();
    return assignableOperators
        .where((operator) => operator.area == area)
        .map(resolve)
        .toList();
  }

  List<Operator> get visibleDashboardOperators {
    if (currentOperator?.canManageAssignments != true) return [];
    final area = currentManagedArea;
    return visibleAssignableOperators
        .where(
          (operator) =>
              operator.canManageAssignments &&
              (area == null || operator.managesArea == area),
        )
        .toList();
  }

  WorkStage stageFor(Operator operator) {
    if (!operator.usesAssignedStage &&
        !(operator.stage == WorkStage.dashboard &&
            permissionFor(operator) != OperatorPermission.manager)) {
      return operator.stage;
    }
    return _assignments[operator.username] ?? operator.stage;
  }

  Operator resolve(Operator operator) => operator.copyWithStage(
    stageFor(operator),
    permission: permissionFor(operator),
  );

  Operator? authenticate(String username, String password) {
    final operator = Operator.authenticate(username, password);
    if (operator == null) return null;
    final resolved = resolve(operator);
    _currentOperator = operator;
    notifyListeners();
    return resolved;
  }

  Operator? findByPin(String pin) {
    final operator = Operator.findByPin(pin);
    if (operator == null) return null;
    return resolve(operator);
  }

  void assignStage(String username, WorkStage stage) {
    if (persistence != null) _restore(persistence!.read());
    final operator = assignableOperators.cast<Operator?>().firstWhere(
      (operator) => operator?.username == username,
      orElse: () => null,
    );
    if (operator == null) return;
    if (!_canCurrentManagerAssign(operator, stage)) return;
    final updated = {..._assignments, username: stage};
    _save(_permissions, updated);
    _assignments
      ..clear()
      ..addAll(updated);
    notifyListeners();
  }

  List<WorkStage> stagesFor(Operator operator) {
    return switch (operator.area) {
      WorkArea.production => productionStages,
      WorkArea.smd => smdStages,
      WorkArea.warehouse => warehouseStages,
      WorkArea.support => supportStages,
      WorkArea.system => const [],
    };
  }

  int countAt(WorkStage stage) {
    return visibleAssignableOperators
        .where((operator) => stageFor(operator) == stage)
        .length;
  }

  bool _canCurrentManagerAssign(Operator operator, WorkStage stage) {
    if (currentOperator?.canManageAssignments != true) return false;
    final managedArea = currentManagedArea;
    if (managedArea != null && operator.area != managedArea) return false;
    return stagesFor(operator).contains(stage);
  }
}
