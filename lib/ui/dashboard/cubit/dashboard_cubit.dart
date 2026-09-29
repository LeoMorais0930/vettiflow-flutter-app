import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/protheus_product_lookup.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final OpRepository _repository;

  DashboardCubit(this._repository) : super(const DashboardState());

  Future<void> loadOrdens() async {
    if (state.databaseSyncing || isClosed) return;
    emit(
      state.copyWith(
        databaseSyncing: true,
        databaseSyncMessage: 'Consultando OPs no Protheus…',
        loadError: '',
      ),
    );
    try {
      final ordens = await _repository.fetchOrdens();
      final armazenadas = await _repository.fetchOrdensArmazenadas();
      final responsaveis = await _repository.fetchResponsaveis();
      final produtos = await _repository.fetchProdutos();
      if (isClosed) return;
      emit(
        state.copyWith(
          ordens: ordens,
          armazenadas: armazenadas,
          responsaveis: responsaveis,
          produtos: produtos,
          databaseSyncing: false,
          databaseSyncMessage: '',
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          databaseSyncing: false,
          databaseSyncMessage: '',
          loadError:
              'Não foi possível atualizar as OPs e suas etapas. Os dados exibidos podem estar desatualizados. Tente novamente.',
        ),
      );
    }
  }

  void setViewMode(ViewMode mode) {
    emit(state.copyWith(viewMode: mode));
  }

  void toggleStatusFilter(StatusOP status) {
    emit(
      state.copyWith(
        filtroStatus: () => state.filtroStatus == status ? null : status,
      ),
    );
  }

  void setFiltroSituacao(String value) => emit(
    state.copyWith(
      filtroSituacao: value,
      mostrarConcluidas: true,
      filtroStatus: () => null,
    ),
  );

  void setFiltroSetor(String value) => emit(state.copyWith(filtroSetor: value));
  void setMostrarConcluidas(bool value) =>
      emit(state.copyWith(mostrarConcluidas: value));

  void setFiltroPeriodo(String value) {
    emit(state.copyWith(filtroPeriodo: value));
  }

  void setFiltroResponsavel(String value) {
    emit(state.copyWith(filtroResponsavel: value));
  }

  void setFiltroProduto(String value) {
    emit(state.copyWith(filtroProduto: value));
  }

  void setBusca(String value) {
    emit(state.copyWith(busca: value));
  }

  void limparFiltros() {
    emit(
      state.copyWith(
        filtroPeriodo: 'todos',
        filtroSetor: 'todos',
        filtroSituacao: 'todas',
        mostrarConcluidas: true,
        filtroResponsavel: 'todos',
        filtroProduto: 'todos',
        filtroStatus: () => null,
        busca: '',
      ),
    );
  }

  void openOP(String numero) {
    emit(state.copyWith(selectedOP: () => numero, confirmCancel: false));
  }

  void closeOP() {
    emit(state.copyWith(selectedOP: () => null, confirmCancel: false));
  }

  Future<void> advanceOP({
    int quantidadeArmazenada = 0,
    String? operatorName,
    String? operatorPin,
  }) async {
    final op = state.selectedOP;
    if (op == null) return;
    final signer = operatorName?.trim();
    emit(
      state.copyWith(
        databaseSyncing: true,
        databaseSyncMessage:
            'Atualizando banco Protheus e VettiFlow. Enviando OP para a proxima etapa'
            '${signer == null || signer.isEmpty ? '' : ' com assinatura de $signer'}.',
      ),
    );
    try {
      await _repository.avancarStatus(
        op,
        quantidadeArmazenada: quantidadeArmazenada,
        operatorName: operatorName,
        operatorPin: operatorPin,
      );
      final ordens = await _repository.fetchOrdens();
      final armazenadas = await _repository.fetchOrdensArmazenadas();
      final produtos = await _repository.fetchProdutos();
      emit(
        state.copyWith(
          ordens: ordens,
          armazenadas: armazenadas,
          produtos: produtos,
          databaseSyncing: false,
          databaseSyncMessage: '',
        ),
      );
    } catch (_) {
      emit(state.copyWith(databaseSyncing: false, databaseSyncMessage: ''));
      rethrow;
    }
  }

  Future<void> regressOP() async {
    final op = state.selectedOP;
    if (op == null) return;
    await _repository.voltarStatus(op);
    final ordens = await _repository.fetchOrdens();
    final armazenadas = await _repository.fetchOrdensArmazenadas();
    final produtos = await _repository.fetchProdutos();
    emit(
      state.copyWith(
        ordens: ordens,
        armazenadas: armazenadas,
        produtos: produtos,
      ),
    );
  }

  Future<void> updateRoute(List<ProductionStage> stages) async {
    final op = state.selectedOP;
    if (op == null) return;
    emit(
      state.copyWith(
        databaseSyncing: true,
        databaseSyncMessage: 'Salvando sequencia da OP no VettiFlow.',
      ),
    );
    try {
      await _repository.atualizarRota(op, stages);
      final ordens = await _repository.fetchOrdens();
      emit(
        state.copyWith(
          ordens: ordens,
          databaseSyncing: false,
          databaseSyncMessage: '',
        ),
      );
    } catch (_) {
      emit(state.copyWith(databaseSyncing: false, databaseSyncMessage: ''));
      rethrow;
    }
  }

  void askCancel() {
    emit(state.copyWith(confirmCancel: true));
  }

  void cancelCancelation() {
    emit(state.copyWith(confirmCancel: false));
  }

  Future<void> cancelOP({
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) async {
    final op = state.selectedOP;
    if (op == null) return;
    emit(
      state.copyWith(
        databaseSyncing: true,
        databaseSyncMessage:
            'Cancelando OP e devolvendo empenhos no Protheus e VettiFlow.',
      ),
    );
    try {
      await _repository.cancelarOrdem(
        op,
        returnWarehouses: returnWarehouses,
        operatorName: operatorName,
        operatorPin: operatorPin,
      );
      final ordens = await _repository.fetchOrdens();
      final armazenadas = await _repository.fetchOrdensArmazenadas();
      final produtos = await _repository.fetchProdutos();
      emit(
        state.copyWith(
          ordens: ordens,
          armazenadas: armazenadas,
          produtos: produtos,
          selectedOP: () => null,
          confirmCancel: false,
          databaseSyncing: false,
          databaseSyncMessage: '',
        ),
      );
    } catch (_) {
      emit(state.copyWith(databaseSyncing: false, databaseSyncMessage: ''));
      rethrow;
    }
  }

  void openNovaOP() {
    emit(state.copyWith(novaOPOpen: true));
  }

  void closeNovaOP() {
    emit(state.copyWith(novaOPOpen: false));
  }

  Future<ProtheusProductLookup?> lookupProdutoPorCodigo(String code) {
    return _repository.lookupProdutoPorCodigo(code);
  }

  Future<List<ProtheusProduct>> searchProdutos(String query) {
    return _repository.searchProdutos(query);
  }

  Future<void> createOP(NovaOrdemDTO dto) async {
    emit(
      state.copyWith(
        databaseSyncing: true,
        databaseSyncMessage: 'Criando OP e pedidos de materiais no VettiFlow.',
      ),
    );
    try {
      final criada = await _repository.criarOrdem(dto);
      final envio = _repository.ultimoEnvioProtheus;
      final ordens = await _repository.fetchOrdens();
      final armazenadas = await _repository.fetchOrdensArmazenadas();
      final produtos = await _repository.fetchProdutos();
      emit(
        state.copyWith(
          ordens: ordens,
          armazenadas: armazenadas,
          produtos: produtos,
          novaOPOpen: false,
          databaseSyncing: false,
          databaseSyncMessage: '',
          protheusAviso: envio == null || envio.gravouNoProtheus
              ? ''
              : '${criada.numero}: ${envio.aviso}',
        ),
      );
    } catch (_) {
      emit(state.copyWith(databaseSyncing: false, databaseSyncMessage: ''));
      rethrow;
    }
  }

  /// Some com o aviso depois que a tela ja mostrou, para nao repetir a cada
  /// rebuild.
  void limparAvisoProtheus() {
    if (state.protheusAviso.isEmpty) return;
    emit(state.copyWith(protheusAviso: ''));
  }

  void openFiltros() {
    emit(state.copyWith(filtrosOpen: true));
  }

  void closeFiltros() {
    emit(state.copyWith(filtrosOpen: false));
  }
}
