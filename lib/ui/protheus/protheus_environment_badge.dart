import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class ProtheusEnvironmentBadge extends StatefulWidget {
  const ProtheusEnvironmentBadge({
    super.key,
    this.compact = false,
    this.dark = false,
  });

  final bool compact;
  final bool dark;

  @override
  State<ProtheusEnvironmentBadge> createState() =>
      _ProtheusEnvironmentBadgeState();
}

class _ProtheusEnvironmentBadgeState extends State<ProtheusEnvironmentBadge> {
  Future<ProtheusHealth>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context.read<ProtheusSyncClient?>()?.healthInfo();
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<ProtheusHealth>(
      future: future,
      builder: (context, snapshot) {
        final health = snapshot.data;
        final online = health?.ok == true;
        final database = health?.database.trim() ?? '';
        final label = online && database.isNotEmpty
            ? '$database · somente leitura'
            : 'Protheus · somente leitura';
        final color = online ? AppColors.green : AppColors.orange;

        return Tooltip(
          message: 'VettiFlow consulta o Protheus em modo somente leitura.',
          child: Container(
            constraints: BoxConstraints(maxWidth: widget.compact ? 168 : 260),
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 9 : 11,
              vertical: widget.compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: widget.dark
                  ? Colors.white.withValues(alpha: 0.11)
                  : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: widget.dark
                    ? Colors.white24
                    : color.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_rounded,
                  size: widget.compact ? 15 : 16,
                  color: widget.dark ? const Color(0xFF9EE5FF) : color,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.dark ? Colors.white : AppColors.text,
                      fontSize: widget.compact ? 10.5 : 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
