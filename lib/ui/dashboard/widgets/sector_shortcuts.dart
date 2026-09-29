import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator_access.dart';

class SectorShortcuts extends StatelessWidget {
  const SectorShortcuts({super.key});

  @override
  Widget build(BuildContext context) {
    final actor = context.watch<OperatorAssignmentStore>().currentOperator;
    final sectors = actor?.visibleSectors.toList() ?? [];
    if (sectors.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            actor?.isAdministrator == true
                ? 'Administração · todos os setores'
                : 'Meus setores',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sector in sectors)
                OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(sector.route),
                  child: Text(sector.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
