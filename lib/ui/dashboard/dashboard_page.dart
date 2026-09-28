import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_cubit.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_state.dart';
import 'package:vetti_flow_1_0/ui/dashboard/views/cards_view.dart';
import 'package:vetti_flow_1_0/ui/dashboard/views/stored_view.dart';
import 'package:vetti_flow_1_0/ui/dashboard/views/kanban_view.dart';
import 'package:vetti_flow_1_0/ui/dashboard/views/reports_view.dart';
import 'package:vetti_flow_1_0/ui/dashboard/views/operator_assignments_view.dart';
import 'package:vetti_flow_1_0/ui/dashboard/views/table_view.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/app_header.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/filter_bar.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/kpi_cards.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/mobile_app_bar.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/mobile_bottom_nav.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/nova_op_dialog.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/op_detail_panel.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/sidebar.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/firmware_completion_dialogs.dart';
import 'package:vetti_flow_1_0/ui/protheus/fila_protheus_page.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/firmware_models.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  ProductionFlowStore? _store;

  @override
  void initState() {
    super.initState();
    context.read<DashboardCubit>().loadOrdens();
    // Mantém o dashboard em sincronia com o fluxo real: quando um operador
    // (ou a TV) muda o estado no ProductionFlowStore, recarrega as OPs.
    _store = context.read<ProductionFlowStore>()..addListener(_onStoreChanged);
  }

  void _onStoreChanged() {
    if (!mounted) return;
    context.read<DashboardCubit>().loadOrdens();
  }

  @override
  void dispose() {
    _store?.removeListener(_onStoreChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DashboardCubit, DashboardState>(
      listenWhen: (antes, agora) =>
          antes.protheusAviso != agora.protheusAviso &&
          agora.protheusAviso.isNotEmpty,
      listener: (context, state) {
        _avisarProtheusForaDoAr(context, state.protheusAviso);
        context.read<DashboardCubit>().limparAvisoProtheus();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 920;
              if (isDesktop) return _DesktopLayout(constraints: constraints);
              return _MobileLayout(constraints: constraints);
            },
          ),
        ),
      ),
    );
  }
}

/// A OP existe no VettiFlow mas nao no Protheus. Fica longo de proposito: o
/// operador precisa saber que a SC2/SD4 nao foram gravadas e que ha trabalho
/// pendente na fila, senao ele segue achando que a OP esta no ERP.
void _avisarProtheusForaDoAr(BuildContext context, String aviso) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 12),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                aviso,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Ver fila',
          textColor: Colors.white,
          onPressed: () =>
              Navigator.of(context).pushNamed(FilaProtheusPage.rota),
        ),
      ),
    );
}

class _DesktopLayout extends StatelessWidget {
  final BoxConstraints constraints;

