import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/protheus_product_lookup.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_publisher.dart';

class MockOpRepository implements OpRepository {
  final List<OrdemProducao> _ordens = [
    const OrdemProducao(
      numero: 'OP-2026-0188',
      produto: 'Sirene Eletrônica SE-200',
      qtd: 120,
      responsavel: 'Tatiane',
      dataAbertura: '24/06/2026',
      prazo: '02/07/2026',
      status: StatusOP.aAbrir,
      progresso: 0,
      mes: 'jun',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0189',
      produto: 'Controle Remoto CR-4',
      qtd: 300,
      responsavel: 'Marcos Silva',
      dataAbertura: '24/06/2026',
      prazo: '04/07/2026',
      status: StatusOP.aAbrir,
      progresso: 0,
      mes: 'jun',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0190',
      produto: 'Sensor de Presença SP-30',
      qtd: 80,
      responsavel: 'Juliana',
      dataAbertura: '23/06/2026',
      prazo: '03/07/2026',
      status: StatusOP.aAbrir,
      progresso: 0,
      mes: 'jun',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0191',
      produto: 'Módulo GSM MG-1',
      qtd: 60,
      responsavel: 'Bryan',
      dataAbertura: '23/06/2026',
      prazo: '08/07/2026',
      status: StatusOP.aAbrir,
      progresso: 0,
      mes: 'jun',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0184',
      produto: 'Central de Alarme CA-8',
      qtd: 50,
      responsavel: 'Tatiane',
      dataAbertura: '20/06/2026',
      prazo: '30/06/2026',
      status: StatusOP.naoIniciada,
      progresso: 0,
      mes: 'jun',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0185',
      produto: 'Sirene Bidirecional SB-150',
      qtd: 100,
      responsavel: 'Patrícia Lima',
      dataAbertura: '20/06/2026',
      prazo: '01/07/2026',
      status: StatusOP.naoIniciada,
      progresso: 0,
      mes: 'jun',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0186',
      produto: 'Teclado de Comando TC-12',
      qtd: 75,
      responsavel: 'Marcos Silva',
      dataAbertura: '21/06/2026',
      prazo: '29/06/2026',
      status: StatusOP.naoIniciada,
      progresso: 0,
      mes: 'jun',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0187',
      produto: 'Discadora Telefônica DT-2',
      qtd: 40,
      responsavel: 'Juliana',
      dataAbertura: '21/06/2026',
      prazo: '05/07/2026',
      status: StatusOP.naoIniciada,
      progresso: 0,
      mes: 'jun',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0179',
      produto: 'Sirene Audiovisual AV-120',
      qtd: 90,
      responsavel: 'Bryan',
      dataAbertura: '16/06/2026',
      prazo: '26/06/2026',
      status: StatusOP.emAndamento,
      progresso: 62,
      mes: 'jun',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0180',
      produto: 'Central de Alarme CA-16',
      qtd: 30,
      responsavel: 'Tatiane',
      dataAbertura: '17/06/2026',
      prazo: '27/06/2026',
      status: StatusOP.emAndamento,
      progresso: 45,
      mes: 'jun',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0181',
      produto: 'Sirene Eletrônica SE-200',
      qtd: 150,
      responsavel: 'Patrícia Lima',
      dataAbertura: '17/06/2026',
      prazo: '25/06/2026',
      status: StatusOP.emAndamento,
      progresso: 80,
      mes: 'jun',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0182',
      produto: 'Controle Remoto CR-4',
      qtd: 250,
      responsavel: 'Marcos Silva',
      dataAbertura: '18/06/2026',
      prazo: '22/06/2026',
      status: StatusOP.emAndamento,
      progresso: 33,
      mes: 'jun',
      atrasada: true,
    ),
    const OrdemProducao(
      numero: 'OP-2026-0183',
      produto: 'Sensor de Presença SP-30',
      qtd: 110,
      responsavel: 'Juliana',
      dataAbertura: '18/06/2026',
      prazo: '23/06/2026',
      status: StatusOP.emAndamento,
      progresso: 18,
      mes: 'jun',
      atrasada: true,
    ),
    const OrdemProducao(
      numero: 'OP-2026-0171',
      produto: 'Sirene Eletrônica SE-200',
      qtd: 200,
      responsavel: 'Tatiane',
      dataAbertura: '02/06/2026',
      prazo: '12/06/2026',
      status: StatusOP.finalizada,
      progresso: 100,
      mes: 'jun',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0172',
      produto: 'Central de Alarme CA-8',
      qtd: 60,
      responsavel: 'Bryan',
      dataAbertura: '03/06/2026',
      prazo: '13/06/2026',
      status: StatusOP.finalizada,
      progresso: 100,
      mes: 'jun',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0168',
      produto: 'Teclado de Comando TC-12',
      qtd: 90,
      responsavel: 'Patrícia Lima',
      dataAbertura: '28/05/2026',
      prazo: '06/06/2026',
      status: StatusOP.finalizada,
      progresso: 100,
      mes: 'mai',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0169',
      produto: 'Sirene Bidirecional SB-150',
      qtd: 120,
      responsavel: 'Marcos Silva',
      dataAbertura: '29/05/2026',
      prazo: '09/06/2026',
      status: StatusOP.finalizada,
      progresso: 100,
      mes: 'mai',
    ),
    const OrdemProducao(
      numero: 'OP-2026-0170',
      produto: 'Discadora Telefônica DT-2',
      qtd: 55,
      responsavel: 'Juliana',
      dataAbertura: '30/05/2026',
      prazo: '10/06/2026',
      status: StatusOP.finalizada,
      progresso: 100,
      mes: 'mai',
    ),
  ];

