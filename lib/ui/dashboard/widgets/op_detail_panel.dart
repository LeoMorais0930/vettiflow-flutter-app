import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/protheus_completion_preview.dart';
import 'package:vetti_flow_1_0/data/models/protheus_op_movements.dart';
import 'package:vetti_flow_1_0/data/models/protheus_transfers.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_completion_preview_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_op_movement_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_transfer_repository.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';
import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class OpDetailPanel extends StatelessWidget {
  final OrdemProducao op;
  final bool confirmCancel;
  final VoidCallback onClose;
  final void Function({int quantidadeArmazenada}) onAdvance;
  final Future<void> Function(List<ProductionStage> stages)? onUpdateRoute;
  final VoidCallback onRegress;
  final VoidCallback onAskCancel;
  final void Function(Map<String, String> returnWarehouses, String operatorPin)
  onConfirmCancel;
  final VoidCallback onCancelNo;
  final bool isDesktop;
  final bool canEdit;
  final bool showSensitiveDetails;
  final String readOnlyMessage;

  const OpDetailPanel({
    super.key,
    required this.op,
    required this.confirmCancel,
    required this.onClose,
    required this.onAdvance,
    this.onUpdateRoute,
    required this.onRegress,
    required this.onAskCancel,
    required this.onConfirmCancel,
    required this.onCancelNo,
    this.isDesktop = true,
    this.canEdit = true,
    this.showSensitiveDetails = true,
    this.readOnlyMessage =
        'Você pode acompanhar esta OP, mas não pode movimentar esta etapa.',
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) return _DesktopDrawer(panel: this);
    return _MobileFullScreen(panel: this);
  }
}

class _DesktopDrawer extends StatelessWidget {
  final OpDetailPanel panel;