  const _DesktopLayout({required this.constraints});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    final currentOperator = context
        .watch<OperatorAssignmentStore>()
        .currentOperator;
    final currentOperatorName = currentOperator?.name;

    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        final content = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Sidebar(viewMode: state.viewMode, onViewMode: cubit.setViewMode),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppHeader(onNovaOP: cubit.openNovaOP),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(26, 22, 26, 40),
                      children: [
                        if (state.viewMode == ViewMode.armazenadas) ...[
                          _StoredHeader(
                            resultText: state.armazenadasResultText,
                          ),
                          const SizedBox(height: 18),
                          _buildView(
                            state,
                            cubit,
                            currentOperator?.managesArea,
                          ),
                        ] else if (state.viewMode == ViewMode.relatorios) ...[
                          _buildView(
                            state,
                            cubit,
                            currentOperator?.managesArea,
                          ),
                        ] else if (state.viewMode == ViewMode.responsaveis) ...[
                          _buildView(
                            state,
                            cubit,
                            currentOperator?.managesArea,
                          ),
                        ] else ...[
                          KpiCards(
                            counts: state.kpiCounts,
                            atrasadas: state.atrasadasCount,
                            activeFilter: state.filtroStatus,
                            onToggle: cubit.toggleStatusFilter,
                          ),
                          const SizedBox(height: 18),
                          FilterBar(
                            busca: state.busca,
                            filtroPeriodo: state.filtroPeriodo,
                            filtroResponsavel: state.filtroResponsavel,
                            filtroProduto: state.filtroProduto,
                            responsaveis: state.responsaveis
                                .map((r) => r.nome)
                                .toList(),
                            produtos: state.produtos,
                            viewMode: state.viewMode,
                            hasActiveFilters: state.hasActiveFilters,
                            resultText: state.resultText,
                            onBusca: cubit.setBusca,
                            onPeriodo: cubit.setFiltroPeriodo,
                            onResponsavel: cubit.setFiltroResponsavel,
                            onProduto: cubit.setFiltroProduto,
                            onViewMode: cubit.setViewMode,
                            onLimpar: cubit.limparFiltros,
                          ),
                          const SizedBox(height: 18),
                          _buildView(
                            state,
                            cubit,
                            currentOperator?.managesArea,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        return Stack(
          children: [
            content,
            if (state.selectedOrdem != null)
              OpDetailPanel(
                op: state.selectedOrdem!,
                confirmCancel: state.confirmCancel,
                onClose: cubit.closeOP,
                onAdvance: ({int quantidadeArmazenada = 0}) =>
                    _advanceWithSignature(
                      context,
                      cubit,
                      state.selectedOrdem!,
                      quantidadeArmazenada: quantidadeArmazenada,
                    ),
                onUpdateRoute: cubit.updateRoute,
                onRegress: cubit.regressOP,
                onAskCancel: cubit.askCancel,
                onConfirmCancel: (returnWarehouses, operatorPin) =>
                    cubit.cancelOP(
                      returnWarehouses: returnWarehouses,
                      operatorName: currentOperatorName,
                      operatorPin: operatorPin,
                    ),
                onCancelNo: cubit.cancelCancelation,
                isDesktop: true,
                canEdit: _canOperatorEditOrder(
                  currentOperator,
                  state.selectedOrdem!,
                ),
                showSensitiveDetails: _canOperatorViewSensitiveDetails(
                  currentOperator,
                  state.selectedOrdem!,
                ),
                readOnlyMessage: _readOnlyMessage(
                  currentOperator,
                  state.selectedOrdem!,
                ),
              ),
            if (state.novaOPOpen)
              NovaOpDialog(
                produtos: state.produtos,
                responsaveis: state.responsaveis.map((r) => r.nome).toList(),
                onLookupProduto: cubit.lookupProdutoPorCodigo,
                onSearchProdutos: cubit.searchProdutos,
                currentOperatorName: currentOperatorName,
                onCreate: cubit.createOP,
                onClose: cubit.closeNovaOP,
                isDesktop: true,
              ),
            if (state.databaseSyncing)
              _DatabaseSyncOverlay(message: state.databaseSyncMessage),
          ],
        );
      },
    );
  }

  Widget _buildView(
    DashboardState state,
    DashboardCubit cubit,
    WorkArea? visibleArea,
  ) {
    final ordens = state.ordensFiltradas;
    switch (state.viewMode) {
      case ViewMode.kanban:
        return KanbanView(ordens: ordens, onOpenOP: cubit.openOP);
      case ViewMode.tabela:
        return TableView(ordens: ordens, onOpenOP: cubit.openOP);
      case ViewMode.cards:
        return CardsView(ordens: ordens, onOpenOP: cubit.openOP);
      case ViewMode.armazenadas:
        return StoredView(items: state.armazenadas);
      case ViewMode.responsaveis:
        return const OperatorAssignmentsView();
      case ViewMode.relatorios:
        return ReportsView(visibleArea: visibleArea);
    }
  }
}

class _MobileLayout extends StatelessWidget {
  final BoxConstraints constraints;

