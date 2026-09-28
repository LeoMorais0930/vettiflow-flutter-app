import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_read_page.dart';

class SmdPage extends WarehouseReadPage {
  const SmdPage({super.key}) : super.smd();
}

class SmdNavigationButton extends StatelessWidget {
  const SmdNavigationButton({super.key});

  @override
  Widget build(BuildContext context) {
    final operator = context.watch<OperatorAssignmentStore?>()?.currentOperator;
    if (operator?.canView(AppSector.smd) != true) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      icon: const Icon(Icons.developer_board_outlined, size: 20),
      label: Text(
        operator!.canOperate(AppSector.smd) ? 'SMD' : 'SMD · consulta',
      ),
      onPressed: () => Navigator.of(context).pushNamed('/smd'),
    );
  }
}
