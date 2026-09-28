import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_warehouse_repository.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';

void main() {
  test(
    'API warehouse repository decodes official Protheus warehouses',
    () async {
      final repository = ApiProtheusWarehouseRepository(
        baseUrl: 'http://api.local',
        apiToken: 'token-teste',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v1/locais');
          expect(request.url.queryParameters['filial'], '04');
          expect(request.headers['X-API-Token'], 'token-teste');
          return http.Response(
            jsonEncode([
              {
                'filial': '04',
                'code': '04',
                'description': 'PRODUCAO PTH',
                'type': '1',
                'integratesProduction': '3',
                'mrp': '1',
              },
              {
                'filial': '04',
                'code': '70',
                'description': 'TERCEIROS - MAURO',
                'type': '1',
                'integratesProduction': '3',
                'mrp': '1',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final warehouses = await repository.fetchWarehouses(filial: '04');

      expect(warehouses.map((warehouse) => warehouse.code), ['04', '70']);
      expect(warehouses.first.label, 'Armazém 04 - PRODUCAO PTH');
      expect(warehouses.first.inferredArea, WorkArea.production);
      expect(warehouses.last.inferredArea, WorkArea.production);
      expect(warehouses.last.isThirdParty, isTrue);
    },
  );

  test('warehouse model classifies official missing VettiFlow locations', () {
    const pth = ProtheusWarehouse(code: '04', description: 'PRODUCAO PTH');
    const thirdParty = ProtheusWarehouse(
      code: '72',
      description: 'TER. - GWANDS SP',
    );
    const obsolete = ProtheusWarehouse(
      code: '08',
      description: 'ITENS OBSOLETOS',
    );

    expect(pth.inferredArea, WorkArea.production);
    expect(thirdParty.isThirdParty, isTrue);
    expect(thirdParty.inferredArea, WorkArea.production);
    expect(obsolete.isSpecial, isTrue);
    expect(obsolete.inferredArea, WorkArea.system);
  });
}