  const _MobileLayout({required this.constraints});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    final currentOperator = context
        .watch<OperatorAssignmentStore>()
        .currentOperator;
    final currentOperatorName = currentOperator?.name;

    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state.selectedOrdem != null) {
          return OpDetailPanel(
            op: state.selectedOrdem!,
            confirmCancel: state.confirmCancel,
            onClose: cubit.closeOP,
            onAdvance: ({int quantidadeArmazenada = 0}) =>
                _advanceWithSignature(
                  context,
                  cubit,
                  state.selectedOrdem!,
                  quantidadeArmazenada: quantidadeArmazenada,
                ),
            onUpdateRoute: cubit.updateRoute,
            onRegress: cubit.regressOP,
            onAskCancel: cubit.askCancel,
            onConfirmCancel: (returnWarehouses, operatorPin) => cubit.cancelOP(
              returnWarehouses: returnWarehouses,
              operatorName: currentOperatorName,
              operatorPin: operatorPin,
            ),
            onCancelNo: cubit.cancelCancelation,
            isDesktop: false,
            canEdit: _canOperatorEditOrder(
              currentOperator,
              state.selectedOrdem!,
            ),
            showSensitiveDetails: _canOperatorViewSensitiveDetails(
              currentOperator,
              state.selectedOrdem!,
            ),
            readOnlyMessage: _readOnlyMessage(
              currentOperator,
              state.selectedOrdem!,
            ),
          );
        }

        return Stack(
          children: [
            Column(
              children: [
                const MobileAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 92),
                    child: Column(
                      children: [
                        const SizedBox(height: 14),
                        if (state.viewMode == ViewMode.relatorios) ...[
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                            child: ReportsView(
                              visibleArea: currentOperator?.managesArea,
                            ),
                          ),
                        ] else if (state.viewMode == ViewMode.responsaveis) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                            child: OperatorAssignmentsView(),
                          ),
                        ] else if (state.viewMode != ViewMode.armazenadas) ...[
                          if (state.viewMode == ViewMode.kanban)
                            KpiCards(
                              counts: state.kpiCounts,
                              atrasadas: state.atrasadasCount,
                              activeFilter: state.filtroStatus,
                              onToggle: cubit.toggleStatusFilter,
                              compact: true,
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      border: Border.all(
                                        color: AppColors.borderField,
                                      ),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.search,
                                          size: 15,
                                          color: AppColors.muted,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            onChanged: cubit.setBusca,
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Buscar OP ou produto...',
                                              hintStyle:
                                                  GoogleFonts.ibmPlexSans(
                                                    fontSize: 14,
                                                    color: AppColors.muted,
                                                  ),
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            style: GoogleFonts.ibmPlexSans(
                                              fontSize: 14,
                                              color: AppColors.text,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                _FilterButton(
                                  hasActive:
                                      state.filtroPeriodo != 'todos' ||
                                      state.filtroResponsavel != 'todos' ||
                                      state.filtroProduto != 'todos',
                                  onTap: () =>
                                      _showFilterSheet(context, state, cubit),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  state.resultText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                                if (state.hasActiveFilters)
                                  GestureDetector(
                                    onTap: cubit.limparFiltros,
                                    child: Text(
                                      'Limpar filtros',
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                            child: Column(
                              children: [
                                if (state.ordensFiltradas.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 48,
                                    ),
                                    child: Text(
                                      'Nenhuma OP encontrada\ncom os filtros atuais.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textWeak,
                                      ),
                                    ),
                                  )
                                else
                                  ...state.ordensFiltradas.map(
                                    (op) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 11,
                                      ),
                                      child: _MobileOpCard(
                                        op: op,
                                        onTap: () => cubit.openOP(op.numero),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                            child: _StoredHeader(
                              resultText: state.armazenadasResultText,
                              compact: true,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: StoredView(items: state.armazenadas),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                MobileBottomNav(
                  viewMode: state.viewMode,
                  onViewMode: cubit.setViewMode,
                ),
              ],
            ),
            // FAB
            Positioned(
              right: 18,
              bottom: 80,
              child: FloatingActionButton(
                onPressed: cubit.openNovaOP,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 8,
                child: const Icon(Icons.add, size: 28),
              ),
            ),
            if (state.novaOPOpen)
              NovaOpDialog(
                produtos: state.produtos,
                responsaveis: state.responsaveis.map((r) => r.nome).toList(),
                onLookupProduto: cubit.lookupProdutoPorCodigo,
                onSearchProdutos: cubit.searchProdutos,
                currentOperatorName: currentOperatorName,
                onCreate: cubit.createOP,
                onClose: cubit.closeNovaOP,
                isDesktop: false,
              ),
            if (state.databaseSyncing)
              _DatabaseSyncOverlay(message: state.databaseSyncMessage),
          ],
        );
      },
    );
  }

  void _showFilterSheet(
    BuildContext context,
    DashboardState state,
    DashboardCubit cubit,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(state: state, cubit: cubit),
    );
  }
}

Future<void> _advanceWithSignature(
  BuildContext context,
  DashboardCubit cubit,
  OrdemProducao order, {
  int quantidadeArmazenada = 0,
}) async {
  final signature = await showFirmwarePinDialog(
    context,
    FirmwareOperation(
      number: order.numero,
      product: order.produto,
      quantity: order.qtdLabel,
      origin: order.stage.label,
      receivedAt: order.dataAbertura,
      receivedAgo: 'Movimentacao pela dashboard',
    ),
    currentStage: _workStageFor(order.stage),
    isOperatorAllowed: (operator) => _canOperatorEditOrder(operator, order),
  );
  if (signature == null) return;
  try {
    await cubit.advanceOP(
      quantidadeArmazenada: quantidadeArmazenada,
      operatorName: signature.name,
      operatorPin: signature.pin,
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não consegui atualizar o banco agora. Tente novamente.'),
      ),
    );
  }
}

