import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/data/models/dashboard_order_groups.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class OpCard extends StatelessWidget {
  final OrdemProducao op;
  final Color accentColor;
  final VoidCallback onTap;
  final bool showResponsavelName;

  const OpCard({
    super.key,
    required this.op,
    required this.accentColor,
    required this.onTap,
    this.showResponsavelName = false,
  });

  @override
  Widget build(BuildContext context) {
    final resp = Responsavel.byNome(op.responsavel);

    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.white,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderLight),
                right: BorderSide(color: AppColors.borderLight),
                bottom: BorderSide(color: AppColors.borderLight),
                left: BorderSide(color: accentColor, width: 3),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        op.numero,
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textCode,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (op.prioridadeAlta) const _PriorityBadge(),
                        if (op.prioridadeAlta && op.atrasada)
                          const SizedBox(width: 6),
                        if (op.atrasada) const _LateBadge(),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (op.erpReadOnly) ...[
                  Text(
                    'Setor: ${erpOrderSectorLabel(op.armazem)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (op.execution != null) ...[
                    Text(
                      '${op.execution!.stage.label} · ${op.execution!.statusLabel}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: op.execution!.status == 'paused'
                            ? Colors.deepOrange
                            : AppColors.textStrong,
                      ),
                    ),
                    Text(
                      'Último registro: ${op.execution!.actor}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    if (op.execution!.status == 'paused' &&
                        op.execution!.note.isNotEmpty)
                      Text(
                        'Motivo: ${op.execution!.note}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                  ] else if (!op.encerradaNoErp)
                    const Text(
                      'Sem execução registrada',
                      style: TextStyle(fontSize: 11, color: AppColors.textWeak),
                    ),
                  const SizedBox(height: 8),
                ],
                if (op.status == StatusOP.finalizada)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      op.conclusaoLabel,
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Text(
                  op.produto,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textStrong,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (showResponsavelName && resp != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Avatar(resp: resp),
                          const SizedBox(width: 7),
                          Text(
                            op.responsavel,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        op.qtdLabel,
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    if (!showResponsavelName && resp != null)
                      _Avatar(resp: resp),
                    if (showResponsavelName)
                      Text(
                        op.qtdLabel,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
                if (op.showBar) ...[
                  const SizedBox(height: 8),
                  _ProgressBar(
                    progress: op.progresso / 100,
                    color: op.status.barColor,
                    label: op.percentLabel,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  op.encerradaNoErp
                      ? 'Encerramento ${op.dataEncerramento}'
                      : op.prazoLabel,
                  style: TextStyle(fontSize: 11.5, color: AppColors.textWeak),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        'Alta',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.danger,
        ),
      ),
    );
  }
}

class _LateBadge extends StatelessWidget {
  const _LateBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
    );
  }
}

class _Avatar extends StatelessWidget {
  final Responsavel resp;

  const _Avatar({required this.resp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: resp.cor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        resp.iniciais,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final String label;

  const _ProgressBar({
    required this.progress,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.bgProgress,
              borderRadius: BorderRadius.circular(99),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.ibmPlexMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
