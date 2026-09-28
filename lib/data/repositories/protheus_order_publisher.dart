import 'package:flutter/foundation.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/mutation_sync_service.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';

/// O que aconteceu com o rascunho local da OP para o Protheus.
///
/// Existe porque abrir OP no VettiFlow gravava so em
/// `vettiflow.production_orders` e ninguem ficava sabendo que a SC2/SD4 nao
/// tinham sido tocadas. Agora o resultado e explicito e, no modo atual, fica
/// bloqueado em somente leitura.
@immutable
class ProtheusPublishOutcome {
  const ProtheusPublishOutcome._({
    required this.gravouNoProtheus,
    required this.mutationId,
    this.simulacao = false,
    this.motivo,
    this.protheusRef,
  });

  /// Mantido para compatibilidade com testes antigos de simulacao controlada.
  const ProtheusPublishOutcome.gravada({
    required String mutationId,
    String? protheusRef,
  }) : this._(
         gravouNoProtheus: true,
         mutationId: mutationId,
         protheusRef: protheusRef,
       );

  /// Nao chegou. A mutacao fica como rascunho local visivel.
  const ProtheusPublishOutcome.naFila({
    required String mutationId,
    required String motivo,
  }) : this._(gravouNoProtheus: false, mutationId: mutationId, motivo: motivo);

  /// A API respondeu "enviado", mas indicou simulacao no retorno.
  ///
  /// Sem isto o app anunciaria sucesso em cima de um `DRY:` — exatamente o
  /// silencio que este codigo existe para acabar.
  const ProtheusPublishOutcome.simulada({required String mutationId})
    : this._(
        gravouNoProtheus: false,
        simulacao: true,
        mutationId: mutationId,
        motivo: 'a API esta em modo de simulacao',
      );

  final bool gravouNoProtheus;
  final bool simulacao;
  final String mutationId;

  /// Por que nao chegou. So preenchido quando [gravouNoProtheus] e falso.
  final String? motivo;
  final String? protheusRef;

  /// Frase pronta para a tela, ja no tom de aviso.
  String get aviso => simulacao
      ? 'nao foi gravada no Protheus: ${motivo!}. A SC2/SD4 nao foram '
            'tocadas.'
      : 'nao foi enviada ao Protheus: ${motivo ?? 'motivo desconhecido'}. '
            'Ficou como rascunho local somente leitura.';
}

/// Converte abertura de OP em rascunho local relacionado ao Protheus.
abstract class ProtheusOrderPublisher {
  Future<ProtheusPublishOutcome> publishOrder({
    required ProductionOrderFlow order,
    required ProductionCatalogItem product,
    required String filial,
  });
}

/// Implementacao local: enfileira a `AberturaOpMutation` e passa pelo client.
/// O client atual bloqueia escrita antes de qualquer POST, mantendo leitura
/// Protheus como unica integracao ativa.
class MutationProtheusOrderPublisher implements ProtheusOrderPublisher {
  const MutationProtheusOrderPublisher({
    required this.mutations,
    required this.sync,
  });

  final PendingMutationStore mutations;
  final MutationSyncService sync;

  @override
  Future<ProtheusPublishOutcome> publishOrder({
    required ProductionOrderFlow order,
    required ProductionCatalogItem product,
    required String filial,
  }) async {
    final mutation = mutations.enqueue(
      (id, criadoEm) => AberturaOpMutation(
        id: id,
        filial: filial,
        criadoEm: criadoEm,
        autor: order.operatorName ?? '',
        produto: order.productCode,
        produtoDescricao: order.productName,
        quantidade: order.quantity,
        localProducao: order.orderWarehouse,
        previsao: order.prazo,
        empenhos: [
          for (final component in product.components)
            EmpenhoLinha(
              produto: component.code,
              descricao: component.description,
              quantidade: (component.quantity * order.quantity).toDouble(),
              local: component.armazem,
              structureSequence: component.structureSequence,
            ),
        ],
      ),
    );

    final resultado = await sync.enviarEFinalizar(mutation);
    final atualizada = mutations.all
        .where((item) => item.id == mutation.id)
        .firstOrNull;

    if (resultado == MutationStatus.enviado) {
      final ref = atualizada?.protheusRef ?? '';
      if (ref.startsWith('DRY:')) {
        return ProtheusPublishOutcome.simulada(mutationId: mutation.id);
      }
      return ProtheusPublishOutcome.gravada(
        mutationId: mutation.id,
        protheusRef: atualizada?.protheusRef,
      );
    }

    return ProtheusPublishOutcome.naFila(
      mutationId: mutation.id,
      motivo:
          atualizada?.erro ??
          sync.lastError ??
          _motivoPadrao(resultado, atualizada?.protheusRef),
    );
  }

  String _motivoPadrao(MutationStatus status, String? ref) => switch (status) {
    MutationStatus.armazenado =>
      'a API aceitou (${ref ?? 'sem ref'}) mas nao conseguiu aplicar em '
          'SC2/SD4',
    MutationStatus.erro => 'a API recusou a abertura',
    _ => 'a API do Protheus nao respondeu',
  };
}