WorkStage _workStageFor(ProductionStage stage) {
  return switch (stage) {
    ProductionStage.warehouse => WorkStage.warehouse,
    ProductionStage.smd => WorkStage.smd,
    ProductionStage.firmware => WorkStage.firmware,
    ProductionStage.soldering => WorkStage.soldering,
    ProductionStage.testing => WorkStage.testing,
    ProductionStage.closing => WorkStage.closing,
    ProductionStage.expedition ||
    ProductionStage.storage ||
    ProductionStage.completed => WorkStage.expedition,
  };
}

class _DatabaseSyncOverlay extends StatelessWidget {
  const _DatabaseSyncOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.48),
        child: Center(
          child: Container(
            width: 380,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x330F172A),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Atualizando bancos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message.isEmpty
                      ? 'Atualizando banco Protheus e VettiFlow.'
                      : message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _canOperatorEditOrder(Operator? operator, OrdemProducao order) {
  if (operator == null) return true;
  if (operator.managesArea == null && operator.canManageAssignments) {
    return true;
  }
  final stage = order.stage;
  final username = operator.username.trim().toLowerCase();
  return switch (username) {
    'tatiane' || 'andressa' => _productionDashboardStages.contains(stage),
    'vera' => stage == ProductionStage.warehouse,
    'paula' => stage == ProductionStage.smd,
    'bruna' || 'tamara' => stage == ProductionStage.expedition,
    _ => false,
  };
}

bool _canOperatorViewSensitiveDetails(Operator? operator, OrdemProducao order) {
  if (operator == null) return true;
  if (operator.managesArea == null && operator.canManageAssignments) {
    return true;
  }
  final managedArea = operator.managesArea;
  if (managedArea == null) return false;
  return _areaForStage(order.stage) == managedArea;
}

WorkArea _areaForStage(ProductionStage stage) {
  return switch (stage) {
    ProductionStage.warehouse => WorkArea.warehouse,
    ProductionStage.smd => WorkArea.smd,
    ProductionStage.firmware ||
    ProductionStage.soldering ||
    ProductionStage.testing ||
    ProductionStage.closing ||
    ProductionStage.expedition ||
    ProductionStage.storage ||
    ProductionStage.completed => WorkArea.production,
  };
}

String _readOnlyMessage(Operator? operator, OrdemProducao order) {
  final name = operator?.name ?? 'Este usuário';
  return '$name pode acompanhar esta OP em ${order.stage.label}, mas não pode movimentar esta etapa.';
}

const _productionDashboardStages = {
  ProductionStage.firmware,
  ProductionStage.soldering,
  ProductionStage.testing,
  ProductionStage.closing,
  ProductionStage.expedition,
};

class _StoredHeader extends StatelessWidget {
  const _StoredHeader({required this.resultText, this.compact = false});

  final String resultText;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 18,
        vertical: compact ? 15 : 17,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.bgAndamento,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OPs armazenadas',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  resultText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileOpCard extends StatelessWidget {
  final OrdemProducao op;
  final VoidCallback onTap;

  const _MobileOpCard({required this.op, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final resp = Responsavel.byNome(op.responsavel);
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border),
                right: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
                left: BorderSide(color: op.status.dot, width: 3),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        op.numero,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textCode,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 118),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: op.status.bgColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: op.status.dot,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              op.status.shortLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: op.status.textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  op.produto,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textStrong,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (resp != null) ...[
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: resp.cor,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                resp.iniciais,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              op.responsavel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      op.qtdLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
                if (op.showBar) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.bgProgress,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (op.progresso / 100).clamp(0, 1),
                            child: Container(
                              decoration: BoxDecoration(
                                color: op.status.barColor,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        op.percentLabel,
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 9),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.borderLight),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Abertura ${op.dataAbertura}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textWeak,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                op.prazoLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: op.atrasada
                                      ? AppColors.danger
                                      : AppColors.textMuted,
                                  fontWeight: op.atrasada
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (op.atrasada) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerBg,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: const Text(
                                  'Atrasada',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final bool hasActive;
  final VoidCallback onTap;

  const _FilterButton({required this.hasActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderField),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.tune_rounded,
                size: 18,
                color: AppColors.textCode,
              ),
              if (hasActive)
                Positioned(
                  top: 7,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final DashboardState state;
  final DashboardCubit cubit;

  const _FilterSheet({required this.state, required this.cubit});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _periodo;
  late String _responsavel;
  late String _produto;

  @override
  void initState() {
    super.initState();
    _periodo = widget.state.filtroPeriodo;
    _responsavel = widget.state.filtroResponsavel;
    _produto = widget.state.filtroProduto;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filtros',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: AppColors.bgButton,
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => Navigator.pop(context),
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: Center(
                            child: Text(
                              '×',
                              style: TextStyle(
                                fontSize: 19,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    _SheetDropdown(
                      label: 'Período',
                      value: _periodo,
                      items: const {
                        'todos': 'Todos os períodos',
                        'jun': 'Junho 2026',
                        'mai': 'Maio 2026',
                      },
                      onChanged: (v) => setState(() => _periodo = v),
                    ),
                    const SizedBox(height: 15),
                    _SheetDropdown(
                      label: 'Responsável',
                      value: _responsavel,
                      items: {
                        'todos': 'Todos os responsáveis',
                        for (final r in widget.state.responsaveis)
                          r.nome: r.nome,
                      },
                      onChanged: (v) => setState(() => _responsavel = v),
                    ),
                    const SizedBox(height: 15),
                    _SheetDropdown(
                      label: 'Produto',
                      value: _produto,
                      items: {
                        'todos': 'Todos os produtos',
                        for (final p in widget.state.produtos) p: p,
                      },
                      onChanged: (v) => setState(() => _produto = v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: [
                    SizedBox(
                      width: 116,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.cubit.limparFiltros();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.bgButton,
                          foregroundColor: AppColors.textCode,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                          textStyle: GoogleFonts.ibmPlexSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text(
                          'Limpar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.cubit.setFiltroPeriodo(_periodo);
                          widget.cubit.setFiltroResponsavel(_responsavel);
                          widget.cubit.setFiltroProduto(_produto);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                          textStyle: GoogleFonts.ibmPlexSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text(
                          'Aplicar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetDropdown extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _SheetDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textCode,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: Color(0xFFDFE3E9)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: Color(0xFFDFE3E9)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
          style: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            color: AppColors.textStrong,
          ),
          selectedItemBuilder: (context) => items.entries
              .map(
                (e) =>
                    Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
              )
              .toList(),
          items: items.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    e.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
