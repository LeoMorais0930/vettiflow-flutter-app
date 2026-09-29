import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_cubit.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_state.dart';

class OrdensView extends StatelessWidget {
  const OrdensView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();

    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        final ordens = state.ordensFiltradas;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 17),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ordens de Produção',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${state.ordens.length} ordens cadastradas',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: cubit.openNovaOP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      textStyle: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Text('+', style: TextStyle(fontSize: 17)),
                    label: const Text('Nova OP'),
                  ),
                ],
              ),
            ),

            // Filters
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 18, 26, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Flexible(
                          flex: 3,
                          child: _SearchField(onChanged: cubit.setBusca),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 2,
                          child: _Dropdown(
                            value: state.filtroPeriodo,
                            items: const {
                              'todos': 'Todos os períodos',
                              'jun': 'Junho 2026',
                              'mai': 'Maio 2026',
                            },
                            onChanged: cubit.setFiltroPeriodo,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 2,
                          child: _Dropdown(
                            value: state.filtroResponsavel,
                            items: {
                              'todos': 'Todos os responsáveis',
                              for (final r in state.responsaveis)
                                r.nome: r.nome,
                            },
                            onChanged: cubit.setFiltroResponsavel,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 2,
                          child: _Dropdown(
                            value: state.filtroProduto,
                            items: {
                              'todos': 'Todos os produtos',
                              for (final p in state.produtos) p: p,
                            },
                            onChanged: cubit.setFiltroProduto,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Status filter chips
                        ...StatusOP.values.map((s) {
                          final active = state.filtroStatus == s;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              selected: active,
                              label: Text(s.shortLabel),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? s.textColor
                                    : AppColors.textMuted,
                              ),
                              avatar: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: s.dot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              backgroundColor: AppColors.surface,
                              selectedColor: s.bgColor,
                              side: BorderSide(
                                color: active ? s.dot : AppColors.border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(99),
                              ),
                              showCheckmark: false,
                              onSelected: (_) => cubit.toggleStatusFilter(s),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        }),
                        const Spacer(),
                        if (state.hasActiveFilters)
                          TextButton(
                            onPressed: cubit.limparFiltros,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              textStyle: GoogleFonts.ibmPlexSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                            ),
                            child: const Text('Limpar filtros'),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          state.resultText,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Table
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 18, 26, 26),
                child: _OrdensTable(ordens: ordens, onOpenOP: cubit.openOP),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrdensTable extends StatelessWidget {
  final List<OrdemProducao> ordens;
  final ValueChanged<String> onOpenOP;

  const _OrdensTable({required this.ordens, required this.onOpenOP});

  @override
  Widget build(BuildContext context) {
    if (ordens.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 900
              ? 900.0
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  Container(
                    color: AppColors.bgHeader,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 110, child: _ColHeader('OP')),
                        Expanded(flex: 2, child: _ColHeader('PRODUTO')),
                        SizedBox(width: 60, child: _ColHeader('QTD')),
                        Expanded(flex: 2, child: _ColHeader('RESPONSÁVEL')),
                        SizedBox(width: 85, child: _ColHeader('ABERTURA')),
                        SizedBox(width: 85, child: _ColHeader('PRAZO')),
                        SizedBox(width: 120, child: _ColHeader('STATUS')),
                        SizedBox(width: 140, child: _ColHeader('PROGRESSO')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: ordens.length,
                      itemBuilder: (_, i) => _OrderRow(
                        op: ordens[i],
                        onTap: () => onOpenOP(ordens[i].numero),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final OrdemProducao op;
  final VoidCallback onTap;

  const _OrderRow({required this.op, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final resp = Responsavel.byNome(op.responsavel);

    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.bgHover,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderLight)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                op.numero,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textCode,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                op.produto,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textStrong,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                op.qtdLabel,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            Expanded(
              flex: 2,
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
                  Flexible(
                    child: Text(
                      op.responsavel,
                      style: const TextStyle(color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 85,
              child: Text(
                op.dataAbertura,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                ),
              ),
            ),
            SizedBox(
              width: 85,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
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
                  ),
                  if (op.atrasada) ...[
                    const SizedBox(width: 4),
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
                        '!',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 120,
              child: _StatusBadge(
                status: op.status,
                label: op.status == StatusOP.finalizada
                    ? op.conclusaoLabel
                    : null,
              ),
            ),
            SizedBox(
              width: 140,
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
          ],
        ),
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
          Flexible(
            child: Text(
              label ?? status.shortLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: status.textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;

  const _ColHeader(this.text);

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

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderField),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Buscar OP ou produto...',
                hintStyle: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  color: AppColors.muted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderField),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
          items: items.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
