import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/protheus_write_readiness.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_write_readiness_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_environment_badge.dart';

class ProtheusWriteReadinessPage extends StatefulWidget {
  const ProtheusWriteReadinessPage({super.key});

  static const rota = '/governanca-protheus';

  @override
  State<ProtheusWriteReadinessPage> createState() =>
      _ProtheusWriteReadinessPageState();
}

class _ProtheusWriteReadinessPageState
    extends State<ProtheusWriteReadinessPage> {
  Future<ProtheusWriteReadinessSnapshot>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context
        .read<ProtheusWriteReadinessRepository?>()
        ?.fetchReadiness();
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('Governanca Protheus'),
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
            ? const _StateMessage(
                icon: Icons.lock_outline_rounded,
                title: 'Escrita desabilitada',
                detail: 'Somente leitura',
                color: AppColors.green,
              )
            : FutureBuilder<ProtheusWriteReadinessSnapshot>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _StateMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Governanca indisponivel',
                      detail:
                          'A consulta falhou sem criar, alterar ou excluir nada no Protheus.',
                      color: AppColors.orange,
                    );
                  }
                  final data = snapshot.data;
                  if (data == null) {
                    return const _StateMessage(
                      icon: Icons.lock_outline_rounded,
                      title: 'Escrita desabilitada',
                      detail: 'Somente leitura',
                      color: AppColors.green,
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _StatusPanel(data),
                      const SizedBox(height: 12),
                      _ListPanel(
                        title: 'Operacoes bloqueadas',
                        icon: Icons.block_rounded,
                        items: data.blockedOperations,
                      ),
                      const SizedBox(height: 12),
                      _ListPanel(
                        title: 'Pendências da conexão',
                        icon: Icons.rule_rounded,
                        items: data.futureRequirements,
                      ),
                      const SizedBox(height: 12),
                      _ListPanel(
                        title: 'Rotinas candidatas',
                        icon: Icons.manage_search_rounded,
                        items: data.candidateRoutines,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel(this.data);

  final ProtheusWriteReadinessSnapshot data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              Expanded(
                child: Text(
                  data.readOnly
                      ? 'Somente leitura disponível'
                      : 'Integração DEV',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.statusLabel,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Base ${data.database.isEmpty ? '?' : data.database}. ${data.writeAvailable ? 'Abertura de OP exige autenticação e confirmação no serviço Protheus.' : 'A gravação ainda depende da conexão com a rotina do Protheus. As consultas continuam disponíveis.'}',
            style: const TextStyle(fontSize: 12, color: AppColors.textStrong),
          ),
        ],
      ),
    );
  }
}

class _ListPanel extends StatelessWidget {
  const _ListPanel({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items) _GovernanceChip(item),
              if (items.isEmpty) const _GovernanceChip('Nada informado'),
            ],
          ),
        ],
      ),
    );
  }
}

class _GovernanceChip extends StatelessWidget {
  const _GovernanceChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.bgSegment,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
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
