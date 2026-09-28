import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';

class ProtheusProduct {
  final String filial;
  final String code;
  final String description;
  final String type;
  final String unit;
  final String group;
  final String screenBlock;

  const ProtheusProduct({
    this.filial = '',
    required this.code,
    required this.description,
    required this.type,
    required this.unit,
    required this.group,
    this.screenBlock = '',
  });

  String get label => '$code - $description';

  bool get isBlockedForOperations => screenBlock.trim() == '1';
}

class ProtheusWarehouseBalance {
  final String filial;
  final String armazem;
  final num currentStock;
  final num committedQuantity;
  final num reservedQuantity;
  final num availableQuantity;

  const ProtheusWarehouseBalance({
    required this.filial,
    required this.armazem,
    required this.currentStock,
    required this.committedQuantity,
    required this.reservedQuantity,
    required this.availableQuantity,
  });
}

class ProtheusChildOrder {
  final String number;
  final String productCode;
  final String productDescription;
  final num plannedQuantity;
  final num producedQuantity;
  final String status;

  const ProtheusChildOrder({
    required this.number,
    required this.productCode,
    required this.productDescription,
    required this.plannedQuantity,
    required this.producedQuantity,
    required this.status,
  });
}

class ProtheusProductComponent {
  final String filial;
  final String armazem;
  final String code;
  final String description;
  final num quantityPerUnit;
  final String unit;
  final num stockAvailable;
  final num currentStock;
  final num committedQuantity;
  final num reservedQuantity;
  final String requirementSource;
  final String sourceOrder;
  final String commitmentDate;
  final num originalQuantity;
  final num commitmentQuantity;
  final String structureSequence;
  final List<ProtheusWarehouseBalance> warehouseBalances;
  final List<ProtheusChildOrder> childOrders;

  const ProtheusProductComponent({
    this.filial = '',
    this.armazem = '',
    required this.code,
    required this.description,
    required this.quantityPerUnit,
    required this.unit,
    this.stockAvailable = 0,
    this.currentStock = 0,
    this.committedQuantity = 0,
    this.reservedQuantity = 0,
    this.requirementSource = 'SG1',
    this.sourceOrder = '',
    this.commitmentDate = '',
    this.originalQuantity = 0,
    this.commitmentQuantity = 0,
    this.structureSequence = '',
    this.warehouseBalances = const [],
    this.childOrders = const [],
  });

  bool get hasChildOrders => childOrders.isNotEmpty;

  static ProtheusWarehouseBalance? selectBestWarehouseBalance(
    List<ProtheusWarehouseBalance> balances,
    String preferredWarehouse,
  ) {
    if (balances.isEmpty) return null;
    final eligibleBalances = balances
        .where(
          (balance) =>
              WarehouseRouting.canSourceMaterialFromWarehouse(balance.armazem),
        )
        .toList();
    if (eligibleBalances.isEmpty) return null;
    final preferred = eligibleBalances
        .cast<ProtheusWarehouseBalance?>()
        .firstWhere(
          (balance) => balance?.armazem == preferredWarehouse,
          orElse: () => null,
        );
    final positiveBalances =
        eligibleBalances
            .where(
              (balance) =>
                  balance.availableQuantity > 0 || balance.currentStock > 0,
            )
            .toList()
          ..sort((a, b) {
            final available = b.availableQuantity.compareTo(
              a.availableQuantity,
            );
            if (available != 0) return available;
            return b.currentStock.compareTo(a.currentStock);
          });
    if (preferred != null &&
        (preferred.availableQuantity > 0 || positiveBalances.isEmpty)) {
      return preferred;
    }
    if (positiveBalances.isNotEmpty) return positiveBalances.first;
    return preferred ?? balances.first;
  }

  List<String> get availableWarehouses {
    final values = [
      for (final balance in warehouseBalances)
        if (balance.armazem.isNotEmpty) balance.armazem,
      if (armazem.isNotEmpty) armazem,
    ];
    return values.toSet().toList()..sort();
  }

  ProtheusProductComponent selectWarehouse(String warehouse) {
    ProtheusWarehouseBalance? selected;
    for (final balance in warehouseBalances) {
      if (balance.armazem == warehouse) {
        selected = balance;
        break;
      }
    }
    if (selected == null) {
      final hasKnownBalances = warehouseBalances.isNotEmpty;
      return ProtheusProductComponent(
        filial: filial,
        armazem: warehouse,
        code: code,
        description: description,
        quantityPerUnit: quantityPerUnit,
        unit: unit,
        stockAvailable: hasKnownBalances ? 0 : stockAvailable,
        currentStock: hasKnownBalances ? 0 : currentStock,
        committedQuantity: hasKnownBalances ? 0 : committedQuantity,
        reservedQuantity: hasKnownBalances ? 0 : reservedQuantity,
        requirementSource: requirementSource,
        sourceOrder: sourceOrder,
        commitmentDate: commitmentDate,
        originalQuantity: originalQuantity,
        commitmentQuantity: commitmentQuantity,
        structureSequence: structureSequence,
        warehouseBalances: warehouseBalances,
        childOrders: childOrders,
      );
    }
    return ProtheusProductComponent(
      filial: selected.filial,
      armazem: selected.armazem,
      code: code,
      description: description,
      quantityPerUnit: quantityPerUnit,
      unit: unit,
      stockAvailable: selected.availableQuantity,
      currentStock: selected.currentStock,
      committedQuantity: selected.committedQuantity,
      reservedQuantity: selected.reservedQuantity,
      requirementSource: requirementSource,
      sourceOrder: sourceOrder,
      commitmentDate: commitmentDate,
      originalQuantity: originalQuantity,
      commitmentQuantity: commitmentQuantity,
      structureSequence: structureSequence,
      warehouseBalances: warehouseBalances,
      childOrders: childOrders,
    );
  }

