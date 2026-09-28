import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/protheus/fila_protheus_page.dart';

class ProtheusQueueButton extends StatelessWidget {
  const ProtheusQueueButton({
    super.key,
    this.compact = false,
    this.dark = false,
  });

  final bool compact;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fila = context.watch<PendingMutationStore?>();
    if (fila == null) return const SizedBox.shrink();

    final aguardando = fila.awaitingCount;
    final foreground = dark ? Colors.white : AppColors.muted;

    return IconButton(
      tooltip: aguardando == 0
          ? 'Protheus somente leitura'
          : '$aguardando rascunho${aguardando == 1 ? '' : 's'} local${aguardando == 1 ? '' : 'is'} sem envio',
      onPressed: () => Navigator.of(context).pushNamed(FilaProtheusPage.rota),
      icon: Badge(
        isLabelVisible: aguardando > 0,
        label: Text('$aguardando'),
        backgroundColor: AppColors.orange,
        child: Icon(
          Icons.cloud_sync_rounded,
          color: foreground,
          size: compact ? 20 : 22,
        ),
      ),
      color: foreground,
      style: IconButton.styleFrom(
        backgroundColor: dark
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFF2F5F8),
        side: BorderSide(color: dark ? Colors.white24 : AppColors.borderLight),
        minimumSize: Size.square(compact ? 34 : 40),
        fixedSize: Size.square(compact ? 34 : 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
