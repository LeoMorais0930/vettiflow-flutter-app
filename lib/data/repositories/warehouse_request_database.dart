import 'package:vetti_flow_1_0/data/models/warehouse_request.dart';
import 'dart:convert';
import 'package:vetti_flow_1_0/data/repositories/local_json_persistence.dart';

abstract class WarehouseRequestDatabase {
  Future<List<WarehouseConfirmationRequest>> loadRequests();
  Future<void> saveRequest(WarehouseConfirmationRequest request);
}

class EmptyWarehouseRequestDatabase implements WarehouseRequestDatabase {
  const EmptyWarehouseRequestDatabase();

  @override
  Future<List<WarehouseConfirmationRequest>> loadRequests() async => const [];

  @override
  Future<void> saveRequest(WarehouseConfirmationRequest request) async {}
}

/// Registros do VettiFlow neste dispositivo. Não acessa o Protheus.
class LocalWarehouseRequestDatabase implements WarehouseRequestDatabase {
  const LocalWarehouseRequestDatabase({
    this.persistence = const LocalJsonPersistence(
      'vetti_flow.warehouse_materials.v1',
    ),
  });
  final LocalJsonPersistence persistence;

  List<WarehouseConfirmationRequest> _read() {
    final raw = persistence.read();
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map(
          (item) => WarehouseConfirmationRequest.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  @override
  Future<List<WarehouseConfirmationRequest>> loadRequests() async => _read();

  @override
  Future<void> saveRequest(WarehouseConfirmationRequest request) async {
    final items = {for (final item in _read()) item.id: item};
    final previous = items[request.id];
    if (previous != null && previous.updatedAt.isAfter(request.updatedAt)) {
      return;
    }
    items[request.id] = request;
    final payload = jsonEncode(items.values.map((e) => e.toJson()).toList());
    persistence.write(payload);
    if (persistence.read() != payload) {
      throw StateError('Não foi possível gravar os pedidos neste dispositivo.');
    }
  }
}