  bool get shouldValidateStock => !code.toUpperCase().startsWith('MOD');

  num requiredQuantityFor(int orderQuantity) => quantityPerUnit * orderQuantity;

  num missingQuantityFor(int orderQuantity) {
    if (!shouldValidateStock) return 0;
    final missing = requiredQuantityFor(orderQuantity) - stockAvailable;
    return missing > 0 ? missing : 0;
  }

  List<ProtheusWarehouseBalance> warehousesThatCanCover(int orderQuantity) {
    if (!shouldValidateStock) return const [];
    final required = requiredQuantityFor(orderQuantity);
    final options = [
      for (final balance in warehouseBalances)
        if (balance.armazem != armazem &&
            WarehouseRouting.canSourceMaterialFromWarehouse(balance.armazem) &&
            balance.availableQuantity >= required)
          balance,
    ];
    options.sort((a, b) => b.availableQuantity.compareTo(a.availableQuantity));
    return options;
  }

  bool hasEnoughStockFor(int orderQuantity) {
    if (!shouldValidateStock) return true;
    return stockAvailable >= requiredQuantityFor(orderQuantity);
  }

  ProductionComponent toProductionComponent() {
    return ProductionComponent(
      code: code,
      unit: unit,
      description: description,
      quantity: quantityPerUnit,
      stock: stockAvailable,
      filial: filial,
      armazem: armazem,
      currentStock: currentStock,
      committedQuantity: committedQuantity,
      reservedQuantity: reservedQuantity,
      requirementSource: requirementSource,
      sourceOrder: sourceOrder,
      commitmentDate: commitmentDate,
      originalQuantity: originalQuantity,
      commitmentQuantity: commitmentQuantity,
      structureSequence: structureSequence,
    );
  }
}

class ProtheusStockShortage {
  const ProtheusStockShortage({
    required this.component,
    required this.requiredQuantity,
    required this.availableQuantity,
  });

  final ProtheusProductComponent component;
  final num requiredQuantity;
  final num availableQuantity;

  String get label =>
      '${component.code}: precisa $requiredQuantity, disponivel $availableQuantity';
}

class ProtheusProductLookup {
  final String filial;
  final String armazem;
  final ProtheusProduct product;
  final List<ProtheusProductComponent> components;
  final List<ProtheusChildOrder> smdReleaseOrders;

  const ProtheusProductLookup({
    this.filial = '04',
    this.armazem = '',
    required this.product,
    this.components = const [],
    this.smdReleaseOrders = const [],
  });

  String get label => product.label;

  bool get hasRamifications =>
      components.isNotEmpty ||
      components.any((component) => component.childOrders.isNotEmpty) ||
      smdReleaseOrders.isNotEmpty;

  bool get isReleasedBySmd => smdReleaseOrders.isNotEmpty;

  List<String> get availableWarehouses {
    final values = [
      for (final component in components) ...component.availableWarehouses,
      if (armazem.isNotEmpty) armazem,
    ];
    return values.toSet().toList()..sort();
  }

  String get defaultWarehouse {
    if (armazem.isNotEmpty) return armazem;
    final warehouses = availableWarehouses;
    return warehouses.isEmpty ? '' : warehouses.first;
  }

  ProtheusProductLookup selectWarehouse(String warehouse) {
    return ProtheusProductLookup(
      filial: filial,
      armazem: warehouse,
      product: product,
      components: components
          .map((component) => component.selectWarehouse(warehouse))
          .toList(),
      smdReleaseOrders: smdReleaseOrders,
    );
  }

  ProtheusProductLookup selectComponentWarehouse(
    String componentCode,
    String warehouse,
  ) {
    return ProtheusProductLookup(
      filial: filial,
      armazem: armazem,
      product: product,
      components: [
        for (final component in components)
          component.code == componentCode
              ? component.selectWarehouse(warehouse)
              : component,
      ],
      smdReleaseOrders: smdReleaseOrders,
    );
  }

  List<ProtheusStockShortage> stockShortagesFor(int orderQuantity) {
    return [
      for (final component in components)
        if (!component.hasEnoughStockFor(orderQuantity))
          ProtheusStockShortage(
            component: component,
            requiredQuantity: component.requiredQuantityFor(orderQuantity),
            availableQuantity: component.stockAvailable,
          ),
    ];
  }

  List<ProductionComponent> toProductionComponents() {
    return components
        .map((component) => component.toProductionComponent())
        .toList();
  }
}
