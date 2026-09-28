import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/mutation_sync_service.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_publisher.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';

ProductionFlowStore _storeComLeitura(
  ProtheusSyncClient client,
  PendingMutationStore mutations,
) {
  return ProductionFlowStore(
    protheusPublisher: MutationProtheusOrderPublisher(
      mutations: mutations,
      sync: MutationSyncService(store: mutations, client: client),
    ),
  );
}

Future<ProductionOrderFlow> _abrirOp(ProductionFlowStore store) {
  return store.createOrder(
    productCode: '575-0863A',
    productName: 'SUB MEC SMART ALARM MONITORADA',
    quantity: 15,
    priority: 'Media',
    operatorName: 'Tatiane',
    operatorPin: '2001',
    orderWarehouse: '05',
    components: const [
      ProductionComponent(
        code: '550-0845',
        description: 'Componente mecanico',
        quantity: 2,
        stock: 900,
        filial: '04',
        armazem: '05',
        structureSequence: '0001',
      ),
    ],
  );
}

void main() {
  test('sem publicador configurado nao ha tentativa de escrita', () async {
    final store = ProductionFlowStore();

    final order = await _abrirOp(store);

    expect(store.protheusOutcome(order.number), isNull);
    expect(store.ordersNotInProtheus, isEmpty);
  });

  test(
    'publicador enfileira rascunho local, mas o client nao chama HTTP',
    () async {
      final methods = <String>[];
      final client = ProtheusSyncClient(
        baseUrl: 'http://api.local',
        httpClient: MockClient((request) async {
          methods.add('${request.method} ${request.url.path}');
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );
      addTearDown(client.dispose);
      final mutations = PendingMutationStore();
      final store = _storeComLeitura(client, mutations);

      final order = await _abrirOp(store);
      final envio = store.protheusOutcome(order.number);

      expect(envio, isNotNull);
      expect(envio!.gravouNoProtheus, isFalse);
      expect(envio.motivo, contains('somente leitura'));
      expect(envio.aviso, contains('nao foi enviada ao Protheus'));
      expect(store.ordersNotInProtheus, [order.number]);
      expect(methods, isEmpty);

      final mutation = mutations.all.single;
      expect(mutation, isA<AberturaOpMutation>());
      expect(mutation.status, MutationStatus.erro);
      expect(mutation.erro, contains('somente leitura'));
    },
  );

  test('o empenho fica representado no rascunho local da abertura', () async {
    final client = ProtheusSyncClient(
      baseUrl: 'http://api.local',
      httpClient: MockClient((request) async {
        fail('cliente somente leitura nao deve chamar ${request.method}');
      }),
    );
    addTearDown(client.dispose);
    final mutations = PendingMutationStore();
    final store = _storeComLeitura(client, mutations);

    await _abrirOp(store);

    final mutation = mutations.all.single as AberturaOpMutation;
    expect(mutation.produto, '575-0863A');
    expect(mutation.quantidade, 15);
    expect(mutation.localProducao, '05');
    expect(mutation.filial, '04');
    expect(mutation.empenhos.single.produto, '550-0845');
    expect(mutation.empenhos.single.quantidade, 30);
    expect(mutation.empenhos.single.local, '05');
    expect(mutation.empenhos.single.structureSequence, '0001');
  });
}
