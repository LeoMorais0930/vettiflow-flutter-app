import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_read_page.dart';

class ProductionReadPage extends WarehouseReadPage {
  const ProductionReadPage({super.key}) : super.production();
}

class ProductionNavigationButton extends StatelessWidget {
  const ProductionNavigationButton({super.key});

  @override
  Widget build(BuildContext context) {
    final operator = context.watch<OperatorAssignmentStore?>()?.currentOperator;
    if (operator?.canView(AppSector.production) != true) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      icon: const Icon(Icons.precision_manufacturing_outlined, size: 20),
      label: const Text('Produção'),
      onPressed: () => Navigator.of(context).pushNamed('/producao'),
    );
  }
}
