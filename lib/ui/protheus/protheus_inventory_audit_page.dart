import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/protheus_inventory_audit.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_inventory_audit_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_environment_badge.dart';

class ProtheusInventoryAuditPage extends StatefulWidget {
  const ProtheusInventoryAuditPage({super.key});

  static const rota = '/auditoria-estoque-protheus';

  @override
  State<ProtheusInventoryAuditPage> createState() =>
      _ProtheusInventoryAuditPageState();
}

class _ProtheusInventoryAuditPageState
    extends State<ProtheusInventoryAuditPage> {
  Future<ProtheusInventoryAuditSnapshot>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context
        .read<ProtheusInventoryAuditRepository?>()
        ?.fetchAuditMovements(limit: 50);
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('Auditoria de estoque Protheus'),
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
            : FutureBuilder<ProtheusInventoryAuditSnapshot>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _StateMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Nao foi possivel ler auditoria',
                      detail:
                          'A consulta falhou sem criar, alterar ou excluir nada no Protheus.',
                      color: AppColors.orange,
                    );
                  }
                  final data = snapshot.data;
                  if (data == null || data.movimentos.isEmpty) {
                    return const _ReadOnlyEmpty();
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const _HeaderNotice(),
                      if (data.resumoPorTipo.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SummaryWrap(data.resumoPorTipo),
                      ],
                      const SizedBox(height: 12),
                      for (final item in data.movimentos) _AuditCard(item),
                      if (data.pendenciasPesquisa.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _ResearchPendingBox(data.pendenciasPesquisa),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_rounded, color: AppColors.green),
              const SizedBox(width: 10),
              Text(
                'Somente leitura',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Consulta SD3 para ER0/999, DE1/499, DE0/400 e RE0/501.',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryWrap extends StatelessWidget {
  const _SummaryWrap(this.items);

  final List<ProtheusInventoryAuditSummary> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          _SummaryChip('${item.tipoLabel}: ${item.quantidadeMovimentos}'),
      ],
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard(this.item);

  final ProtheusInventoryAuditMovement item;

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
              _MovementChip(item.label),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.tipoLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.title,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.receipt_long_rounded,
            label: 'Documento',
            value:
                '${_fallback(item.documento)} · OP ${_fallback(item.op)} · ${_fallback(item.data)}',
          ),
          const SizedBox(height: 7),
          _InfoLine(
            icon: Icons.inventory_2_rounded,
            label: 'Produto',
            value:
                '${item.produtoLabel} · local ${_fallback(item.local)} · ${item.quantidade} un',
          ),
          const SizedBox(height: 7),
          _InfoLine(
            icon: Icons.person_search_rounded,
            label: 'Auditoria',
            value:
                '${_fallback(item.usuario)} · motivo ${_fallback(item.motivo)}',
          ),
          if (item.observacao.isNotEmpty) ...[
            const SizedBox(height: 7),
            _InfoLine(
              icon: Icons.notes_rounded,
              label: 'Observacao',
              value: item.observacao,
            ),
          ],
        ],
      ),
    );
  }
}

class _ResearchPendingBox extends StatelessWidget {
  const _ResearchPendingBox(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pendencias de pesquisa',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.orangeText,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Text(
              item,
              style: const TextStyle(fontSize: 12, color: AppColors.orangeText),
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.text,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReadOnlyEmpty extends StatelessWidget {
  const _ReadOnlyEmpty();

  @override
  Widget build(BuildContext context) {
    return const _StateMessage(
      icon: Icons.manage_search_rounded,
      title: 'Sem movimentos especiais recentes',
      detail:
          'Somente leitura: nenhum ER0/DE1/DE0/RE0 retornou para os filtros atuais.',
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
