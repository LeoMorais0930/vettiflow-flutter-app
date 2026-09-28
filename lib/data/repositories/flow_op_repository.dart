import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/protheus_product_lookup.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_publisher.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_product_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/shared/models/finished_goods_routing.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';

/// Implementação de [OpRepository] que projeta o [ProductionFlowStore] (fonte
/// única, compartilhada com as telas de operador e a TV) no modelo de view
/// [OrdemProducao] usado pelo dashboard, e roteia as ações de volta ao store.
class FlowOpRepository implements OpRepository {
  FlowOpRepository(
    this._store, {
    this.protheusProducts = const EmptyProtheusProductRepository(),
    this.warehouseRequests,
  });

  final ProductionFlowStore _store;
  final ProtheusProductRepository protheusProducts;
  final WarehouseRequestStore? warehouseRequests;

  ProtheusPublishOutcome? _ultimoEnvioProtheus;

  static const _meses = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

  // ── Leitura ────────────────────────────────────────────────────────────

  @override
  Future<List<OrdemProducao>> fetchOrdens() async {
    final all = [..._store.activeOrders, ..._store.recentCompleted];
    return all.map(_toOrdem).toList();
  }

  @override
  Future<List<OrdemArmazenada>> fetchOrdensArmazenadas() async {
    return _store.orders
        .where((order) => order.totalStoredQuantity > 0)
        .map(
          (order) => OrdemArmazenada(
            numero: order.number,
            produto: order.productLabel,
            quantidadeOriginal: order.quantity,
            quantidadeArmazenada: order.totalStoredQuantity,
            unidade: order.unit.isEmpty ? 'un' : order.unit,
            responsavel: _responsavel(order),
            data: _fmtDate(order.updatedAt),
          ),
        )
        .toList();
  }

  @override
  Future<List<Responsavel>> fetchResponsaveis() async => Responsavel.todos;

  @override
  Future<List<String>> fetchProdutos() async {
    final local = _store.catalogItems.map((item) => item.label).toList();
    try {
      final protheus = (await protheusProducts.searchProducts('', limit: 250))
          .where((product) => !product.isBlockedForOperations)
          .map((product) => product.label);
      return {...protheus, ...local}.toList();
    } catch (_) {
      return local;
    }
  }

  @override
  Future<List<ProtheusProduct>> searchProdutos(String query) async {
    try {
      final products = await protheusProducts.searchProducts(query);
      return products
          .where((product) => !product.isBlockedForOperations)
          .toList();
    } catch (_) {
      return _store.catalogItems
          .where((item) {
            final normalized = query.trim().toLowerCase();
            return normalized.isEmpty ||
                item.code.toLowerCase().contains(normalized) ||
                item.name.toLowerCase().contains(normalized);
          })
          .take(12)
          .map(
            (item) => ProtheusProduct(
              code: item.code,
              description: item.name,
              type: '',
              unit: '',
              group: '',
            ),
          )
          .toList();
    }
  }

  // ── Ações ──────────────────────────────────────────────────────────────

  @override
  Future<OrdemProducao> criarOrdem(NovaOrdemDTO dto) async {
    _validateWarehouseAccess(dto);
    if (dto.components.isNotEmpty && _isBlank(dto.operatorPin)) {
      throw StateError('Informe o PIN para movimentar o Protheus.');
    }
    final catalogItem = _store.catalogItem(
      dto.productCode ?? _codeFromProduto(dto.produto),
    );
    final productCode = dto.productCode ?? catalogItem.code;
    final productName = dto.productName ?? catalogItem.name;
    final productionComponents = dto.components
        .map((component) => component.toProductionComponent())
        .toList();
    final order = await _store.createOrder(
      productCode: productCode,
      productName: productName,
      productUnit: dto.productUnit,
      components: productionComponents,
      quantity: dto.qtd,
      priority: dto.prioridade,
      operatorName: dto.openedBy ?? '',
      responsavel: null,
      prazo: dto.prazo,
      orderWarehouse: dto.armazem,
      initialStage: _initialStageForWarehouse(dto.armazem),
      plannedStages: dto.plannedStages,
      operatorPin: dto.operatorPin,
    );
    warehouseRequests?.createForOrder(
      order: order,
      catalogItem: ProductionCatalogItem(
        code: productCode,
        name: productName,
        defaultQuantity: dto.qtd,
        unit: dto.productUnit?.trim().isNotEmpty == true
            ? dto.productUnit!.trim()
            : catalogItem.unit,
        components: productionComponents,
      ),
      orderWarehouse: dto.armazem,
      requestedBy: dto.openedBy ?? dto.responsavel,
    );
    _ultimoEnvioProtheus = _store.protheusOutcome(order.number);
    return _toOrdem(order);
  }

  @override
  ProtheusPublishOutcome? get ultimoEnvioProtheus => _ultimoEnvioProtheus;

  @override
  Future<ProtheusProductLookup?> lookupProdutoPorCodigo(String code) async {
    final lookup = await protheusProducts.lookupByCode(code);
    if (lookup?.product.isBlockedForOperations ?? false) return null;
    return lookup;
  }

