import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vetti_flow_1_0/data/repositories/api_settings.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';

class ProtheusWarehouse {
  const ProtheusWarehouse({
    this.filial = '',
    required this.code,
    required this.description,
    this.type = '',
    this.integratesProduction = '',
    this.mrp = '',
    this.alternateWarehouse = '',
  });

  final String filial;
  final String code;
  final String description;
  final String type;
  final String integratesProduction;
  final String mrp;
  final String alternateWarehouse;

  String get normalizedCode => WarehouseRouting.normalizeCode(code);

  String get label => 'Armazém $normalizedCode - ${description.trim()}';

  bool get isThirdParty {
    final text = description.toUpperCase();
    return normalizedCode.startsWith('7') || text.contains('TERC');
  }

  bool get isSpecial {
    final text = description.toUpperCase();
    return {'02', '08', '11', '12'}.contains(normalizedCode) ||
        text.contains('OBSOLETO') ||
        text.contains('ENTREGA FUTURA') ||
        text.contains('USA') ||
        text.contains('ADRIAN');
  }

  WorkArea get inferredArea {
    final text = description.toUpperCase();
    if (isSpecial) return WorkArea.system;
    if (text.contains('ALMOX')) return WorkArea.warehouse;
    if (text.contains('SMD')) return WorkArea.smd;
    if (text.contains('ASSIST') || text.contains('SUPORTE')) {
      return WorkArea.support;
    }
    return WorkArea.production;
  }

  factory ProtheusWarehouse.fromJson(Map<String, dynamic> json) {
    return ProtheusWarehouse(
      filial: _text(json['filial']),
      code: _text(json['code'] ?? json['codigo']),
      description: _text(json['description'] ?? json['descricao']),
      type: _text(json['type'] ?? json['tipo']),
      integratesProduction: _text(
        json['integratesProduction'] ?? json['integraProducao'],
      ),
      mrp: _text(json['mrp']),
      alternateWarehouse: _text(
        json['alternateWarehouse'] ?? json['armazemAlternativo'],
      ),
    );
  }
}

abstract class ProtheusWarehouseRepository {
  Future<List<ProtheusWarehouse>> fetchWarehouses({String filial = '04'});
}

class EmptyProtheusWarehouseRepository implements ProtheusWarehouseRepository {
  const EmptyProtheusWarehouseRepository();

  @override
  Future<List<ProtheusWarehouse>> fetchWarehouses({
    String filial = '04',
  }) async {
    return const [];
  }
}

class ApiProtheusWarehouseRepository implements ProtheusWarehouseRepository {
  ApiProtheusWarehouseRepository({
    required String baseUrl,
    this.apiToken = '',
    http.Client? httpClient,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _http = httpClient ?? http.Client();

  final String baseUrl;
  final String apiToken;
  final http.Client _http;

  static const _timeout = Duration(seconds: 12);

  @override
  Future<List<ProtheusWarehouse>> fetchWarehouses({
    String filial = '04',
  }) async {
    final response = await _http
        .get(_uri('/api/v1/locais', {'filial': filial}), headers: _headers())
        .timeout(_timeout);
    _ensureOk(response);

    final decoded = jsonDecode(response.body);
    final items = decoded is List ? decoded : const [];
    return items
        .whereType<Map>()
        .map((item) => ProtheusWarehouse.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

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

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw StateError(
      'API Protheus HTTP ${response.statusCode}: ${response.body}',
    );
  }
}

String _text(Object? value) {
  return value?.toString().trim() ?? '';
}
