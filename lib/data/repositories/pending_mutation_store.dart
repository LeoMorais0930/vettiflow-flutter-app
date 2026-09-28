import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/repositories/local_json_persistence.dart';

class PendingMutationStore extends ChangeNotifier {
  PendingMutationStore({LocalJsonPersistence? persistence})
    : _persistence = persistence ?? const LocalJsonPersistence(_storageKey) {
    _restore(_persistence.read());
    _persistence.listen((payload) {
      if (_restore(payload)) notifyListeners();
    });
  }

  static const _storageKey = 'vetti_flow.pending_mutations.v1';

  final LocalJsonPersistence _persistence;
  final _mutations = <PendingMutation>[];
  int _sequence = 0;

  List<PendingMutation> get all => List.unmodifiable(_mutations);

  List<PendingMutation> get pending => _mutations
      .where(
        (mutation) =>
            mutation.status != MutationStatus.enviado &&
            mutation.status != MutationStatus.armazenado,
      )
      .toList(growable: false);

  List<PendingMutation> get stored => _mutations
      .where((mutation) => mutation.status == MutationStatus.armazenado)
      .toList(growable: false);

  List<PendingMutation> get sent => _mutations
      .where((mutation) => mutation.status == MutationStatus.enviado)
      .toList(growable: false);

  int get pendingCount => pending.length;

  int get storedCount => stored.length;

  int get awaitingCount => pendingCount + storedCount;

  T enqueue<T extends PendingMutation>(
    T Function(String id, DateTime criadoEm) build,
  ) {
    _sequence++;
    final mutation = build(
      'vf-${DateTime.now().microsecondsSinceEpoch}-$_sequence',
      DateTime.now(),
    );
    _mutations.add(mutation);
    _persist();
    notifyListeners();
    return mutation;
  }

  bool discard(String id) {
    final index = _mutations.indexWhere((mutation) => mutation.id == id);
    if (index < 0) return false;
    if (_mutations[index].status == MutationStatus.enviado) return false;
    _mutations.removeAt(index);
    _persist();
    notifyListeners();
    return true;
  }

  int clearSent() {
    final before = _mutations.length;
    _mutations.removeWhere(
      (mutation) => mutation.status == MutationStatus.enviado,
    );
    if (_mutations.length == before) return 0;
    _persist();
    notifyListeners();
    return before - _mutations.length;
  }

  void updateStatus(
    String id, {
    required MutationStatus status,
    String? erro,
    String? protheusRef,
  }) {
    final index = _mutations.indexWhere((mutation) => mutation.id == id);
    if (index < 0) return;
    _mutations[index] = _mutations[index].copyWithStatus(
      status: status,
      erro: erro,
      protheusRef: protheusRef,
    );
    _persist();
    notifyListeners();
  }

  void _persist() {
    _persistence.write(
      jsonEncode([for (final mutation in _mutations) mutation.toJson()]),
    );
  }

  bool _restore(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    try {
      final list = jsonDecode(payload) as List<dynamic>;
      final restored = [
        for (final item in list)
          PendingMutation.fromJson((item as Map).cast<String, dynamic>()),
      ];
      _mutations
        ..clear()
        ..addAll(restored);
      return true;
    } catch (_) {
      return false;
    }
  }
}
