import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vetti_flow_1_0/data/models/protheus_product_lookup.dart';
import 'package:vetti_flow_1_0/data/repositories/api_settings.dart';

abstract class ProtheusProductRepository {
  Future<ProtheusProductLookup?> lookupByCode(String code);
  Future<List<ProtheusProduct>> searchProducts(String query, {int limit = 12});
  Future<List<String>> fetchProductLabels({int limit = 250});
}

class EmptyProtheusProductRepository implements ProtheusProductRepository {
  const EmptyProtheusProductRepository();

  @override
  Future<List<String>> fetchProductLabels({int limit = 250}) async {
    return const [];
  }

  @override
  Future<ProtheusProductLookup?> lookupByCode(String code) async {
    return null;
  }

  @override
  Future<List<ProtheusProduct>> searchProducts(
    String query, {
    int limit = 12,
  }) async {
    return const [];
  }
}

class ApiProtheusProductRepository implements ProtheusProductRepository {
  ApiProtheusProductRepository({
    required String baseUrl,
    this.apiToken = '',
    http.Client? httpClient,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _http = httpClient ?? ApiSettings.createClient();

  final String baseUrl;
  final String apiToken;
  final http.Client _http;

  static const _timeout = Duration(seconds: 12);

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Map<String, String> _headers() {
    final token = apiToken.trim().isNotEmpty
        ? apiToken.trim()
        : ApiSettings.token;
    return {if (token.isNotEmpty) 'X-API-Token': token};
  }

  @override
  Future<List<String>> fetchProductLabels({int limit = 250}) async {
    final products = await searchProducts('', limit: limit);
    return products.map((product) => product.label).toList();
  }

  @override
  Future<ProtheusProductLookup?> lookupByCode(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) return null;

    final response = await _http
        .get(_uri('/api/v1/produtos/$normalizedCode'), headers: _headers())
        .timeout(_timeout);
    if (response.statusCode == 404) return null;
    _ensureOk(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _lookupFromApi(json);
  }

  @override
  Future<List<ProtheusProduct>> searchProducts(
    String query, {
    int limit = 12,
  }) async {
    final response = await _http
        .get(
          _uri('/api/v1/produtos', {
            'query': query.trim(),
            'limit': limit.toString(),
          }),
          headers: _headers(),
        )
        .timeout(_timeout);
    _ensureOk(response);
    final json = jsonDecode(response.body);
    final items = json is List ? json : const [];
    return items
        .whereType<Map>()
        .map((item) => _productFromApi(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw StateError(
      'API Protheus HTTP ${response.statusCode}: ${response.body}',
    );
  }

  ProtheusProductLookup _lookupFromApi(Map<String, dynamic> data) {
    return ProtheusProductLookup(
      filial: _text(data['filial'], fallback: '04'),
      armazem: _text(data['armazem']),
      product: _productFromApi(_map(data['product'])),
      components: _list(
        data['components'],
      ).map(_componentFromApi).toList(growable: false),
      smdReleaseOrders: _list(
        data['smdReleaseOrders'],
      ).map(_childOrderFromApi).toList(growable: false),
    );
  }

  ProtheusProduct _productFromApi(Map<String, dynamic> data) {
    return ProtheusProduct(
      filial: _text(data['filial']),
      code: _text(data['code'] ?? data['codigo']),
      description: _text(data['description'] ?? data['descricao']),
      type: _text(data['type'] ?? data['tipo']),
      unit: _text(data['unit'] ?? data['unidade']),
      group: _text(data['group'] ?? data['grupo']),
      screenBlock: _text(data['screenBlock'] ?? data['b1_msblql']),
    );
  }

  ProtheusProductComponent _componentFromApi(Map<String, dynamic> data) {
    return ProtheusProductComponent(
      filial: _text(data['filial']),
      armazem: _text(data['armazem']),
      code: _text(data['code'] ?? data['codigo']),
      description: _text(data['description'] ?? data['descricao']),
      quantityPerUnit: _num(
        data['quantityPerUnit'] ?? data['quantidadePorUnidade'],
      ),
      unit: _text(data['unit'] ?? data['unidade']),
      stockAvailable: _num(data['stockAvailable'] ?? data['saldoDisponivel']),
      currentStock: _num(data['currentStock'] ?? data['saldoAtual']),
      committedQuantity: _num(
        data['committedQuantity'] ?? data['quantidadeEmpenhada'],
      ),
      reservedQuantity: _num(
        data['reservedQuantity'] ?? data['quantidadeReservada'],
      ),
      requirementSource: _text(
        data['requirementSource'] ?? data['origemNecessidade'],
        fallback: 'SG1',
      ),
      sourceOrder: _text(data['sourceOrder'] ?? data['opOrigem']),
      commitmentDate: _text(data['commitmentDate'] ?? data['dataEmpenho']),
      originalQuantity: _num(
        data['originalQuantity'] ?? data['quantidadeOriginal'],
      ),
      commitmentQuantity: _num(
        data['commitmentQuantity'] ?? data['quantidadeEmpenho'],
      ),
      structureSequence: _text(
        data['structureSequence'] ??
            data['sequenciaEstrutura'] ??
            data['structure_sequence'] ??
            data['g1_trt'],
      ),
      warehouseBalances: _list(
        data['warehouseBalances'],
      ).map(_warehouseBalanceFromApi).toList(growable: false),
      childOrders: _list(
        data['childOrders'],
      ).map(_childOrderFromApi).toList(growable: false),
    );
  }

  ProtheusWarehouseBalance _warehouseBalanceFromApi(Map<String, dynamic> data) {
    return ProtheusWarehouseBalance(
      filial: _text(data['filial']),
      armazem: _text(data['armazem']),
      currentStock: _num(data['currentStock'] ?? data['saldoAtual']),
      committedQuantity: _num(
        data['committedQuantity'] ?? data['quantidadeEmpenhada'],
      ),
      reservedQuantity: _num(
        data['reservedQuantity'] ?? data['quantidadeReservada'],
      ),
      availableQuantity: _num(
        data['availableQuantity'] ?? data['saldoDisponivel'],
      ),
    );
  }

  ProtheusChildOrder _childOrderFromApi(Map<String, dynamic> data) {
    return ProtheusChildOrder(
      number: _text(data['number'] ?? data['numero']),
      productCode: _text(data['productCode'] ?? data['produtoCodigo']),
      productDescription: _text(
        data['productDescription'] ?? data['produtoDescricao'],
      ),
      plannedQuantity: _num(
        data['plannedQuantity'] ?? data['quantidadePlanejada'],
      ),
      producedQuantity: _num(
        data['producedQuantity'] ?? data['quantidadeProduzida'],
      ),
      status: _text(data['status']),
    );
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return const {};
  }

  List<Map<String, dynamic>> _list(Object? value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList(growable: false);
    }
    return const [];
  }

  String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  num _num(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}
