import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/repositories/local_json_persistence.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';

/// A fila existe para o caso da API estar fora do ar. Se ela nao sobrevive ao
/// fechamento do app, o pendente evapora justamente no cenario que ela cobre.
void main() {
  late Directory pasta;

  setUp(() {
    pasta = Directory.systemTemp.createTempSync('vetti_fila_');
    LocalJsonPersistence.directoryOverride = pasta.path;
  });

  tearDown(() {
    LocalJsonPersistence.directoryOverride = null;
    if (pasta.existsSync()) pasta.deleteSync(recursive: true);
  });

  AberturaOpMutation abrirOp(String id, DateTime criadoEm) =>
      AberturaOpMutation(
        id: id,
        filial: '04',
        criadoEm: criadoEm,
        autor: 'Tatiane',
        produto: '575-0864',
        produtoDescricao: 'CENTRAL SMART VETTI',
        quantidade: 65,
        localProducao: '05',
        previsao: '20260827',
      );

  test('mutacao pendente volta depois de reabrir o app', () {
    final antes = PendingMutationStore();
    final criada = antes.enqueue(abrirOp);
    expect(antes.pendingCount, 1);

    // Nova instancia = app reaberto: nada compartilhado em memoria.
    final depois = PendingMutationStore();

    expect(depois.pendingCount, 1);
    final restaurada = depois.pending.single;
    expect(restaurada.id, criada.id);
    expect(restaurada.status, MutationStatus.pendente);
    expect((restaurada as AberturaOpMutation).produto, '575-0864');
    expect(restaurada.quantidade, 65);
    expect(restaurada.filial, '04');
  });

  test('o que ja foi aplicado nao reaparece como pendente', () {
    final antes = PendingMutationStore();
    final criada = antes.enqueue(abrirOp);
    antes.updateStatus(
      criada.id,
      status: MutationStatus.enviado,
      protheusRef: '01596501001',
    );

    final depois = PendingMutationStore();

    expect(depois.pendingCount, 0);
    expect(depois.sent.single.protheusRef, '01596501001');
  });

  test('descartar da fila tambem vale no proximo boot', () {
    final antes = PendingMutationStore();
    final criada = antes.enqueue(abrirOp);
    expect(antes.discard(criada.id), isTrue);

    expect(PendingMutationStore().awaitingCount, 0);
  });

  test('arquivo corrompido nao impede o app de abrir', () {
    PendingMutationStore().enqueue(abrirOp);
    final arquivo = pasta.listSync().whereType<File>().single;
    arquivo.writeAsStringSync('{isso nao e json valido');

    expect(PendingMutationStore().awaitingCount, 0);
  });

  test('sem override, um teste nao encosta no arquivo real da maquina', () {
    LocalJsonPersistence.directoryOverride = null;

    PendingMutationStore().enqueue(abrirOp);

    expect(PendingMutationStore().awaitingCount, 0);
    expect(pasta.listSync(), isEmpty);
  });
}