  const _DesktopDrawer({required this.panel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: panel.onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.42),
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 500,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x330F172A),
                    blurRadius: 36,
                    offset: Offset(-10, 0),
                  ),
                ],
              ),
              child: _DetailContent(panel: panel, showBackArrow: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileFullScreen extends StatelessWidget {
  final OpDetailPanel panel;

  const _MobileFullScreen({required this.panel});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: _DetailContent(panel: panel, showBackArrow: true),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final OpDetailPanel panel;
  final bool showBackArrow;

  const _DetailContent({required this.panel, required this.showBackArrow});

  OrdemProducao get op => panel.op;

  @override
  Widget build(BuildContext context) {
    final resp = Responsavel.byNome(op.responsavel);
    final isDone = op.status == StatusOP.finalizada;
    final canAdvance = !isDone;
    final canRegress = op.stage != ProductionStage.warehouse;

    final flow = ProductionStage.productionFlow;
    final stageIdx = flow.indexOf(op.stage);
    final advanceLabel = stageIdx == -1
        ? 'Finalizar OP'
        : stageIdx == flow.length - 1
        ? 'Concluir e expedir'
        : 'Avançar p/ ${flow[stageIdx + 1].label}';

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.borderLight)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showBackArrow) ...[
                    _IconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: panel.onClose,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      op.numero,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (!showBackArrow)
                    _IconButton(icon: Icons.close, onTap: panel.onClose)
                  else
                    _StatusBadge(status: op.status),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                op.produto,
                maxLines: showBackArrow ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 11),
              if (!showBackArrow)
                Row(
                  children: [
                    _StatusBadge(status: op.status),
                    if (op.prioridadeAlta) ...[
                      const SizedBox(width: 9),
                      const _PriorityBadge(),
                    ],
                    if (op.atrasada) ...[
                      const SizedBox(width: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'Atrasada',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              if (showBackArrow && (op.prioridadeAlta || op.atrasada))
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (op.prioridadeAlta) const _PriorityBadge(),
                      if (op.atrasada)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBg,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'Atrasada',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Scrollable content
        Expanded(
          child: panel.confirmCancel
              ? SingleChildScrollView(
                  padding: EdgeInsets.all(showBackArrow ? 16 : 20),
                  child: _CancelConfirm(
                    op: op,
                    onConfirm: panel.onConfirmCancel,
                    onBack: panel.onCancelNo,
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(showBackArrow ? 16 : 20),
                  child: Column(
                    children: [
                      _InfoCard(op: op, resp: resp),
                      SizedBox(height: showBackArrow ? 18 : 24),
                      _RoutingCard(op: op),
                      SizedBox(height: showBackArrow ? 18 : 24),
                      _OfficialMovementsCard(op: op),
                      SizedBox(height: showBackArrow ? 18 : 24),
                      _CompletionPreviewCard(op: op),
                      SizedBox(height: showBackArrow ? 18 : 24),
                      _OfficialTransfersCard(op: op),
                      SizedBox(height: showBackArrow ? 18 : 24),
                      _StagesCard(
                        op: op,
                        canEdit: panel.canEdit,
                        onUpdateRoute: panel.onUpdateRoute,
                      ),
                      SizedBox(height: showBackArrow ? 18 : 24),
                      _SignatureAuditCard(op: op),
                      SizedBox(height: showBackArrow ? 18 : 24),
                      if (panel.showSensitiveDetails) ...[
                        _MaterialsCard(op: op),
                        SizedBox(height: showBackArrow ? 18 : 24),
                        _PausasTempoCard(op: op),
                      ] else
                        const _RestrictedDetailsCard(),
                    ],
                  ),
                ),
        ),

        // Actions
        if (!panel.confirmCancel)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: showBackArrow ? 16 : 22,
              vertical: showBackArrow ? 13 : 14,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            child: !panel.canEdit
                ? _ReadOnlyActions(
                    message: panel.readOnlyMessage,
                    onClose: panel.onClose,
                    isDesktop: !showBackArrow,
                  )
                : _ActionButtons(
                    canAdvance: canAdvance,
                    isDone: isDone,
                    canRegress: canRegress,
                    actionLabel: advanceLabel,
                    op: op,
                    onAdvance: panel.onAdvance,
                    onRegress: panel.onRegress,
                    onAskCancel: panel.onAskCancel,
                    onClose: panel.onClose,
                    isDesktop: !showBackArrow,
                  ),
          ),
      ],
    );
  }
}

class _OfficialMovementsCard extends StatefulWidget {
  const _OfficialMovementsCard({required this.op});

  final OrdemProducao op;

  @override
  State<_OfficialMovementsCard> createState() => _OfficialMovementsCardState();
}

class _OfficialMovementsCardState extends State<_OfficialMovementsCard> {
  Future<ProtheusOpSnapshot>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context.read<ProtheusOpMovementRepository?>()?.fetchSnapshot(
      widget.op.numero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<ProtheusOpSnapshot>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _SectionLabel('MOVIMENTOS OFICIAIS PROTHEUS'),
                  ),
                  _AuditChip(label: 'Somente leitura'),
                ],
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState != ConnectionState.done)
                const Text(
                  'Consultando SC2, SD4 e SD3...',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                )
              else if (snapshot.hasError)
                Text(
                  'Nao foi possivel ler movimentos oficiais: ${snapshot.error}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.danger,
                  ),
                )
              else if (data == null || data.movimentos.isEmpty)
                Text(
                  data == null
                      ? 'Sem retorno oficial do Protheus.'
                      : 'Sem movimentos SD3 oficiais para esta OP. Status oficial: ${data.statusLabel}.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                  ),
                )
              else ...[
                Text(
                  'Status oficial: ${data.statusLabel}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textStrong,
                  ),
                ),
                const SizedBox(height: 6),
                _OfficialTotals(snapshot: data),
                if (_localDivergence(data) != null) ...[
                  const SizedBox(height: 8),
                  _OfficialWarning(text: _localDivergence(data)!),
                ],
                if (_finishedGoodsDivergence(data) != null) ...[
                  const SizedBox(height: 8),
                  _OfficialWarning(text: _finishedGoodsDivergence(data)!),
                ],
                for (final warning in data.divergencias) ...[
                  const SizedBox(height: 8),
                  _OfficialWarning(text: warning),
                ],
                const SizedBox(height: 10),
                for (var i = 0; i < data.movimentos.length; i++) ...[
                  _OfficialMovementRow(movement: data.movimentos[i]),
                  if (i < data.movimentos.length - 1)
                    const Divider(height: 18, color: AppColors.borderLight),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  String? _localDivergence(ProtheusOpSnapshot snapshot) {
    final localVetti = widget.op.armazem.trim();
    final localProtheus = snapshot.ordem?.local.trim() ?? '';
    if (localVetti.isEmpty || localProtheus.isEmpty) return null;
    if (localVetti == localProtheus) return null;
    return 'Local VettiFlow $localVetti difere do local oficial SC2 $localProtheus.';
  }

  String? _finishedGoodsDivergence(ProtheusOpSnapshot snapshot) {
    final localSugerido = widget.op.localEntradaAcabado.trim();
    if (localSugerido.isEmpty) return null;
    var localOficial = '';
    for (final movement in snapshot.movimentos) {
      if (movement.cf == 'PR0' && !movement.estorno) {
        localOficial = movement.local.trim();
        break;
      }
    }
    if (localOficial.isEmpty) return null;
    if (WarehouseRouting.normalizeCode(localSugerido) ==
        WarehouseRouting.normalizeCode(localOficial)) {
      return null;
    }
    return 'Entrada do acabado sugerida ${WarehouseRouting.normalizeCode(localSugerido)} difere do PR0 oficial ${WarehouseRouting.normalizeCode(localOficial)}.';
  }
}

class _RoutingCard extends StatelessWidget {
  const _RoutingCard({required this.op});

  final OrdemProducao op;

