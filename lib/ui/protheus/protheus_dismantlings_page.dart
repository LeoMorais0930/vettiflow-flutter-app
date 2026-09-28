import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/protheus_dismantlings.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_dismantling_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_environment_badge.dart';

class ProtheusDismantlingsPage extends StatefulWidget {
  const ProtheusDismantlingsPage({super.key});

  static const rota = '/desmontagens-protheus';

  @override
  State<ProtheusDismantlingsPage> createState() =>
      _ProtheusDismantlingsPageState();
}

class _ProtheusDismantlingsPageState extends State<ProtheusDismantlingsPage> {
  Future<ProtheusDismantlingSnapshot>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context
        .read<ProtheusDismantlingRepository?>()
        ?.fetchDismantlings();
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('Desmontagens Protheus'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: ProtheusEnvironmentBadge(compact: true)),
          ),
        ],
      ),
      body: SafeArea(
        child: future == null
            ? const _ReadOnlyEmpty()
            : FutureBuilder<ProtheusDismantlingSnapshot>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _StateMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Nao foi possivel ler desmontagens',
                      detail:
                          'A consulta falhou sem criar, alterar ou excluir nada no Protheus.',
                      color: AppColors.orange,
                    );
                  }
                  final data = snapshot.data;
                  if (data == null || data.desmontagens.isEmpty) {
                    return const _ReadOnlyEmpty();
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const _HeaderNotice(),
                      const SizedBox(height: 12),
                      for (final item in data.desmontagens)
                        _DismantlingCard(item),
                      if (data.divergencias.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _WarningsBox(data.divergencias),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _HeaderNotice extends StatelessWidget {
  const _HeaderNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F6EC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFE8CC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_rounded, color: AppColors.green),
          const SizedBox(width: 10),
          const _StatusPill('Somente leitura'),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Consulta SD3 para RE7/999 e DE7/499, sem envio ao Protheus.',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DismantlingCard extends StatelessWidget {
  const _DismantlingCard(this.item);

  final ProtheusDismantling item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.documento,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.title,
                  ),
                ),
              ),
              _StatusPill(item.statusLabel),
            ],
          ),
          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.output_rounded,
            label: 'Origem',
            value:
                '${item.produtoOrigemLabel} · local ${_fallback(item.localOrigem)} · ${item.quantidadeOrigem} un',
          ),
          const SizedBox(height: 8),
          _SectionLabel('Componentes retornados'),
          const SizedBox(height: 6),
          for (final component in item.componentesRetornados)
            _ReturnedComponentRow(component),
          if (item.componentesRetornados.isEmpty)
            const _MutedText('Nenhum retorno DE7 encontrado.'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final movement in item.movimentos)
                _MovementChip(movement.label),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReturnedComponentRow extends StatelessWidget {
  const _ReturnedComponentRow(this.component);

  final ProtheusReturnedComponent component;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.subdirectory_arrow_right_rounded, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${component.produtoLabel} · local ${_fallback(component.local)} · ${component.quantidade} un',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.iconMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: value),
              ],
            ),
            style: TextStyle(fontSize: 12, color: AppColors.text),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.green,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MovementChip extends StatelessWidget {
  const _MovementChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bgSegment,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexMono(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textCode,
        ),
      ),
    );
  }
}

class _WarningsBox extends StatelessWidget {
  const _WarningsBox(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Text(
              item,
              style: const TextStyle(fontSize: 12, color: AppColors.danger),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: AppColors.label,
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 12, color: AppColors.muted));
  }
}

class _ReadOnlyEmpty extends StatelessWidget {
  const _ReadOnlyEmpty();

  @override
  Widget build(BuildContext context) {
    return const _StateMessage(
      icon: Icons.inventory_2_outlined,
      title: 'Sem desmontagens recentes',
      detail:
          'Somente leitura: nenhum movimento RE7/DE7 retornou para os filtros atuais.',
      color: AppColors.iconMuted,
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

String _fallback(String value) => value.isEmpty ? '?' : value;
