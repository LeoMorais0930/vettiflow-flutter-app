import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_state.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_read_page.dart';
import 'package:vetti_flow_1_0/ui/smd/smd_page.dart';
import 'package:vetti_flow_1_0/ui/production/production_read_page.dart';
import 'package:vetti_flow_1_0/ui/support/support_page.dart';
import 'package:vetti_flow_1_0/ui/expedition/expedition_read_page.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.viewMode, required this.onViewMode});

  final ViewMode viewMode;
  final ValueChanged<ViewMode> onViewMode;

  @override
  Widget build(BuildContext context) {
    final currentOperator = context
        .watch<OperatorAssignmentStore>()
        .currentOperator;
    final managerName = currentOperator?.name ?? 'Sem sessão';
    final managerRole = currentOperator?.role ?? 'Coordenadora da producao';

    return Container(
      width: 230,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/vetti-flow-logo.png',
                    width: 128,
                    color: Colors.white,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                currentOperator?.isAdministrator == true
                    ? 'ADMINISTRAÇÃO'
                    : 'MEU PAINEL',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 24),
              _NavItem(
                icon: _panelIcon,
                label: 'Painel',
                active:
                    viewMode == ViewMode.kanban || viewMode == ViewMode.tabela,
                onTap: () => onViewMode(ViewMode.kanban),
              ),
              _NavItem(
                icon: _listIcon,
                label: 'Ordens de Produção',
                active: viewMode == ViewMode.cards,
                onTap: () => onViewMode(ViewMode.cards),
              ),
              _NavItem(
                icon: _boxIcon,
                label: 'Armazenadas',
                active: viewMode == ViewMode.armazenadas,
                onTap: () => onViewMode(ViewMode.armazenadas),
              ),
              _NavItem(
                icon: _userIcon,
                label: 'Colaboradores',
                active: viewMode == ViewMode.responsaveis,
                onTap: () => onViewMode(ViewMode.responsaveis),
              ),
              _NavItem(
                icon: _chartIcon,
                label: 'Relatórios',
                active: viewMode == ViewMode.relatorios,
                onTap: () => onViewMode(ViewMode.relatorios),
              ),
              const SizedBox(height: 18),
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  child: Text(
                    'MEUS SETORES',
                    style: TextStyle(fontSize: 10.5, color: AppColors.muted),
                  ),
                ),
              ),
              const WarehouseNavigationButton(),
              const SmdNavigationButton(),
              const ProductionNavigationButton(),
              const SupportNavigationButton(),
              const ExpeditionNavigationButton(),
              const SizedBox(height: 24),
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.borderLight)),
                ),
                padding: const EdgeInsets.only(top: 11),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFF7C3AED),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        managerName.characters.first.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            managerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            managerRole,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
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
    );
  }
}

class _NavItem extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: active ? const Color(0xFFE6F3FC) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          hoverColor: AppColors.bgHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              children: [
                IconTheme(
                  data: IconThemeData(
                    color: active ? AppColors.primary : AppColors.textMuted,
                    size: 17,
                  ),
                  child: icon,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? AppColors.primary : AppColors.textMuted,
                    ),
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

final _panelIcon = Icon(Icons.grid_view_rounded, size: 17);
final _listIcon = Icon(Icons.format_list_bulleted_rounded, size: 17);
final _boxIcon = Icon(Icons.inventory_2_outlined, size: 17);
final _userIcon = Icon(Icons.person_outline_rounded, size: 17);
final _chartIcon = Icon(Icons.bar_chart_rounded, size: 17);