  final List<OrdemArmazenada> _armazenadas = [
    const OrdemArmazenada(
      numero: 'OP-2026-0172',
      produto: 'Central de Alarme CA-8',
      quantidadeOriginal: 60,
      quantidadeArmazenada: 20,
      responsavel: 'Bryan',
      data: '13/06/2026',
    ),
  ];

  int _nextSeq = 192;

  @override
  Future<List<OrdemProducao>> fetchOrdens() async => List.unmodifiable(_ordens);

  @override
  Future<List<OrdemArmazenada>> fetchOrdensArmazenadas() async =>
      List.unmodifiable(_armazenadas);

  @override
  ProtheusPublishOutcome? get ultimoEnvioProtheus => null;

  @override
  Future<OrdemProducao> criarOrdem(NovaOrdemDTO dto) async {
    final op = OrdemProducao(
      numero: 'OP-2026-${_nextSeq.toString().padLeft(4, '0')}',
      produto: dto.produto,
      qtd: dto.qtd,
      responsavel: dto.responsavel,
      dataAbertura: '25/06/2026',
      prazo: dto.prazo ?? '—',
      status: StatusOP.aAbrir,
      progresso: 0,
      mes: 'jun',
      prioridade: dto.prioridade,
    );
    _nextSeq++;
    _ordens.insert(0, op);
    return op;
  }

  @override
  Future<void> avancarStatus(
    String numero, {
    int quantidadeArmazenada = 0,
    String? operatorName,
    String? operatorPin,
  }) async {
    final idx = _ordens.indexWhere((o) => o.numero == numero);
    if (idx == -1) return;
    final op = _ordens[idx];
    final next = op.status.next;
    if (next == null) return;

    _ordens[idx] = op.copyWith(
      status: next,
      progresso: switch (next) {
        StatusOP.naoIniciada => 0,
        StatusOP.emAndamento => 8,
        StatusOP.finalizada => 100,
        _ => op.progresso,
      },
      atrasada: next == StatusOP.finalizada ? false : op.atrasada,
    );

    if (next == StatusOP.finalizada && quantidadeArmazenada > 0) {
      _armazenadas.removeWhere((item) => item.numero == op.numero);
      _armazenadas.insert(
        0,
        OrdemArmazenada(
          numero: op.numero,
          produto: op.produto,
          quantidadeOriginal: op.qtd,
          quantidadeArmazenada: quantidadeArmazenada.clamp(0, op.qtd),
          responsavel: op.responsavel,
          data: '25/06/2026',
        ),
      );
    }
  }

  @override
  Future<void> voltarStatus(String numero) async {
    final idx = _ordens.indexWhere((o) => o.numero == numero);
    if (idx == -1) return;
    final op = _ordens[idx];
    final prev = op.status.previous;
    if (prev == null) return;

    _ordens[idx] = op.copyWith(
      status: prev,
      progresso: prev == StatusOP.emAndamento ? 8 : 0,
      atrasada: false,
    );
  }

  @override
  Future<void> atualizarRota(
    String numero,
    List<ProductionStage> stages,
  ) async {
    final idx = _ordens.indexWhere((o) => o.numero == numero);
    if (idx == -1) return;
    _ordens[idx] = _ordens[idx].copyWith(plannedStages: stages);
  }

  @override
  Future<void> cancelarOrdem(
    String numero, {
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) async {
    _ordens.removeWhere((o) => o.numero == numero);
  }

  @override
  Future<List<Responsavel>> fetchResponsaveis() async => Responsavel.todos;

  @override
  Future<List<String>> fetchProdutos() async {
    return _ordens.map((o) => o.produto).toSet().toList();
  }

  @override
  Future<List<ProtheusProduct>> searchProdutos(String query) async {
    final normalized = query.trim().toLowerCase();
    return (await fetchProdutos())
        .where(
          (produto) =>
              normalized.isEmpty || produto.toLowerCase().contains(normalized),
        )
        .take(12)
        .map((produto) {
          final parts = produto.split(' - ');
          return ProtheusProduct(
            code: parts.first.trim(),
            description: parts.length > 1
                ? parts.sublist(1).join(' - ')
                : produto,
            type: '',
            unit: '',
            group: '',
          );
        })
        .toList();
  }

  @override
  Future<ProtheusProductLookup?> lookupProdutoPorCodigo(String code) async {
    return null;
  }
}
