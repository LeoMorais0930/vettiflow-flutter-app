import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_auth_session.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_environment_badge.dart';
import 'package:vetti_flow_1_0/ui/protheus/fila_protheus_page.dart';

class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key, this.dark = false, this.showName = false});
  final bool dark, showName;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<OperatorAssignmentStore?>();
    final operator = store?.currentOperator;
    final foreground = dark ? Colors.white : null;
    return PopupMenuButton<String>(
      tooltip: 'Minha área e conta',
      iconColor: foreground,
      icon: showName ? null : const Icon(Icons.account_circle_outlined),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            operator == null
                ? 'Sem sessão'
                : '${operator.name}\n${operator.role}',
          ),
        ),
        if (operator != null) ...[
          PopupMenuItem(
            value: operator.homeRoute,
            child: const Text('Minha área'),
          ),
          if (operator.canManageAssignments)
            const PopupMenuItem(
              value: '/colaboradores',
              child: Text('Colaboradores'),
            ),
          for (final sector in operator.visibleSectors)
            PopupMenuItem(
              value: sector.route,
              child: Text(
                '${sector.label}${operator.canOperate(sector) ? '' : ' · consulta'}',
              ),
            ),
        ],
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'environment',
          child: Text('Ambiente e conexão'),
        ),
        if (operator?.isAdministrator == true)
          const PopupMenuItem(
            value: FilaProtheusPage.rota,
            child: Text('Integração Protheus'),
          ),
        const PopupMenuItem(value: 'logout', child: Text('Sair')),
      ],
      onSelected: (value) {
        if (value == 'logout') {
          store?.logout();
          context.read<ProtheusAuthSession?>()?.logout();
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        } else if (value == 'environment') {
          showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Ambiente e conexão'),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProtheusEnvironmentBadge(),
                  SizedBox(height: 16),
                  Text(
                    'O Protheus está em modo de consulta. As operações do VettiFlow ficam neste navegador.',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          );
        } else if (ModalRoute.of(context)?.settings.name != value) {
          Navigator.pushNamed(context, value);
        }
      },
      child: showName
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_circle_outlined, color: foreground),
                  const SizedBox(width: 8),
                  Text(
                    operator?.name ?? 'Conta',
                    style: TextStyle(color: foreground),
                  ),
                  Icon(Icons.expand_more, size: 18, color: foreground),
                ],
              ),
            )
          : null,
    );
  }
}
