import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';

enum ViewMode { kanban, tabela, cards, armazenadas, responsaveis, relatorios }

class DashboardState {
  final List<OrdemProducao> ordens;
  final List<OrdemArmazenada> armazenadas;
  final List<Responsavel> responsaveis;
  final List<String> produtos;
  final ViewMode viewMode;
  final StatusOP? filtroStatus;
  final String filtroPeriodo;
  final String filtroResponsavel;
  final String filtroProduto;
  final String busca;
  final String? selectedOP;
  final bool novaOPOpen;
  final bool confirmCancel;
  final bool filtrosOpen;
  final bool databaseSyncing;
  final String databaseSyncMessage;

  /// Aviso de que a ultima OP aberta nao chegou ao Protheus. Vazio = tudo
  /// certo. A tela mostra e limpa com [DashboardCubit.limparAvisoProtheus].
  final String protheusAviso;

  const DashboardState({
    this.ordens = const [],
    this.armazenadas = const [],
    this.responsaveis = const [],
    this.produtos = const [],
    this.viewMode = ViewMode.kanban,
    this.filtroStatus,
    this.filtroPeriodo = 'todos',
    this.filtroResponsavel = 'todos',
    this.filtroProduto = 'todos',
    this.busca = '',
    this.selectedOP,
    this.novaOPOpen = false,
    this.confirmCancel = false,
    this.filtrosOpen = false,
    this.databaseSyncing = false,
    this.databaseSyncMessage = '',
    this.protheusAviso = '',
  });

  List<OrdemProducao> get ordensFiltradas {
    var result = ordens.where((op) {
      if (filtroPeriodo != 'todos' && op.mes != filtroPeriodo) {
        return false;
      }
      if (filtroResponsavel != 'todos' && op.responsavel != filtroResponsavel) {
        return false;
      }
      if (filtroProduto != 'todos' && op.produto != filtroProduto) {
        return false;
      }
      if (busca.isNotEmpty) {
        final q = busca.toLowerCase();
        if (!op.numero.toLowerCase().contains(q) &&
            !op.produto.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    if (filtroStatus != null) {
      result = result.where((op) => op.status == filtroStatus).toList();
    }

    return result;
  }

  Map<StatusOP, int> get kpiCounts {
    final base = ordens.where((op) {
      if (filtroPeriodo != 'todos' && op.mes != filtroPeriodo) {
        return false;
      }
      if (filtroResponsavel != 'todos' && op.responsavel != filtroResponsavel) {
        return false;
      }
      if (filtroProduto != 'todos' && op.produto != filtroProduto) {
        return false;
      }
      if (busca.isNotEmpty) {
        final q = busca.toLowerCase();
        if (!op.numero.toLowerCase().contains(q) &&
            !op.produto.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    });

    final counts = <StatusOP, int>{};
    for (final s in StatusOP.values) {
      counts[s] = base.where((op) => op.status == s).length;
    }
    return counts;
  }

  int get atrasadasCount => ordens
      .where((op) => op.status == StatusOP.emAndamento && op.atrasada)
      .length;

  OrdemProducao? get selectedOrdem => selectedOP == null
      ? null
      : ordens.cast<OrdemProducao?>().firstWhere(
          (op) => op?.numero == selectedOP,
          orElse: () => null,
        );

  bool get hasActiveFilters =>
      filtroPeriodo != 'todos' ||
      filtroResponsavel != 'todos' ||
      filtroProduto != 'todos' ||
      filtroStatus != null ||
      busca.isNotEmpty;

  String get resultText => '${ordensFiltradas.length} de ${ordens.length} OPs';

  String get armazenadasResultText =>
      '${armazenadas.length} OP${armazenadas.length == 1 ? '' : 's'} armazenada${armazenadas.length == 1 ? '' : 's'}';

  DashboardState copyWith({
    List<OrdemProducao>? ordens,
    List<OrdemArmazenada>? armazenadas,
    List<Responsavel>? responsaveis,
    List<String>? produtos,
    ViewMode? viewMode,
    StatusOP? Function()? filtroStatus,
    String? filtroPeriodo,
    String? filtroResponsavel,
    String? filtroProduto,
    String? busca,
    String? Function()? selectedOP,
    bool? novaOPOpen,
    bool? confirmCancel,
    bool? filtrosOpen,
    bool? databaseSyncing,
    String? databaseSyncMessage,
    String? protheusAviso,
  }) {
    return DashboardState(
      ordens: ordens ?? this.ordens,
      armazenadas: armazenadas ?? this.armazenadas,
      responsaveis: responsaveis ?? this.responsaveis,
      produtos: produtos ?? this.produtos,
      viewMode: viewMode ?? this.viewMode,
      filtroStatus: filtroStatus != null ? filtroStatus() : this.filtroStatus,
      filtroPeriodo: filtroPeriodo ?? this.filtroPeriodo,
      filtroResponsavel: filtroResponsavel ?? this.filtroResponsavel,
      filtroProduto: filtroProduto ?? this.filtroProduto,
      busca: busca ?? this.busca,
      selectedOP: selectedOP != null ? selectedOP() : this.selectedOP,
      novaOPOpen: novaOPOpen ?? this.novaOPOpen,
      confirmCancel: confirmCancel ?? this.confirmCancel,
      filtrosOpen: filtrosOpen ?? this.filtrosOpen,
      databaseSyncing: databaseSyncing ?? this.databaseSyncing,
      databaseSyncMessage: databaseSyncMessage ?? this.databaseSyncMessage,
      protheusAviso: protheusAviso ?? this.protheusAviso,
    );
  }
}
