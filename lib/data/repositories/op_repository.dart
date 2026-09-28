import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/protheus_product_lookup.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_publisher.dart';

class NovaOrdemDTO {
  final String produto;
  final String? productCode;
  final String? productName;
  final String? productUnit;
  final List<ProtheusProductComponent> components;
  final List<ProtheusChildOrder> smdReleaseOrders;
  final String filial;
  final String armazem;
  final String? openedBy;
  final String? operatorPin;
  final int qtd;
  final String responsavel;
  final String? prazo;
  final String prioridade;
  final List<ProductionStage> plannedStages;

  const NovaOrdemDTO({
    required this.produto,
    this.productCode,
    this.productName,
    this.productUnit,
    this.components = const [],
    this.smdReleaseOrders = const [],
    this.filial = '04',
    this.armazem = '',
    this.openedBy,
    this.operatorPin,
    required this.qtd,
    required this.responsavel,
    this.prazo,
    this.prioridade = 'Media',
    this.plannedStages = const [],
  });
}

abstract class OpRepository {
  Future<List<OrdemProducao>> fetchOrdens();
  Future<List<OrdemArmazenada>> fetchOrdensArmazenadas();
  Future<OrdemProducao> criarOrdem(NovaOrdemDTO dto);

  /// Como ficou o rascunho Protheus da ultima OP aberta por [criarOrdem].
  ///
  /// `null` quando nao houve tentativa. A tela le logo apos o `await` para
  /// avisar o operador que a escrita real no Protheus segue bloqueada.
  ProtheusPublishOutcome? get ultimoEnvioProtheus => null;

  Future<void> avancarStatus(
    String numero, {
    int quantidadeArmazenada = 0,
    String? operatorName,
    String? operatorPin,
  });
  Future<void> voltarStatus(String numero);
  Future<void> atualizarRota(String numero, List<ProductionStage> stages);
  Future<void> cancelarOrdem(
    String numero, {
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  });
  Future<List<Responsavel>> fetchResponsaveis();
  Future<List<String>> fetchProdutos();
  Future<List<ProtheusProduct>> searchProdutos(String query);
  Future<ProtheusProductLookup?> lookupProdutoPorCodigo(String code);
}
