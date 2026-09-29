import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class TableView extends StatelessWidget {
  final List<OrdemProducao> ordens;
  final ValueChanged<String> onOpenOP;

  const TableView({super.key, required this.ordens, required this.onOpenOP});

  @override
  Widget build(BuildContext context) {
    if (ordens.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: const Center(
          child: Text(
            'Nenhuma OP encontrada com os filtros atuais.',
            style: TextStyle(fontSize: 13, color: AppColors.textWeak),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 300,
          ),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(AppColors.bgHeader),
            headingRowHeight: 44,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 56,
            columnSpacing: 16,
            horizontalMargin: 16,
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: _HeaderText('OP')),
              DataColumn(label: _HeaderText('PRODUTO')),
              DataColumn(label: _HeaderText('QTD')),
              DataColumn(label: _HeaderText('RESPONSÁVEL')),
              DataColumn(label: _HeaderText('ABERTURA')),
              DataColumn(label: _HeaderText('PRAZO')),
              DataColumn(label: _HeaderText('STATUS')),
              DataColumn(label: _HeaderText('EXECUÇÃO VETTIFLOW')),
              DataColumn(label: _HeaderText('PROGRESSO')),
            ],
            rows: ordens.map((op) {
              final resp = Responsavel.byNome(op.responsavel);
              return DataRow(
                onSelectChanged: (_) => onOpenOP(op.numero),
                cells: [
                  DataCell(
                    Text(
                      op.numero,
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textCode,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      op.produto,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textStrong,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      op.qtdLabel,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
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
                        Text(
                          op.responsavel,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      op.dataAbertura,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          op.prazo,
                          style: TextStyle(
                            color: op.atrasada
                                ? AppColors.danger
                                : AppColors.textMuted,
                            fontWeight: op.atrasada
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        if (op.atrasada) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
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
                  DataCell(
                    _StatusBadge(
                      status: op.status,
                      label: op.status == StatusOP.finalizada
                          ? op.conclusaoLabel
                          : null,
                    ),
                  ),
                  DataCell(
                    Tooltip(
                      message: op.execution == null
                          ? ''
                          : 'Último registro: ${op.execution!.actor}\n${op.execution!.note}',
                      child: Text(
                        op.execution == null
                            ? (op.encerradaNoErp
                                  ? 'Sem registro interno'
                                  : 'Sem execução registrada')
                            : '${op.execution!.stage.label} · ${op.execution!.statusLabel}',
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 160,
                      child: Row(
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
                          SizedBox(
                            width: 30,
                            child: Text(
                              op.percentLabel,
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8A94A3),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final StatusOP status;
  final String? label;

  const _StatusBadge({required this.status, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            label ?? status.shortLabel,
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
