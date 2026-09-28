import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

/// Painel de chao de fabrica para TV (50"+).
///
/// Carrossel de 3 telas que rotacionam automaticamente, cada uma com uma
/// unica mensagem clara e enxuta, legivel a distancia:
///   1. Producao em andamento (numeros-heroi)
///   2. Onde estao as OPs (fluxo por etapa)
///   3. Saida e prioridades
/// Todo o dimensionamento e proporcional a largura da tela.
class VettiFlowTvPage extends StatefulWidget {
  const VettiFlowTvPage({super.key});

  @override
  State<VettiFlowTvPage> createState() => _VettiFlowTvPageState();
}

class _VettiFlowTvPageState extends State<VettiFlowTvPage> {
  static const _slideCount = 3;
  static const _slideDuration = Duration(seconds: 12);
  static const _slideTitles = [
    'Producao em andamento',
    'Fluxo por etapa',
    'Saida e prioridades',
  ];

  final _controller = PageController();
  var _now = DateTime.now();
  var _currentSlide = 0;
  Timer? _clock;
  Timer? _slideTimer;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _slideTimer = Timer.periodic(_slideDuration, (_) => _showNextSlide());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _slideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showNextSlide() {
    if (!mounted || !_controller.hasClients) return;
    _controller.animateToPage(
      (_currentSlide + 1) % _slideCount,
      duration: const Duration(milliseconds: 820),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProductionFlowStore>();
    final active = store.activeOrders;
    final completed = store.recentCompleted;

    final stored = store.orders
        .where((order) => order.totalStoredQuantity > 0)
        .toList();
    final paused = active
        .where((order) => order.status == ProductionRunStatus.paused)
        .toList();
    final highPriority = active.where((order) => order.isHighPriority).toList();
    final activePieces = active.fold<int>(0, (sum, o) => sum + o.quantity);
    final storedPieces = _outputQuantities(
      stored,
      (o) => o.totalStoredQuantity,
    );
    final dispatchedPieces = _outputQuantities(
      store.orders,
      (o) => o.totalDispatchedQuantity,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFEDF2F7),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Escala por largura e altura para TVs grandes sem estourar em desktop compacto.
          final widthScale = constraints.maxWidth / 1920;
          final heightScale = constraints.maxHeight / 1080;
          final baseScale = widthScale < heightScale ? widthScale : heightScale;
          final scale = (baseScale * 1.08).clamp(0.42, 1.12);

          return Column(
            children: [
              _TvHeader(now: _now, scale: scale, liveCount: active.length),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _currentSlide = i),
                  children: [
                    _ExecutiveSlide(
                      scale: scale,
                      activeCount: active.length,
                      activePieces: activePieces,
                      pausedCount: paused.length,
                      attention: [...paused, ...highPriority].firstOrNull,
                      now: _now,
                    ),
                    _FlowSlide(scale: scale, active: active),
                    _OutputSlide(
                      scale: scale,
                      highPriority: highPriority,
                      storedCount: stored.length,
                      storedPieces: storedPieces,
                      dispatchedPieces: dispatchedPieces,
                      lastCompleted: completed.firstOrNull,
                    ),
                  ],
                ),
              ),
              _SlideFooter(
                scale: scale,
                currentSlide: _currentSlide,
                slideCount: _slideCount,
                titles: _slideTitles,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _TvHeader extends StatelessWidget {
  const _TvHeader({
    required this.now,
    required this.scale,
    required this.liveCount,
  });

  final DateTime now;
  final double scale;
  final int liveCount;

  @override
  Widget build(BuildContext context) {
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      height: 104 * scale,
      padding: EdgeInsets.symmetric(horizontal: 40 * scale),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56 * scale,
            height: 56 * scale,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14 * scale),
            ),
            child: Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 36 * scale,
            ),
          ),
          SizedBox(width: 20 * scale),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VETTIFLOW TV',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38 * scale,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2 * scale,
                  height: 1,
                ),
              ),
              SizedBox(height: 4 * scale),
              Text(
                'Painel de producao em tempo real',
                style: TextStyle(
                  color: const Color(0xFFCDE9FA),
                  fontSize: 19 * scale,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
          const Spacer(),
          _LiveBadge(scale: scale),
          SizedBox(width: 28 * scale),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48 * scale,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 1 * scale,
                ),
              ),
              SizedBox(height: 4 * scale),
              Text(
                _formatDate(now),
                style: TextStyle(
                  color: const Color(0xFFCDE9FA),
                  fontSize: 19 * scale,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(width: 14 * scale),
          IconButton(
            tooltip: 'Sair',
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/login'),
            icon: Icon(
              Icons.logout_rounded,
              color: Colors.white70,
              size: 28 * scale,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 18 * scale,
        vertical: 10 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Container(
            width: 12 * scale,
            height: 12 * scale,
            decoration: const BoxDecoration(
              color: Color(0xFF7BE495),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10 * scale),
          Text(
            'AO VIVO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: 1 * scale,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Casca de slide (eyebrow + titulo + conteudo)
// ---------------------------------------------------------------------------

class _SlideShell extends StatelessWidget {
  const _SlideShell({
    required this.scale,
    required this.index,
    required this.title,
    required this.child,
  });

  final double scale;
  final int index;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        44 * scale,
        30 * scale,
        44 * scale,
        20 * scale,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAINEL ${index + 1}/3',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 18 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: 2 * scale,
              height: 1,
            ),
          ),
          SizedBox(height: 10 * scale),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.title,
              fontSize: 56 * scale,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          SizedBox(height: 26 * scale),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 1 - Executivo
// ---------------------------------------------------------------------------

class _ExecutiveSlide extends StatelessWidget {
  const _ExecutiveSlide({
    required this.scale,
    required this.activeCount,
    required this.activePieces,
    required this.pausedCount,
    required this.attention,
    required this.now,
  });

  final double scale;
  final int activeCount;
  final int activePieces;
  final int pausedCount;
  final ProductionOrderFlow? attention;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      scale: scale,
      index: 0,
      title: 'Producao em andamento',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: _HeroMetric(
              scale: scale,
              label: 'OPs ativas',
              value: '$activeCount',
              helper: '$activePieces pecas no fluxo',
              icon: Icons.precision_manufacturing_rounded,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 26 * scale),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricCard(
                    scale: scale,
                    label: 'Pausadas',
                    value: '$pausedCount',
                    helper: pausedCount > 0 ? 'Requer atencao' : 'Tudo rodando',
                    icon: Icons.pause_circle_outline_rounded,
                    color: pausedCount > 0
                        ? AppColors.orangeText
                        : AppColors.green,
                  ),
                ),
                SizedBox(height: 22 * scale),
                Expanded(
                  child: attention == null
                      ? _ClearStatusCard(scale: scale)
                      : _AttentionCard(
                          scale: scale,
                          order: attention!,
                          now: now,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 2 - Fluxo por etapa
// ---------------------------------------------------------------------------

class _FlowSlide extends StatelessWidget {
  const _FlowSlide({required this.scale, required this.active});

  final double scale;
  final List<ProductionOrderFlow> active;

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      scale: scale,
      index: 1,
      title: 'Fluxo por etapa',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final stage in ProductionStage.productionFlow) ...[
            Expanded(
              child: _StageCard(
                scale: scale,
                stage: stage,
                orders: active.where((o) => o.currentStage == stage).toList(),
              ),
            ),
            if (stage != ProductionStage.productionFlow.last)
              SizedBox(width: 20 * scale),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 3 - Saida e prioridades
// ---------------------------------------------------------------------------

String _outputQuantities(
  Iterable<ProductionOrderFlow> orders,
  num Function(ProductionOrderFlow) quantity,
) {
  final totals = <String, num>{};
  for (final o in orders) {
    final value = quantity(o);
    if (value <= 0) continue;
    final unit = o.unit.isEmpty ? 'un' : o.unit;
    totals[unit] = (totals[unit] ?? 0) + value;
  }
  return totals.isEmpty
      ? '0'
      : totals.entries
            .map((e) => '${formatProductionQuantity(e.value)} ${e.key}')
            .join(' · ');
}

class _OutputSlide extends StatelessWidget {
  const _OutputSlide({
    required this.scale,
    required this.highPriority,
    required this.storedCount,
    required this.storedPieces,
    required this.dispatchedPieces,
    required this.lastCompleted,
  });

  final double scale;
  final List<ProductionOrderFlow> highPriority;
  final int storedCount;
  final String storedPieces;
  final String dispatchedPieces;
  final ProductionOrderFlow? lastCompleted;

  @override
  Widget build(BuildContext context) {
    return _SlideShell(
      scale: scale,
      index: 2,
      title: 'Saida e prioridades',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MetricCard(
              scale: scale,
              big: true,
              label: 'Prioridade alta',
              value: '${highPriority.length}',
              helper: highPriority.firstOrNull?.number ?? 'Sem pendencias',
              icon: Icons.priority_high_rounded,
              color: highPriority.isEmpty ? AppColors.green : AppColors.danger,
            ),
          ),
          SizedBox(width: 24 * scale),
          Expanded(
            child: _MetricCard(
              scale: scale,
              big: true,
              label: 'Em estoque',
              value: storedPieces,
              helper: '$storedCount OPs armazenadas',
              icon: Icons.warehouse_rounded,
              color: AppColors.primaryDark,
            ),
          ),
          SizedBox(width: 24 * scale),
          Expanded(
            child: _MetricCard(
              scale: scale,
              big: true,
              label: 'Expedidas',
              value: dispatchedPieces,
              helper: lastCompleted == null
                  ? 'Nenhuma finalizada'
                  : 'Ultima: ${lastCompleted!.number}',
              icon: Icons.local_shipping_rounded,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.scale,
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.color,
  });

  final double scale;
  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(44 * scale),
      decoration: _cardDecoration(scale, accent: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconChip(icon: icon, color: color, scale: scale, big: true),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 230 * scale,
                height: 0.82,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: 20 * scale),
          Text(
            label,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 60 * scale,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          SizedBox(height: 10 * scale),
          Text(
            helper,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 36 * scale,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.scale,
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.color,
    this.big = false,
  });

  final double scale;
  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = math.min(scale, constraints.maxHeight / (big ? 370 : 320));

        return Container(
          padding: EdgeInsets.all((big ? 40 : 30) * s),
          decoration: _cardDecoration(s, accent: color),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconChip(icon: icon, color: color, scale: s, big: big),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: (big ? 150 : 104) * s,
                    height: 0.82,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(height: 14 * s),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: (big ? 46 : 38) * s,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              SizedBox(height: 8 * s),
              Text(
                helper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: (big ? 30 : 26) * s,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.scale,
    required this.stage,
    required this.orders,
  });

  final double scale;
  final ProductionStage stage;
  final List<ProductionOrderFlow> orders;

  @override
  Widget build(BuildContext context) {
    final accent = _stageAccent(stage);
    final pieces = orders.fold<int>(0, (sum, o) => sum + o.quantity);
    final running = orders.any((o) => o.status == ProductionRunStatus.active);
    final paused = orders.any((o) => o.status == ProductionRunStatus.paused);
    final statusColor = paused
        ? AppColors.orangeText
        : running
        ? AppColors.green
        : accent;
    final statusLabel = paused
        ? 'Pausada'
        : running
        ? 'Rodando'
        : orders.isEmpty
        ? 'Livre'
        : 'Na fila';

    return Container(
      padding: EdgeInsets.all(26 * scale),
      decoration: _cardDecoration(scale, accent: accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconChip(icon: _stageIcon(stage), color: accent, scale: scale),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${orders.length}',
              style: TextStyle(
                color: accent,
                fontSize: 150 * scale,
                height: 0.82,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: 16 * scale),
          Text(
            stage.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 38 * scale,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          SizedBox(height: 16 * scale),
          _Pill(
            label: statusLabel,
            color: statusColor,
            scale: scale,
            big: true,
          ),
          SizedBox(height: 14 * scale),
          Text(
            '$pieces pecas',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 28 * scale,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.scale,
    required this.order,
    required this.now,
  });

  final double scale;
  final ProductionOrderFlow order;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final paused = order.status == ProductionRunStatus.paused;
    final color = paused ? AppColors.orangeText : AppColors.danger;
    final label = paused ? 'OP pausada' : 'Prioridade alta';

    return LayoutBuilder(
      builder: (context, constraints) {
        final s = math.min(scale, constraints.maxHeight / 295);

        return Container(
          padding: EdgeInsets.all(30 * s),
          decoration: _cardDecoration(
            s,
            accent: color,
            fill: color.withValues(alpha: 0.06),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconChip(
                icon: Icons.notification_important_rounded,
                color: color,
                scale: s,
              ),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 40 * s,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              SizedBox(height: 8 * s),
              Text(
                order.number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 52 * s,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              SizedBox(height: 8 * s),
              Text(
                '${order.currentStage.label} - ${_formatDuration(order.activeElapsed(now))}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 30 * s,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClearStatusCard extends StatelessWidget {
  const _ClearStatusCard({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = math.min(scale, constraints.maxHeight / 285);

        return Container(
          padding: EdgeInsets.all(30 * s),
          decoration: _cardDecoration(
            s,
            accent: AppColors.green,
            fill: const Color(0xFFEAF7EF),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconChip(
                icon: Icons.check_circle_rounded,
                color: AppColors.green,
                scale: s,
              ),
              const Spacer(),
              Text(
                'Fluxo normal',
                style: TextStyle(
                  color: AppColors.green,
                  fontSize: 44 * s,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              SizedBox(height: 8 * s),
              Text(
                'Sem pausas ou prioridades criticas',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 30 * s,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Pecas reutilizaveis
// ---------------------------------------------------------------------------

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.color,
    required this.scale,
    this.big = false,
  });

  final IconData icon;
  final Color color;
  final double scale;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = (big ? 92 : 76) * scale;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18 * scale),
      ),
      child: Icon(icon, color: color, size: (big ? 54 : 44) * scale),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.scale,
    this.big = false,
  });

  final String label;
  final Color color;
  final double scale;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (big ? 20 : 16) * scale,
        vertical: (big ? 11 : 8) * scale,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: (big ? 26 : 16) * scale,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _SlideFooter extends StatelessWidget {
  const _SlideFooter({
    required this.scale,
    required this.currentSlide,
    required this.slideCount,
    required this.titles,
  });

  final double scale;
  final int currentSlide;
  final int slideCount;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 * scale,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < slideCount; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: (i == currentSlide ? 60 : 18) * scale,
              height: 11 * scale,
              margin: EdgeInsets.symmetric(horizontal: 7 * scale),
              decoration: BoxDecoration(
                color: i == currentSlide
                    ? AppColors.primary
                    : const Color(0xFFC2D2DD),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          SizedBox(width: 20 * scale),
          Text(
            'Painel atual: ${titles[currentSlide]}',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 26 * scale,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BoxDecoration _cardDecoration(
  double scale, {
  required Color accent,
  Color fill = Colors.white,
}) {
  return BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(22 * scale),
    border: Border(
      top: BorderSide(color: accent, width: 5 * scale),
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF083047).withValues(alpha: 0.06),
        blurRadius: 22,
        offset: const Offset(0, 9),
      ),
    ],
  );
}

Color _stageAccent(ProductionStage stage) {
  return switch (stage) {
    ProductionStage.warehouse => const Color(0xFF0077BD),
    ProductionStage.smd => const Color(0xFF0E9C8A),
    ProductionStage.firmware => const Color(0xFF6D5BD0),
    ProductionStage.soldering => const Color(0xFFD97706),
    ProductionStage.testing => const Color(0xFF0E9C8A),
    ProductionStage.closing => const Color(0xFF7458D8),
    ProductionStage.expedition => const Color(0xFF209F58),
    ProductionStage.storage => AppColors.primaryDark,
    ProductionStage.completed => AppColors.green,
  };
}

IconData _stageIcon(ProductionStage stage) {
  return switch (stage) {
    ProductionStage.warehouse => Icons.warehouse_rounded,
    ProductionStage.smd => Icons.developer_board_rounded,
    ProductionStage.firmware => Icons.memory_rounded,
    ProductionStage.soldering => Icons.construction_rounded,
    ProductionStage.testing => Icons.fact_check_rounded,
    ProductionStage.closing => Icons.inventory_2_rounded,
    ProductionStage.expedition => Icons.local_shipping_rounded,
    ProductionStage.storage => Icons.inventory_2_rounded,
    ProductionStage.completed => Icons.check_circle_rounded,
  };
}

String _formatDuration(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '${hours}h ${minutes}m' : '$minutes:$seconds';
}

String _formatDate(DateTime now) {
  const weekdays = [
    'Segunda',
    'Terca',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sabado',
    'Domingo',
  ];
  const months = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
}
