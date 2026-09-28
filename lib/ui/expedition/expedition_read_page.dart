import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_read_page.dart';

class ExpeditionReadPage extends WarehouseReadPage {
  const ExpeditionReadPage({super.key})
    : super.expedition(sectorAction: const ExpeditionFlowButton());
}

class ExpeditionFlowButton extends StatelessWidget {
  const ExpeditionFlowButton({super.key});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    label: const Text('Conferência anterior'),
    icon: const Icon(Icons.fact_check_outlined),
    onPressed: () => Navigator.of(context).pushNamed('/expedicao/fluxo-local'),
  );
}

class ExpeditionNavigationButton extends StatelessWidget {
  const ExpeditionNavigationButton({super.key});

  @override
  Widget build(BuildContext context) {
    final operator = context.watch<OperatorAssignmentStore?>()?.currentOperator;
    if (operator?.canView(AppSector.expedition) != true) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      icon: const Icon(Icons.local_shipping_outlined, size: 20),
      label: const Text('Expedição'),
      onPressed: () => Navigator.of(context).pushNamed('/expedicao'),
    );
  }
}
