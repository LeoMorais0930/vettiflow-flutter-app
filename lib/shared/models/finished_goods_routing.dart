import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';

enum FinishedGoodsRoutingConfidence { high, medium, uncertain }

class FinishedGoodsRouteSuggestion {
  const FinishedGoodsRouteSuggestion({
    required this.orderWarehouse,
    required this.componentConsumptionWarehouse,
    required this.finishedGoodsWarehouse,
    required this.confidence,
    required this.reason,
    this.warnings = const [],
  });

  final String orderWarehouse;
  final String componentConsumptionWarehouse;
  final String finishedGoodsWarehouse;
  final FinishedGoodsRoutingConfidence confidence;
  final String reason;
  final List<String> warnings;

  bool get canComplete =>
      finishedGoodsWarehouse.isNotEmpty &&
      confidence != FinishedGoodsRoutingConfidence.uncertain;

  List<String> compareOfficialFinishedGoodsWarehouse(
    String? officialWarehouse,
  ) {
    final raw = officialWarehouse?.trim();
    if (raw == null || raw.isEmpty) return const [];
    final official = WarehouseRouting.normalizeCode(raw);
    if (finishedGoodsWarehouse.isEmpty || official == finishedGoodsWarehouse) {
      return const [];
    }
    return [
      'Divergencia de entrada do acabado: sugerido $finishedGoodsWarehouse, oficial PR0 $official.',
    ];
  }
}

class FinishedGoodsRouting {
  const FinishedGoodsRouting._();

  static const _historicalFinishedGoodsProducts = {
    '203-025',
    '575-0764',
    '575-0767',
    '575-0779',
    '575-0862',
    '575-0863',
    '575-0863E',
    '575-0911',
  };

  static const _historicalFinishedGoodsFamilies = {'575'};
  static const _uncertainOrderWarehouses = {'02', '08', '11', '12'};

  static FinishedGoodsRouteSuggestion suggest({
    required String productCode,
    required String orderWarehouse,
    Iterable<String> componentWarehouses = const [],
  }) {
    final normalizedOrderWarehouse = _normalizeWarehouse(orderWarehouse);
    final consumptionWarehouse = _componentConsumptionWarehouse(
      normalizedOrderWarehouse,
      componentWarehouses,
    );
    final product = productCode.trim().toUpperCase();
    final family = product.split('-').first;

    if (orderWarehouse.trim().isEmpty ||
        WarehouseRouting.byCode(normalizedOrderWarehouse) == null ||
        _uncertainOrderWarehouses.contains(normalizedOrderWarehouse)) {
      return FinishedGoodsRouteSuggestion(
        orderWarehouse: normalizedOrderWarehouse,
        componentConsumptionWarehouse: consumptionWarehouse,
        finishedGoodsWarehouse: '',
        confidence: FinishedGoodsRoutingConfidence.uncertain,
        reason: 'Sem historico suficiente para sugerir entrada do acabado.',
        warnings: const [
          'Destino do acabado incerto; confirme historico Protheus antes de concluir.',
        ],
      );
    }

    if (normalizedOrderWarehouse == '05' &&
        _historicalFinishedGoodsProducts.contains(product)) {
      return FinishedGoodsRouteSuggestion(
        orderWarehouse: normalizedOrderWarehouse,
        componentConsumptionWarehouse: consumptionWarehouse,
        finishedGoodsWarehouse: '10',
        confidence: FinishedGoodsRoutingConfidence.high,
        reason: 'Regra historica 05 -> 10 para produto $product.',
        warnings: const [
          'Entrada do acabado sugerida pela regra historica 05 -> 10.',
        ],
      );
    }

    if (normalizedOrderWarehouse == '05' &&
        _historicalFinishedGoodsFamilies.contains(family)) {
      return FinishedGoodsRouteSuggestion(
        orderWarehouse: normalizedOrderWarehouse,
        componentConsumptionWarehouse: consumptionWarehouse,
        finishedGoodsWarehouse: '10',
        confidence: FinishedGoodsRoutingConfidence.medium,
        reason: 'Regra historica 05 -> 10 por familia $family.',
        warnings: const [
          'Entrada do acabado sugerida por familia; comparar com historico PR0.',
        ],
      );
    }

    return FinishedGoodsRouteSuggestion(
      orderWarehouse: normalizedOrderWarehouse,
      componentConsumptionWarehouse: consumptionWarehouse,
      finishedGoodsWarehouse: normalizedOrderWarehouse,
      confidence: FinishedGoodsRoutingConfidence.high,
      reason:
          'Destino direto no mesmo local da OP ${WarehouseRouting.labelForWarehouse(normalizedOrderWarehouse)}.',
    );
  }

  static String _componentConsumptionWarehouse(
    String orderWarehouse,
    Iterable<String> componentWarehouses,
  ) {
    final normalized = componentWarehouses
        .map(_normalizeWarehouse)
        .where((warehouse) => warehouse.trim().isNotEmpty)
        .toList();
    if (normalized.contains(orderWarehouse)) return orderWarehouse;
    if (normalized.length == 1) return normalized.single;
    return orderWarehouse;
  }

  static String _normalizeWarehouse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return WarehouseRouting.normalizeCode(trimmed);
  }
}
