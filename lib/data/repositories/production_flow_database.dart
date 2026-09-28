import 'package:vetti_flow_1_0/data/models/production_flow.dart';

class ProductionFlowSnapshot {
  const ProductionFlowSnapshot({
    required this.orders,
    required this.catalogItems,
  });

  final List<ProductionOrderFlow> orders;
  final List<ProductionCatalogItem> catalogItems;
}

abstract class ProductionFlowDatabase {
  Future<ProductionFlowSnapshot> loadSnapshot();

  Future<int?> nextOrderSequence();

  Future<void> saveOrder(
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem, {
    required String eventType,
  });

  Future<void> deleteOrder(
    String number, {
    ProductionOrderFlow? order,
    ProductionCatalogItem? catalogItem,
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  });
}

class EmptyProductionFlowDatabase implements ProductionFlowDatabase {
  const EmptyProductionFlowDatabase();

  @override
  Future<void> deleteOrder(
    String number, {
    ProductionOrderFlow? order,
    ProductionCatalogItem? catalogItem,
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) async {}

  @override
  Future<ProductionFlowSnapshot> loadSnapshot() async {
    return const ProductionFlowSnapshot(orders: [], catalogItems: []);
  }

  @override
  Future<int?> nextOrderSequence() async => null;

  @override
  Future<void> saveOrder(
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem, {
    required String eventType,
  }) async {}
}
