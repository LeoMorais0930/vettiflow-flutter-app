import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_read_page.dart';

class SupportPage extends WarehouseReadPage {
  const SupportPage({super.key})
    : super.support(sectorAction: const SupportDefectsButton());
}

class SupportNavigationButton extends StatelessWidget {
  const SupportNavigationButton({super.key});

  @override
  Widget build(BuildContext context) {
    final operator = context.watch<OperatorAssignmentStore?>()?.currentOperator;
    if (operator?.canView(AppSector.support) != true) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      icon: const Icon(Icons.build_outlined, size: 20),
      label: const Text('Suporte'),
      onPressed: () => Navigator.of(context).pushNamed('/suporte'),
    );
  }
}

class SupportDefectsButton extends StatelessWidget {
  const SupportDefectsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProductionFlowStore?>();
    final records = [
      for (final order in store?.orders ?? [])
        for (final defect in order.testDefects)
          (
            op: order.number,
            product: order.productLabel,
            code: defect.code,
            title: defect.title,
            quantity: defect.quantity,
          ),
    ];
    return TextButton.icon(
      label: const Text('Defeitos da produção'),
      icon: const Icon(Icons.fact_check_outlined),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Defeitos da produção'),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Registros locais dos testes. A transferência para o suporte deve ser conferida no histórico do Protheus.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (records.isEmpty)
                  const Text('Nenhum defeito registrado no VettiFlow.')
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (_, index) {
                        final record = records[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('OP ${record.op} · ${record.product}'),
                          subtitle: Text('${record.code} · ${record.title}'),
                          trailing: Text('${record.quantity} un'),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }
}