  @override
  Widget build(BuildContext context) {
    final orderWarehouse = _warehouseOrDash(op.armazem);
    final consumptionWarehouse = _warehouseOrDash(op.localConsumoComponentes);
    final finishedWarehouse = _warehouseOrDash(op.localEntradaAcabado);
    final blocked = op.localEntradaAcabado.trim().isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionLabel('ROTEAMENTO DE LOCAIS')),
              _AuditChip(label: blocked ? 'Bloqueia conclusao' : 'Validado'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              _AuditChip(label: 'OP $orderWarehouse'),
              _AuditChip(label: 'Consumo $consumptionWarehouse'),
              _AuditChip(label: 'Acabado $finishedWarehouse'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            blocked
                ? 'Destino do acabado incerto. A expedição local fica bloqueada ate comparar com o historico Protheus.'
                : _routingSummary(op),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: blocked ? AppColors.danger : AppColors.textStrong,
            ),
          ),
          for (final warning in op.roteamentoAvisos) ...[
            const SizedBox(height: 8),
            _OfficialWarning(text: warning),
          ],
        ],
      ),
    );
  }

  static String _warehouseOrDash(String value) {
    final code = value.trim();
    if (code.isEmpty) return '—';
    return WarehouseRouting.normalizeCode(code);
  }

  static String _routingSummary(OrdemProducao op) {
    final orderWarehouse = WarehouseRouting.normalizeCode(op.armazem);
    final finishedWarehouse = WarehouseRouting.normalizeCode(
      op.localEntradaAcabado,
    );
    if (orderWarehouse == '05' && finishedWarehouse == '10') {
      return 'Regra historica 05 -> 10: OP e consumo ficam na producao; entrada do acabado vai para expedicao.';
    }
    if (orderWarehouse == finishedWarehouse) {
      return 'Entrada do acabado no mesmo local da OP.';
    }
    return 'Entrada do acabado em local diferente da OP conforme historico mapeado.';
  }
}

class _CompletionPreviewCard extends StatefulWidget {
  const _CompletionPreviewCard({required this.op});

  final OrdemProducao op;

  @override
  State<_CompletionPreviewCard> createState() => _CompletionPreviewCardState();
}