  @override
  Future<void> avancarStatus(
    String numero, {
    int quantidadeArmazenada = 0,
    String? operatorName,
    String? operatorPin,
  }) async {
    final order = _find(numero);
    if (order == null) return;
    if (order.currentStage == ProductionStage.expedition) {
      await _store.completeExpedition(
        numero,
        storedQuantity: quantidadeArmazenada,
      );
    } else {
      await _store.completeStage(
        numero,
        operatorName: operatorName,
        operatorPin: operatorPin,
      );
    }
  }

  @override
  Future<void> voltarStatus(String numero) async {
    await _store.regressStage(numero);
  }

  @override
  Future<void> atualizarRota(
    String numero,
    List<ProductionStage> stages,
  ) async {
    await _store.updatePlannedStages(numero, stages);
  }

  @override
  Future<void> cancelarOrdem(
    String numero, {
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) async {
    if (_isBlank(operatorPin)) {
      throw StateError('Informe o PIN para cancelar e devolver no Protheus.');
    }
    await _store.cancelOrder(
      numero,
      returnWarehouses: returnWarehouses,
      operatorName: operatorName,
      operatorPin: operatorPin,
    );
  }

  // ── Mapeamento ProductionOrderFlow → OrdemProducao ─────────────────────

  OrdemProducao _toOrdem(ProductionOrderFlow order) {
    final status = _statusFrom(order);
    final finalizada = status == StatusOP.finalizada;
    final catalogItem = _store.catalogItem(order.productCode);
    final routing = FinishedGoodsRouting.suggest(
      productCode: order.productCode,
      orderWarehouse: order.orderWarehouse,
      componentWarehouses: catalogItem.components.map((component) {
        return component.armazem;
      }),
    );
    return OrdemProducao(
      numero: order.number,
      produto: order.productLabel,
      qtd: order.quantity,
      responsavel: _responsavel(order),
      dataAbertura: _fmtDate(order.createdAt),
      prazo: order.prazo ?? '—',
      status: status,
      progresso: _progresso(order, finalizada),
      mes: _meses[order.createdAt.month - 1],
      atrasada: _atrasada(order.prazo, finalizada),
      prioridade: order.priority,
      stage: order.currentStage,
      armazem: order.orderWarehouse,
      localConsumoComponentes: order.componentConsumptionWarehouse.isNotEmpty
          ? order.componentConsumptionWarehouse
          : routing.componentConsumptionWarehouse,
      localEntradaAcabado: order.finishedGoodsWarehouse.isNotEmpty
          ? order.finishedGoodsWarehouse
          : routing.finishedGoodsWarehouse,
      roteamentoAvisos: order.routingWarnings.isNotEmpty
          ? order.routingWarnings
          : routing.warnings,
      materiais: catalogItem.components
          .map((c) => (c.description, c.quantity))
          .toList(),
      materiaisDetalhados: catalogItem.components
          .map(
            (component) => MaterialOpDetalhe(
              codigo: component.code,
              descricao: component.description,
              quantidadePorUnidade: component.quantity,
              quantidadeTotal: component.quantity * order.quantity,
              filial: component.filial.trim().isEmpty
                  ? '04'
                  : component.filial.trim(),
              armazem: component.armazem.trim(),
              movimentaEstoque: !component.code.toUpperCase().startsWith('MOD'),
            ),
          )
          .toList(),
      pausas: _pausas(order),
      tempoTotal: formatProductionDuration(order.totalElapsed(DateTime.now())),
      tempoEtapaAtual: formatProductionDuration(
        order.activeElapsed(DateTime.now()),
      ),
      observacao: order.lastObservation,
      plannedStages: order.plannedStages,
      assinaturas: _assinaturas(order),
    );
  }

  StatusOP _statusFrom(ProductionOrderFlow order) {
    if (order.currentStage == ProductionStage.completed ||
        order.currentStage == ProductionStage.storage) {
      return StatusOP.finalizada;
    }
    final started = order.timings.values.any((t) => t.startedAt != null);
    if (order.status == ProductionRunStatus.active ||
        order.status == ProductionRunStatus.paused ||
        order.currentStage != ProductionStage.warehouse ||
        started) {
      return StatusOP.emAndamento;
    }
    return StatusOP.naoIniciada;
  }

  int _progresso(ProductionOrderFlow order, bool finalizada) {
    if (finalizada) return 100;
    final total = ProductionStage.productionFlow.length;
    return (order.currentStage.progressIndex / total * 100).round();
  }

  String _responsavel(ProductionOrderFlow order) {
    final resp = order.responsavel;
    if (resp != null && resp.isNotEmpty) return resp;
    return '—';
  }

  List<ResumoPausaOp> _pausas(ProductionOrderFlow order) {
    final now = DateTime.now();
    return order.pauseEvents.reversed
        .map(
          (pause) => ResumoPausaOp(
            etapa: pause.stage.label,
            motivo: pause.reasonLabel,
            operador: pause.operatorName.isEmpty
                ? 'Operador'
                : pause.operatorName,
            tempo: formatProductionDuration(pause.pauseDuration(now)),
            iniciadaEm: _fmtDateTime(pause.createdAt),
            status: pause.resumedAt == null ? 'Pausada' : 'Retomada',
            quantidadeProduzida: pause.producedQuantity,
          ),
        )
        .toList();
  }

  List<ResumoAssinaturaOp> _assinaturas(ProductionOrderFlow order) {
    final items = <ResumoAssinaturaOp>[];
    final openingName = order.operatorName?.trim();
    final openingPin = order.operatorPin?.trim();
    if ((openingName != null && openingName.isNotEmpty) ||
        (openingPin != null && openingPin.isNotEmpty)) {
      items.add(
        ResumoAssinaturaOp(
          tipo: 'Criação',
          etapa: _initialStageForWarehouse(order.orderWarehouse).label,
          operador: openingName == null || openingName.isEmpty
              ? 'Responsável'
              : openingName,
          pin: _maskPin(openingPin),
          quando: _fmtDateTime(order.createdAt),
          detalhe: order.orderWarehouse.isEmpty
              ? 'Criou a OP'
              : 'Criou a OP no ${WarehouseRouting.labelForWarehouse(order.orderWarehouse)}',
        ),
      );
    }

    for (final session in order.operatorSessions) {
      items.add(
        ResumoAssinaturaOp(
          tipo: 'Início',
          etapa: session.stage.label,
          operador: session.operatorName,
          pin: _maskPin(session.operatorPin),
          quando: _fmtDateTime(session.startedAt),
          detalhe: 'Iniciou a etapa',
        ),
      );
      if (session.completedAt != null) {
        items.add(
          ResumoAssinaturaOp(
            tipo: 'Movimentação',
            etapa: session.stage.label,
            operador: session.operatorName,
            pin: _maskPin(session.operatorPin),
            quando: _fmtDateTime(session.completedAt!),
            detalhe: 'Concluiu a etapa e liberou a OP',
          ),
        );
      } else if (session.pausedAt != null) {
        items.add(
          ResumoAssinaturaOp(
            tipo: 'Pausa',
            etapa: session.stage.label,
            operador: session.operatorName,
            pin: _maskPin(session.operatorPin),
            quando: _fmtDateTime(session.pausedAt!),
            detalhe: 'Pausou a etapa',
          ),
        );
      }
    }

    for (final pause in order.pauseEvents) {
      items.add(
        ResumoAssinaturaOp(
          tipo: pause.resumedAt == null ? 'Pausa' : 'Retomada',
          etapa: pause.stage.label,
          operador: pause.operatorName,
          pin: _maskPin(pause.operatorPin),
          quando: _fmtDateTime(pause.resumedAt ?? pause.createdAt),
          detalhe: pause.resumedAt == null
              ? 'Pausou: ${pause.reasonLabel}'
              : 'Retomou após ${pause.reasonLabel}',
        ),
      );
    }

    items.sort((a, b) => b.quando.compareTo(a.quando));
    return items;
  }

  bool _atrasada(String? prazo, bool finalizada) {
    if (finalizada || prazo == null) return false;
    final parts = prazo.split('/');
    if (parts.length != 3) return false;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return false;
    return DateTime(y, m, d).isBefore(DateTime.now());
  }

  ProductionOrderFlow? _find(String numero) {
    for (final order in [..._store.activeOrders, ..._store.recentCompleted]) {
      if (order.number == numero) return order;
    }
    return null;
  }

  String _fmtDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  String _fmtDateTime(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  ProductionStage _initialStageForWarehouse(String warehouse) {
    return switch (WarehouseRouting.stageForWarehouse(warehouse)) {
      WorkStage.smd => ProductionStage.smd,
      WorkStage.firmware => ProductionStage.firmware,
      WorkStage.soldering => ProductionStage.soldering,
      WorkStage.testing => ProductionStage.testing,
      WorkStage.closing => ProductionStage.closing,
      WorkStage.expedition => ProductionStage.expedition,
      _ => ProductionStage.warehouse,
    };
  }

  String _codeFromProduto(String produto) {
    return produto.split(' - ').first.trim();
  }

  bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  String _maskPin(String? pin) {
    final value = pin?.trim();
    if (value == null || value.isEmpty) return '—';
    if (value.length <= 2) return '*' * value.length;
    return '${'*' * (value.length - 2)}${value.substring(value.length - 2)}';
  }

  void _validateWarehouseAccess(NovaOrdemDTO dto) {
    final openedBy = dto.openedBy;
    if (openedBy == null || openedBy.trim().isEmpty) return;

    final orderWarehouse = dto.armazem.trim();
    if (orderWarehouse.isNotEmpty &&
        !WarehouseRouting.canOperatorCreateOrder(openedBy, orderWarehouse)) {
      throw StateError(
        'Armazém inválido para abertura de OP: ${WarehouseRouting.labelForWarehouse(orderWarehouse)}.',
      );
    }

    // Componentes atendidos por outro armazem geram uma requisicao para
    // confirmacao do responsavel daquele setor; nao bloqueiam a abertura da OP.
  }
}
