import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/firmware_models.dart';

class OperationActions extends StatelessWidget {
  const OperationActions({
    super.key,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
    required this.onReset,
    this.compact = false,
    this.startLabel = 'Iniciar gravacao',
    this.resumeLabel = 'Retomar gravacao',
    this.completeLabel = 'Concluir OP',
    this.pauseLabel = 'Pausar OP',
    this.completedLabel = 'OP concluida e enviada para a proxima etapa.',
  });

  final FirmwareStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;
  final VoidCallback onReset;
  final bool compact;
  final String startLabel;
  final String resumeLabel;
  final String completeLabel;
  final String pauseLabel;
  final String completedLabel;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 50.0 : 52.0;

    return switch (status) {
      FirmwareStatus.waiting => _ActionButton(
        label: startLabel,
        icon: Icons.play_arrow_rounded,
        onPressed: onStart,
        fillColor: AppColors.primary,
        foregroundColor: Colors.white,
        height: height,
        width: compact ? double.infinity : 280,
      ),
      FirmwareStatus.recording => _ActionPair(
        height: height,
        primary: _ActionButton(
          label: completeLabel,
          icon: Icons.check_rounded,
          onPressed: onComplete,
          fillColor: AppColors.green,
          foregroundColor: Colors.white,
          height: height,
        ),
        secondary: _ActionButton(
          label: pauseLabel,
          icon: Icons.pause_rounded,
          onPressed: onPause,
          foregroundColor: AppColors.orangeText,
          borderColor: AppColors.orange,
          height: height,
        ),
      ),
      FirmwareStatus.paused => _ActionPair(
        height: height,
        primary: _ActionButton(
          label: resumeLabel,
          icon: Icons.play_arrow_rounded,
          onPressed: onStart,
          fillColor: AppColors.primary,
          foregroundColor: Colors.white,
          height: height,
        ),
        secondary: _ActionButton(
          label: completeLabel,
          icon: Icons.check_rounded,
          onPressed: onComplete,
          foregroundColor: AppColors.green,
          borderColor: AppColors.green,
          height: height,
        ),
      ),
      FirmwareStatus.completed => _CompletedBanner(
        height: height,
        compact: compact,
        onReset: onReset,
        label: completedLabel,
      ),
    };
  }
}

class _ActionPair extends StatelessWidget {
  const _ActionPair({
    required this.primary,
    required this.secondary,
    required this.height,
  });

  final Widget primary;
  final Widget secondary;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Row(
        children: [
          Expanded(child: secondary),
          const SizedBox(width: 12),
          Expanded(child: primary),
        ],
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner({
    required this.height,
    required this.compact,
    required this.onReset,
    required this.label,
  });

  final double height;
  final bool compact;
  final VoidCallback onReset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F6EC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFE5CC)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.green,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
    this.icon,
    this.fillColor,
    this.borderColor,
    this.width,
    this.height = 52,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color? fillColor;
  final Color? borderColor;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: fillColor ?? Colors.white,
          foregroundColor: foregroundColor,
          side: BorderSide(
            color: borderColor ?? fillColor ?? const Color(0xFFD8E6EE),
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: fillColor == null ? 0 : 2,
          shadowColor: fillColor?.withValues(alpha: 0.26),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