class _CompletionPreviewCardState extends State<_CompletionPreviewCard> {
  Future<ProtheusCompletionPreviewSnapshot>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context
        .read<ProtheusCompletionPreviewRepository?>()
        ?.fetchPreview(widget.op.numero, quantidade: widget.op.qtd);
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<ProtheusCompletionPreviewSnapshot>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _SectionLabel('PREVIA DE APONTAMENTO PROTHEUS'),
                  ),
                  _AuditChip(label: 'Somente leitura'),
                ],
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState != ConnectionState.done)
                const Text(
                  'Simulando PR0 e RE1...',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                )
              else if (snapshot.hasError)
                Text(
                  'Nao foi possivel simular apontamento: ${snapshot.error}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.danger,
                  ),
                )
              else if (data == null || data.movimentosPrevistos.isEmpty)
                const Text(
                  'Sem dados oficiais suficientes para simular apontamento.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                )
              else ...[
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    _AuditChip(label: 'Qtd ${_qty(data.quantidadeSolicitada)}'),
                    _AuditChip(
                      label: 'Restante ${_qty(data.quantidadeRestante)}',
                    ),
                    _AuditChip(label: data.rotinaStatus),
                  ],
                ),
                const SizedBox(height: 10),
                for (final movement in data.movimentosPrevistos) ...[
                  _CompletionPreviewMovementRow(movement: movement),
                  const SizedBox(height: 8),
                ],
                for (final balance in data.saldosComponentes) ...[
                  _CompletionBalanceRow(balance: balance),
                  const SizedBox(height: 8),
                ],
                for (final warning in data.divergencias) ...[
                  _OfficialWarning(text: warning),
                  const SizedBox(height: 8),
                ],
                for (final pending in data.pendenciasPesquisa) ...[
                  _OfficialWarning(text: pending),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CompletionPreviewMovementRow extends StatelessWidget {
  const _CompletionPreviewMovementRow({required this.movement});

  final ProtheusCompletionMovementPreview movement;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            movement.label,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${movement.kindLabel} · ${movement.produto}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textStrong,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 7,
                runSpacing: 5,
                children: [
                  _AuditChip(label: '${_qty(movement.quantidade)} un'),
                  _AuditChip(label: 'Local ${movement.local}'),
                  if (movement.documentoReferencia.isNotEmpty)
                    _AuditChip(label: 'Doc ${movement.documentoReferencia}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompletionBalanceRow extends StatelessWidget {
  const _CompletionBalanceRow({required this.balance});

  final ProtheusCompletionComponentBalance balance;

  @override
  Widget build(BuildContext context) {
    final color = balance.suficiente ? AppColors.green : AppColors.orangeText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        'Saldo ${balance.produto} local ${balance.local}: ${_qty(balance.saldoAtual)} disponivel / ${_qty(balance.quantidadePrevista)} previsto',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _OfficialTransfersCard extends StatefulWidget {
  const _OfficialTransfersCard({required this.op});

  final OrdemProducao op;

  @override
  State<_OfficialTransfersCard> createState() => _OfficialTransfersCardState();
}

class _OfficialTransfersCardState extends State<_OfficialTransfersCard> {
  Future<ProtheusTransferSnapshot>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context.read<ProtheusTransferRepository?>()?.fetchTransfers(
      produto: _productCode(widget.op.produto),
      limit: 8,
    );
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<ProtheusTransferSnapshot>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _SectionLabel('TRANSFERENCIAS OFICIAIS PROTHEUS'),
                  ),
                  _AuditChip(label: 'Somente leitura'),
                ],
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState != ConnectionState.done)
                const Text(
                  'Consultando RE4 e DE4...',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                )
              else if (snapshot.hasError)
                Text(
                  'Nao foi possivel ler transferencias oficiais: ${snapshot.error}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.danger,
                  ),
                )
              else if (data == null || data.transferencias.isEmpty)
                const Text(
                  'Sem transferencias oficiais RE4/DE4 para este produto.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                )
              else ...[
                for (final warning in data.divergencias) ...[
                  _OfficialWarning(text: warning),
                  const SizedBox(height: 8),
                ],
                for (var i = 0; i < data.transferencias.length; i++) ...[
                  _OfficialTransferRow(transfer: data.transferencias[i]),
                  if (i < data.transferencias.length - 1)
                    const Divider(height: 18, color: AppColors.borderLight),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  static String _productCode(String produto) {
    return produto.split(' - ').first.trim();
  }
}

class _OfficialTransferRow extends StatelessWidget {
  const _OfficialTransferRow({required this.transfer});

  final ProtheusTransfer transfer;

  @override
  Widget build(BuildContext context) {
    final incomplete = transfer.status != 'pareada';
    final color = incomplete ? AppColors.orangeText : AppColors.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            transfer.routeLabel,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${transfer.produto} · ${transfer.statusLabel}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textStrong,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 7,
                runSpacing: 5,
                children: [
                  _AuditChip(label: '${_qty(transfer.quantidade)} un'),
                  if (transfer.documento.isNotEmpty)
                    _AuditChip(label: 'Doc ${transfer.documento}'),
                  if (transfer.data.isNotEmpty)
                    _AuditChip(label: transfer.data),
                  for (final movement in transfer.movimentos)
                    _AuditChip(label: movement.label),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfficialTotals extends StatelessWidget {
  const _OfficialTotals({required this.snapshot});

  final ProtheusOpSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ordem = snapshot.ordem;
    return Wrap(
      spacing: 7,
      runSpacing: 6,
      children: [
        if (ordem != null) _AuditChip(label: 'SC2 local ${ordem.local}'),
        _AuditChip(label: 'PR0 ${_qty(snapshot.totalProduzido)}'),
        _AuditChip(label: 'RE1 ${_qty(snapshot.totalConsumido)}'),
        if (snapshot.hasReversal) _AuditChip(label: 'Estorno detectado'),
        _AuditChip(label: '${snapshot.empenhos.length} empenho(s) SD4'),
      ],
    );
  }
}

class _OfficialWarning extends StatelessWidget {
  const _OfficialWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgHeader,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          height: 1.3,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _OfficialMovementRow extends StatelessWidget {
  const _OfficialMovementRow({required this.movement});

  final ProtheusOpMovement movement;

  @override
  Widget build(BuildContext context) {
    final color = movement.estorno ? AppColors.danger : AppColors.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            movement.label,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${movement.kindLabel} · ${movement.produto}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textStrong,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 7,
                runSpacing: 5,
                children: [
                  _AuditChip(label: '${_qty(movement.quantidade)} un'),
                  _AuditChip(label: 'Local ${movement.local}'),
                  if (movement.documento.isNotEmpty)
                    _AuditChip(label: 'Doc ${movement.documento}'),
                  if (movement.numSeq.isNotEmpty)
                    _AuditChip(label: 'Seq ${movement.numSeq}'),
                  if (movement.perda != 0)
                    _AuditChip(label: 'Perda ${_qty(movement.perda)}'),
                  if (movement.ganho != 0)
                    _AuditChip(label: 'Ganho ${_qty(movement.ganho)}'),
                  if (movement.estorno) const _AuditChip(label: 'Estorno'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _qty(num value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

class _InfoCard extends StatelessWidget {
  final OrdemProducao op;
  final Responsavel? resp;

  const _InfoCard({required this.op, required this.resp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _InfoField(
                  label: 'RESPONSÁVEL',
                  child: Row(
                    children: [
                      if (resp != null) ...[
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: resp!.cor,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            resp!.iniciais,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        op.responsavel,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _InfoField(label: 'QUANTIDADE', text: op.qtdLabel),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _InfoField(label: 'ABERTURA', text: op.dataAbertura),
              ),
              Expanded(
                child: _InfoField(
                  label: 'PRAZO',
                  child: Text(
                    op.prazo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: op.atrasada
                          ? AppColors.danger
                          : AppColors.textStrong,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionLabel('PROGRESSO'),
              Text(
                op.percentLabel,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textCode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: op.progresso / 100,
              minHeight: 8,
              backgroundColor: AppColors.bgProgress,
              valueColor: AlwaysStoppedAnimation(op.status.barColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _StagesCard extends StatelessWidget {
  final OrdemProducao op;
  final bool canEdit;
  final Future<void> Function(List<ProductionStage> stages)? onUpdateRoute;

  const _StagesCard({
    required this.op,
    required this.canEdit,
    required this.onUpdateRoute,
  });

  @override
  Widget build(BuildContext context) {
    const flow = ProductionStage.productionFlow;
    final route = op.plannedStages.isEmpty
        ? flow.toList()
        : op.plannedStages.where(flow.contains).toList();
    final skipped = flow.where((stage) => !route.contains(stage)).toList();
    final finalizada = op.status == StatusOP.finalizada;
    final currentRouteIndex = route.indexOf(op.stage);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _SectionLabel('ETAPAS DE PRODUÇÃO')),
              if (canEdit && onUpdateRoute != null && !finalizada)
                TextButton.icon(
                  onPressed: () async {
                    final stages = await showDialog<List<ProductionStage>>(
                      context: context,
                      builder: (context) => _RouteEditorDialog(op: op),
                    );
                    if (stages == null) return;
                    await onUpdateRoute!(stages);
                  },
                  icon: const Icon(Icons.alt_route_rounded, size: 17),
                  label: const Text('Editar sequência'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < route.length; i++)
            _StageRouteRow(
              stage: route[i],
              index: i,
              currentIndex: currentRouteIndex,
              finalizada: finalizada,
              status: op.status,
            ),
          if (skipped.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Fora da sequência',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            for (final stage in skipped) _SkippedStageRow(stage: stage),
          ],
        ],
      ),
    );
  }
}

class _StageRouteRow extends StatelessWidget {
  const _StageRouteRow({
    required this.stage,
    required this.index,
    required this.currentIndex,
    required this.finalizada,
    required this.status,
  });

  final ProductionStage stage;
  final int index;
  final int currentIndex;
  final bool finalizada;
  final StatusOP status;

  @override
  Widget build(BuildContext context) {
    final isOk = finalizada || (currentIndex != -1 && index < currentIndex);
    final isRunning =
        !finalizada && currentIndex != -1 && index == currentIndex;
    final isNext =
        !finalizada && currentIndex != -1 && index == currentIndex + 1;

    final Color bg, color, textColor;
    final String mark, statusLabel;

    if (isOk) {
      bg = AppColors.bgFinalizada;
      color = AppColors.statusFinalizada;
      textColor = AppColors.textCode;
      mark = '✓';
      statusLabel = 'Concluída';
    } else if (isRunning) {
      bg = AppColors.bgAndamento;
      color = AppColors.statusAndamento;
      textColor = AppColors.textStrong;
      mark = '●';
      statusLabel = status == StatusOP.emAndamento ? 'Atual' : 'Aguardando';
    } else {
      bg = AppColors.bgButton;
      color = isNext ? AppColors.primary : AppColors.muted;
      textColor = isNext ? AppColors.textStrong : AppColors.muted;
      mark = '${index + 1}';
      statusLabel = isNext ? 'Próxima' : 'Pendente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.background)),
      ),
      child: Row(
        children: [
          Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              mark,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stage.label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkippedStageRow extends StatelessWidget {
  const _SkippedStageRow({required this.stage});

  final ProductionStage stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 23,
            height: 23,
            decoration: const BoxDecoration(
              color: AppColors.bgButton,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              '-',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stage.label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ),
          const Text(
            'Pulada',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialsCard extends StatelessWidget {
  final OrdemProducao op;

  const _MaterialsCard({required this.op});

  @override
  Widget build(BuildContext context) {
    final mats = op.materiais.isNotEmpty
        ? op.materiais
        : const [('Componentes diversos', 1)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('MATERIAIS (BOM)'),
          const SizedBox(height: 6),
          ...mats.map((m) {
            final nome = m.$1;
            final qtdPer = m.$2;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.background)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${qtdPer * op.qtd} un',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SignatureAuditCard extends StatelessWidget {
  const _SignatureAuditCard({required this.op});

  final OrdemProducao op;

  @override
  Widget build(BuildContext context) {
    final items = op.assinaturas;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('ASSINATURAS E MOVIMENTAÇÕES'),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text(
              'Nenhuma assinatura registrada para esta OP.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              _SignatureAuditRow(item: items[i]),
              if (i < items.length - 1)
                const Divider(height: 18, color: AppColors.borderLight),
            ],
        ],
      ),
    );
  }
}

class _SignatureAuditRow extends StatelessWidget {
  const _SignatureAuditRow({required this.item});

  final ResumoAssinaturaOp item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.bgAndamento,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            size: 17,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    item.tipo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textStrong,
                    ),
                  ),
                  _AuditChip(label: item.etapa),
                  _AuditChip(label: 'PIN ${item.pin}'),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.detalhe,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.quando} · ${item.operador}',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textCode,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuditChip extends StatelessWidget {
  const _AuditChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgHeader,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _RestrictedDetailsCard extends StatelessWidget {
  const _RestrictedDetailsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgHeader,
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 19, color: AppColors.muted),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tempo, pausas e materiais detalhados ficam visíveis apenas para o gestor do setor responsável por esta etapa.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteEditorDialog extends StatefulWidget {
  const _RouteEditorDialog({required this.op});

  final OrdemProducao op;

  @override
  State<_RouteEditorDialog> createState() => _RouteEditorDialogState();
}

class _RouteEditorDialogState extends State<_RouteEditorDialog> {
  late final List<ProductionStage> _route;

  @override
  void initState() {
    super.initState();
    final current = widget.op.stage;
    final defaultRoute = ProductionStage.productionFlow
        .where((stage) => stage.progressIndex >= current.progressIndex)
        .toList();
    final savedRoute = widget.op.plannedStages
        .where(ProductionStage.productionFlow.contains)
        .toList();
    _route = savedRoute.isEmpty ? [...defaultRoute] : [...savedRoute];
    if (ProductionStage.productionFlow.contains(current)) {
      _route.remove(current);
      _route.insert(0, current);
    }
  }

  List<ProductionStage> get _editableStages {
    return ProductionStage.productionFlow.toList();
  }

  List<ProductionStage> get _visibleStages => [
    ..._route,
    for (final stage in _editableStages)
      if (!_route.contains(stage)) stage,
  ];

  void _toggle(ProductionStage stage, bool selected) {
    if (stage == widget.op.stage) return;
    setState(() {
      if (selected) {
        if (!_route.contains(stage)) _route.add(stage);
      } else {
        _route.remove(stage);
      }
    });
  }

  void _move(ProductionStage stage, int delta) {
    final index = _route.indexOf(stage);
    if (index <= 0) return;
    final next = index + delta;
    if (next <= 0 || next >= _route.length) return;
    setState(() {
      final moved = _route.removeAt(index);
      _route.insert(next, moved);
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.op.stage;

    return AlertDialog(
      title: const Text('Sequência da OP'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.op.numero,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Marque as etapas e use as setas para definir a ordem.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              for (final stage in _visibleStages)
                _RouteStageTile(
                  stage: stage,
                  selected: _route.contains(stage),
                  requiredStage: stage == current,
                  position: _route.contains(stage)
                      ? _route.indexOf(stage) + 1
                      : 0,
                  canMoveUp: _route.indexOf(stage) > 1,
                  canMoveDown:
                      _route.contains(stage) &&
                      _route.indexOf(stage) > 0 &&
                      _route.indexOf(stage) < _route.length - 1,
                  onSelected: (value) => _toggle(stage, value),
                  onMoveUp: () => _move(stage, -1),
                  onMoveDown: () => _move(stage, 1),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop([..._route]);
          },
          icon: const Icon(Icons.save_rounded, size: 18),
          label: const Text('Salvar sequência'),
        ),
      ],
    );
  }
}

class _RouteStageTile extends StatelessWidget {
  const _RouteStageTile({
    required this.stage,
    required this.selected,
    required this.requiredStage,
    required this.position,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onSelected,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final ProductionStage stage;
  final bool selected;
  final bool requiredStage;
  final int position;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<bool> onSelected;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF8FBFD) : Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: selected ? const Color(0xFFD8E6EE) : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: requiredStage
                ? null
                : (value) => onSelected(value ?? false),
          ),
          SizedBox(
            width: 28,
            child: Text(
              selected ? '$position' : '-',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage.label,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (requiredStage)
                  const Text(
                    'Etapa atual obrigatória',
                    style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Subir',
            onPressed: canMoveUp ? onMoveUp : null,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
          IconButton(
            tooltip: 'Descer',
            onPressed: canMoveDown ? onMoveDown : null,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ],
      ),
    );
  }
}

class _PausasTempoCard extends StatelessWidget {
  final OrdemProducao op;

  const _PausasTempoCard({required this.op});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('TEMPO E PAUSAS'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TempoChip(label: 'Tempo total', value: op.tempoTotal),
              _TempoChip(label: 'Tempo da etapa', value: op.tempoEtapaAtual),
            ],
          ),
          if (op.observacao != null && op.observacao!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Observação: ${op.observacao}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (op.pausas.isEmpty)
            const Text(
              'Nenhuma pausa registrada.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            )
          else
            for (final pausa in op.pausas) ...[
              _PausaRow(pausa: pausa),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _TempoChip extends StatelessWidget {
  const _TempoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgButton,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.ibmPlexMono(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textCode,
        ),
      ),
    );
  }
}

class _PausaRow extends StatelessWidget {
  const _PausaRow({required this.pausa});

  final ResumoPausaOp pausa;

  @override
  Widget build(BuildContext context) {
    final produced = pausa.quantidadeProduzida > 0
        ? ' · ${pausa.quantidadeProduzida} un'
        : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFEFDFBF)),
      ),
      child: Text(
        '${pausa.status} em ${pausa.etapa}: ${pausa.motivo} · ${pausa.tempo}$produced\n'
        '${pausa.iniciadaEm} · ${pausa.operador}',
        style: const TextStyle(
          fontSize: 12,
          height: 1.35,
          color: AppColors.orangeText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CancelConfirm extends StatefulWidget {
  final OrdemProducao op;
  final void Function(Map<String, String> returnWarehouses, String operatorPin)
  onConfirm;
  final VoidCallback onBack;

  const _CancelConfirm({
    required this.op,
    required this.onConfirm,
    required this.onBack,
  });

  @override
  State<_CancelConfirm> createState() => _CancelConfirmState();
}

class _CancelConfirmState extends State<_CancelConfirm> {
  late final Map<String, String> _returnWarehouses;
  late final TextEditingController _pinController;
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _returnWarehouses = {
      for (final material in _physicalMaterials)
        material.codigo: material.armazem.isEmpty ? '05' : material.armazem,
    };
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  List<MaterialOpDetalhe> get _physicalMaterials => widget
      .op
      .materiaisDetalhados
      .where(
        (material) =>
            material.codigo.trim().isNotEmpty && material.movimentaEstoque,
      )
      .toList();

  List<MaterialOpDetalhe> get _materialsNeedingChoice {
    final orderWarehouse = widget.op.armazem.trim();
    if (orderWarehouse.isEmpty) return _physicalMaterials;
    return _physicalMaterials
        .where((material) => material.armazem.trim() != orderWarehouse)
        .toList();
  }

  void _confirm() {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _pinError = 'Informe o PIN para assinar o cancelamento.');
      return;
    }
    widget.onConfirm(Map.of(_returnWarehouses), pin);
  }

  @override
  Widget build(BuildContext context) {
    final materials = _materialsNeedingChoice;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8B8B8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.undo_rounded,
                          color: AppColors.danger,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cancelar OP e devolver empenhos',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textStrong,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.op.numero,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.op.produto,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CancelInfoChip(
                        icon: Icons.inventory_2_outlined,
                        label: '${_physicalMaterials.length} itens físicos',
                      ),
                      _CancelInfoChip(
                        icon: Icons.compare_arrows_rounded,
                        label: '${materials.length} externos',
                      ),
                      _CancelInfoChip(
                        icon: Icons.confirmation_number_outlined,
                        label: widget.op.qtdLabel,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Retorno por item',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.textStrong,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Escolha para onde cada material externo deve voltar. Itens do próprio armazém retornam automaticamente para a origem.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.muted,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (materials.isNotEmpty)
              Column(
                children: [
                  for (var i = 0; i < materials.length; i++) ...[
                    _CancelReturnItem(
                      material: materials[i],
                      selectedWarehouse:
                          _returnWarehouses[materials[i].codigo] ??
                          materials[i].armazem,
                      onWarehouse: (warehouse) => setState(
                        () =>
                            _returnWarehouses[materials[i].codigo] = warehouse,
                      ),
                    ),
                    if (i < materials.length - 1) const SizedBox(height: 10),
                  ],
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgHeader,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Text(
                  'Sem material físico externo. Os empenhos voltam automaticamente para o armazém de origem.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            TextField(
              key: const Key('cancel-op-operator-pin'),
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                if (_pinError != null) setState(() => _pinError = null);
              },
              decoration: InputDecoration(
                labelText: 'PIN do responsável',
                helperText:
                    'Assinatura obrigatória para devolver empenhos no Protheus.',
                errorText: _pinError,
                prefixIcon: const Icon(Icons.password_rounded, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderField),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 14),
            compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CancelPrimaryButton(onPressed: _confirm),
                      const SizedBox(height: 10),
                      _CancelBackButton(onPressed: widget.onBack),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _CancelPrimaryButton(onPressed: _confirm),
                      ),
                      const SizedBox(width: 10),
                      _CancelBackButton(onPressed: widget.onBack),
                    ],
                  ),
          ],
        );
      },
    );
  }
}

class _CancelInfoChip extends StatelessWidget {
  const _CancelInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE8B8B8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.danger),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textCode,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelPrimaryButton extends StatelessWidget {
  const _CancelPrimaryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline_rounded, size: 18),
      label: const Text('Confirmar cancelamento'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CancelBackButton extends StatelessWidget {
  const _CancelBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: const Text('Voltar'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.bgButton,
        foregroundColor: AppColors.textCode,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CancelReturnItem extends StatelessWidget {
  const _CancelReturnItem({
    required this.material,
    required this.selectedWarehouse,
    required this.onWarehouse,
  });

  final MaterialOpDetalhe material;
  final String selectedWarehouse;
  final ValueChanged<String> onWarehouse;

  @override
  Widget build(BuildContext context) {
    final warehouses = {
      if (material.armazem.isNotEmpty) material.armazem,
      for (final warehouse in WarehouseRouting.all) warehouse.code,
    }.toList();
    final safeValue = warehouses.contains(selectedWarehouse)
        ? selectedWarehouse
        : warehouses.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            material.label,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13.5,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _CancelItemChip(
                label: 'Quantidade total',
                value: material.quantidadeTotal.toString(),
              ),
              _CancelItemChip(
                label: 'Origem',
                value: material.armazem.isEmpty
                    ? 'sem armazém'
                    : WarehouseRouting.labelForWarehouse(material.armazem),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: safeValue,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Armazém de retorno',
              helperText: 'Escolha o local que receberá a devolução.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderField),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              isDense: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            items: [
              for (final warehouse in warehouses)
                DropdownMenuItem(
                  value: warehouse,
                  child: Text(
                    WarehouseRouting.labelForWarehouse(warehouse),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: material.movimentaEstoque
                ? (value) {
                    if (value != null) onWarehouse(value);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _CancelItemChip extends StatelessWidget {
  const _CancelItemChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.bgHeader,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: AppColors.textStrong,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyActions extends StatelessWidget {
  const _ReadOnlyActions({
    required this.message,
    required this.onClose,
    required this.isDesktop,
  });

  final String message;
  final VoidCallback onClose;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.bgButton,
              border: Border.all(color: AppColors.borderLight),
              borderRadius: BorderRadius.circular(isDesktop ? 9 : 11),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Somente visualização',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textCode,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: onClose,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textCode,
              side: const BorderSide(color: AppColors.borderField),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              textStyle: GoogleFonts.ibmPlexSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Fechar'),
          ),
        ],
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool canAdvance;
  final bool isDone;
  final bool canRegress;
  final String actionLabel;
  final OrdemProducao op;
  final void Function({int quantidadeArmazenada}) onAdvance;
  final VoidCallback onRegress;
  final VoidCallback onAskCancel;
  final VoidCallback onClose;
  final bool isDesktop;

  const _ActionButtons({
    required this.canAdvance,
    required this.isDone,
    required this.canRegress,
    required this.actionLabel,
    required this.op,
    required this.onAdvance,
    required this.onRegress,
    required this.onAskCancel,
    required this.onClose,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    Future<void> handleAdvance() async {
      if (op.stage != ProductionStage.expedition) {
        onAdvance();
        return;
      }

      final quantidade = await showDialog<int>(
        context: context,
        builder: (context) => _StorageDecisionDialog(op: op),
      );
      if (quantidade == null) return;
      onAdvance(quantidadeArmazenada: quantidade);
    }

    return Column(
      children: [
        if (canAdvance)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: handleAdvance,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 9 : 11),
                ),
                textStyle: GoogleFonts.ibmPlexSans(
                  fontSize: isDesktop ? 13.5 : 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(actionLabel),
            ),
          ),
        if (isDone)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgFinalizada,
              borderRadius: BorderRadius.circular(isDesktop ? 9 : 11),
            ),
            alignment: Alignment.center,
            child: Text(
              'OP finalizada ✓',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.statusFinalizada,
              ),
            ),
          ),
        const SizedBox(height: 11),
        Row(
          children: [
            if (canRegress) ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: onRegress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bgButton,
                    foregroundColor: AppColors.textCode,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isDesktop ? 9 : 11),
                    ),
                    textStyle: GoogleFonts.ibmPlexSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Voltar etapa'),
                ),
              ),
              const SizedBox(width: 9),
            ],
            if (isDesktop)
              TextButton(
                onPressed: onAskCancel,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  textStyle: GoogleFonts.ibmPlexSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Cancelar OP'),
              )
            else
              Expanded(
                child: OutlinedButton(
                  onPressed: onAskCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: Color(0xFFF3D4D4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    textStyle: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Cancelar OP'),
                ),
              ),
            if (isDesktop) ...[
              const Spacer(),
              OutlinedButton(
                onPressed: onClose,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textCode,
                  side: const BorderSide(color: AppColors.borderField),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: GoogleFonts.ibmPlexSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Fechar'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _StorageDecisionDialog extends StatefulWidget {
  final OrdemProducao op;

  const _StorageDecisionDialog({required this.op});

  @override
  State<_StorageDecisionDialog> createState() => _StorageDecisionDialogState();
}

class _StorageDecisionDialogState extends State<_StorageDecisionDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _parseQuantity() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 0 || value > widget.op.qtd) {
      setState(() {
        _error = 'Informe uma quantidade entre 0 e ${widget.op.qtd}.';
      });
      return null;
    }
    return value;
  }

  void _submitTypedQuantity() {
    final quantity = _parseQuantity();
    if (quantity == null) return;
    Navigator.of(context).pop(quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 440,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Concluir OP',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.op.numero} · ${widget.op.qtdLabel}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.bgHeader,
                border: Border.all(color: AppColors.borderLight),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text(
                'Separe a quantidade que deve ir apenas para armazenamento. Use 0 para concluir sem armazenar.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _SectionLabel('QUANTIDADE PARA ARMAZENAMENTO', small: true),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '0 a ${widget.op.qtd}',
                errorText: _error,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: AppColors.borderField),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: AppColors.borderField),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              style: GoogleFonts.ibmPlexMono(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textCode,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(0),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textCode,
                      side: const BorderSide(color: AppColors.borderField),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Sem armazenar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(widget.op.qtd),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Armazenar tudo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitTypedQuantity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Concluir com quantidade informada'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgButton,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 18, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final StatusOP status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: status.dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: status.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        'Prioridade alta',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.danger,
        ),
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final String? text;
  final Widget? child;

  const _InfoField({required this.label, this.text, this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label, small: true),
        const SizedBox(height: 6),
        child ??
            Text(
              text!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textStrong,
              ),
            ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool small;

  const _SectionLabel(this.text, {this.small = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: small ? 10.5 : 11.5,
        fontWeight: FontWeight.w700,
        color: small ? AppColors.muted : AppColors.text,
        letterSpacing: 0.5,
      ),
    );
  }
}
