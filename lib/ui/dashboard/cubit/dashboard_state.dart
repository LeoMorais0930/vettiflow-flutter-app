import 'package:vetti_flow_1_0/data/models/dashboard_order_groups.dart';
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
  final String loadError;
  final String filtroSetor;
  final String filtroSituacao;
  final bool mostrarConcluidas;

  const DashboardState({
    this.ordens = const [],
    this.armazenadas = const [],
    this.responsaveis = const [],
    this.produtos = const [],
    this.viewMode = ViewMode.kanban,
    this.filtroStatus,
    this.filtroPeriodo = 'ano_atual',
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
    this.loadError = '',
    this.filtroSetor = 'todos',
    this.filtroSituacao = 'todas',
    this.mostrarConcluidas = true,
  });

  static DateTime? openingDate(OrdemProducao op) {
    final value = op.encerradaNoErp ? op.dataEncerramento : op.dataAbertura;
    final parts = value.split('/');
    if (parts.length != 3) return DateTime.tryParse(value);
    final day = int.tryParse(parts[0]),
        month = int.tryParse(parts[1]),
        year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final date = DateTime(year, month, day);
    return date.day == day && date.month == month ? date : null;
  }

  bool _matchesSituation(OrdemProducao op) => switch (filtroSituacao) {
    'encerradas_erp' => op.encerradaNoErp,
    'concluidas_painel' =>
      op.erpReadOnly && !op.encerradaNoErp && op.status == StatusOP.finalizada,
    'abertas' => op.status != StatusOP.finalizada,
    _ => true,
  };

  bool _matchesPeriod(OrdemProducao op) {
    if (filtroPeriodo == 'todos') return true;
    final date = openingDate(op);
    if (filtroPeriodo == 'sem_data') return date == null;
    if (date == null) return false;
    if (filtroPeriodo == 'ano_atual') return date.year == DateTime.now().year;
    if (filtroPeriodo.startsWith('ano:')) {
      return '${date.year}' == filtroPeriodo.substring(4);
    }
    return '${date.year}-${date.month.toString().padLeft(2, '0')}' ==
        filtroPeriodo;
  }

  Map<String, String> get periodOptions {
    final dates = ordens.map(openingDate).whereType<DateTime>().toList()
      ..sort((a, b) => b.compareTo(a));
    return {
      'ano_atual': 'Ano atual (${DateTime.now().year})',
      'todos': 'Todo o histórico',
      for (final year in dates.map((d) => d.year).toSet())
        'ano:$year': 'Ano $year',
      for (final date in dates)
        '${date.year}-${date.month.toString().padLeft(2, '0')}':
            '${date.month.toString().padLeft(2, '0')}/${date.year}',
      'sem_data': 'Sem data de referência',
    };
  }

  List<String> get sectors =>
      ordens.map((o) => erpOrderSectorLabel(o.armazem)).toSet().toList()
        ..sort();

  List<OrdemProducao> get ordensFiltradas {
    var result = ordens.where((op) {
      if (!_matchesSituation(op) || !_matchesPeriod(op)) {
        return false;
      }
      if (filtroSetor != 'todos' &&
          erpOrderSectorLabel(op.armazem) != filtroSetor) {
        return false;
      }
      if (!mostrarConcluidas && op.status == StatusOP.finalizada) return false;
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

    result.sort((a, b) {
      final dateA = openingDate(a), dateB = openingDate(b);
      if (dateA == null && dateB == null) return a.numero.compareTo(b.numero);
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      final byDate = dateB.compareTo(dateA);
      return byDate != 0 ? byDate : a.numero.compareTo(b.numero);
    });
    return result;
  }

  Map<StatusOP, int> get kpiCounts {
    final base = ordens.where((op) {
      if (!_matchesSituation(op) || !_matchesPeriod(op)) {
        return false;
      }
      if (filtroSetor != 'todos' &&
          erpOrderSectorLabel(op.armazem) != filtroSetor) {
        return false;
      }
      if (!mostrarConcluidas && op.status == StatusOP.finalizada) return false;
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

  int get atrasadasCount => ordensFiltradas
      .where((op) => op.status == StatusOP.emAndamento && op.atrasada)
      .length;

  OrdemProducao? get selectedOrdem => selectedOP == null
      ? null
      : ordens.cast<OrdemProducao?>().firstWhere(
          (op) => op?.numero == selectedOP,
          orElse: () => null,
        );

  bool get hasActiveFilters =>
      filtroSituacao != 'todas' ||
      filtroPeriodo != 'todos' ||
      filtroSetor != 'todos' ||
      !mostrarConcluidas ||
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
    String? loadError,
    String? filtroSetor,
    String? filtroSituacao,
    bool? mostrarConcluidas,
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
      loadError: loadError ?? this.loadError,
      filtroSetor: filtroSetor ?? this.filtroSetor,
      filtroSituacao: filtroSituacao ?? this.filtroSituacao,
      mostrarConcluidas: mostrarConcluidas ?? this.mostrarConcluidas,
    );
  }
}
