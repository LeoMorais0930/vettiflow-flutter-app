import 'package:flutter/material.dart';
import 'solicitacoes_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_dismantlings_page.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_environment_badge.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_inventory_audit_page.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_write_readiness_page.dart';

class FilaProtheusPage extends StatelessWidget {
  const FilaProtheusPage({super.key});

  static const rota = '/fila-protheus';

  @override
  Widget build(BuildContext context) {
    final fila = context.watch<PendingMutationStore>();
    final pendentes = fila.pending;
    final armazenadas = fila.stored;
    final aplicadas = fila.sent;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('Fila do Protheus'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Solicitações ADVPL na API',
            icon: const Icon(Icons.cloud_queue),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SolicitacoesPage()),
            ),
          ),
          IconButton(
            tooltip: 'Desmontagens Protheus',
            icon: const Icon(Icons.call_split_rounded),
            onPressed: () =>
                Navigator.of(context).pushNamed(ProtheusDismantlingsPage.rota),
          ),
          IconButton(
            tooltip: 'Auditoria de estoque Protheus',
            icon: const Icon(Icons.manage_search_rounded),
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(ProtheusInventoryAuditPage.rota),
          ),
          IconButton(
            tooltip: 'Governanca Protheus',
            icon: const Icon(Icons.lock_outline_rounded),
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(ProtheusWriteReadinessPage.rota),
          ),
          if (aplicadas.isNotEmpty)
            TextButton.icon(
              onPressed: fila.clearSent,
              icon: const Icon(Icons.cleaning_services_rounded, size: 18),
              label: const Text('Limpar aplicados'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ResumoFila(
              pendentes: pendentes.length,
              armazenadas: armazenadas.length,
              aplicadas: aplicadas.length,
            ),
            Expanded(
              child: fila.all.isEmpty
                  ? const _FilaVazia()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        if (pendentes.isNotEmpty) ...[
                          const _SecaoFila(
                            'Rascunhos locais sem envio ao Protheus',
                          ),
                          for (final mutacao in pendentes)
                            _CartaoMutacao(
                              mutacao: mutacao,
                              onDescartar: () => fila.discard(mutacao.id),
                            ),
                        ],
                        if (armazenadas.isNotEmpty) ...[
                          const _SecaoFila('Historico local armazenado'),
                          for (final mutacao in armazenadas)
                            _CartaoMutacao(mutacao: mutacao),
                        ],
                        if (aplicadas.isNotEmpty) ...[
                          const _SecaoFila('Historico local finalizado'),
                          for (final mutacao in aplicadas)
                            _CartaoMutacao(mutacao: mutacao),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumoFila extends StatelessWidget {
  const _ResumoFila({
    required this.pendentes,
    required this.armazenadas,
    required this.aplicadas,
  });

  final int pendentes;
  final int armazenadas;
  final int aplicadas;

  @override
  Widget build(BuildContext context) {
    final totalAberto = pendentes + armazenadas;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (narrow) ...[
                _ResumoTexto(
                  totalAberto: totalAberto,
                  pendentes: pendentes,
                  armazenadas: armazenadas,
                  aplicadas: aplicadas,
                ),
                const SizedBox(height: 14),
                const ProtheusEnvironmentBadge(),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: _ResumoTexto(
                        totalAberto: totalAberto,
                        pendentes: pendentes,
                        armazenadas: armazenadas,
                        aplicadas: aplicadas,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const ProtheusEnvironmentBadge(),
                  ],
                ),
              const SizedBox(height: 12),
              const _ReadOnlyNotice(),
            ],
          ),
        );
      },
    );
  }
}

class _ResumoTexto extends StatelessWidget {
  const _ResumoTexto({
    required this.totalAberto,
    required this.pendentes,
    required this.armazenadas,
    required this.aplicadas,
  });

  final int totalAberto;
  final int pendentes;
  final int armazenadas;
  final int aplicadas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Modo somente leitura',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: totalAberto == 0 ? AppColors.green : AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _detailText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }

  String get _detailText {
    final parts = <String>[
      if (pendentes > 0)
        '$pendentes rascunho${pendentes == 1 ? '' : 's'} local${pendentes == 1 ? '' : 'is'}',
      if (armazenadas > 0)
        '$armazenadas registro${armazenadas == 1 ? '' : 's'} local${armazenadas == 1 ? '' : 'is'}',
      if (aplicadas > 0)
        '$aplicadas historico${aplicadas == 1 ? '' : 's'} finalizado${aplicadas == 1 ? '' : 's'}',
    ];
    final prefix = parts.isEmpty ? '' : '${parts.join('; ')}. ';
    return '${prefix}O VettiFlow consulta o Protheus, mas nao envia, aplica ou altera dados no ERP.';
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F6EC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFE8CC)),
      ),
      child: Text(
        'Modo somente leitura: esta tela nao possui envio nem aplicacao no Protheus.',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.green,
        ),
      ),
    );
  }
}

class _SecaoFila extends StatelessWidget {
  const _SecaoFila(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8, left: 2),
      child: Text(
        titulo,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.label,
        ),
      ),
    );
  }
}

class _CartaoMutacao extends StatelessWidget {
  const _CartaoMutacao({required this.mutacao, this.onDescartar});

  final PendingMutation mutacao;
  final VoidCallback? onDescartar;

  Color get _cor => switch (mutacao.status) {
    MutationStatus.pendente => AppColors.orange,
    MutationStatus.enviando => AppColors.primary,
    MutationStatus.armazenado => const Color(0xFF6366F1),
    MutationStatus.enviado => AppColors.green,
    MutationStatus.erro => AppColors.danger,
  };

  IconData get _icone => switch (mutacao.kind) {
    MutationKind.aberturaOp => Icons.note_add_rounded,
    MutationKind.empenho => Icons.inventory_2_rounded,
    MutationKind.transferencia => Icons.swap_horiz_rounded,
    MutationKind.baixaProducao => Icons.precision_manufacturing_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icone, size: 19, color: _cor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mutacao.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mutacao.detalhe,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(texto: mutacao.status.label, cor: _cor),
              if (onDescartar != null)
                IconButton(
                  tooltip: 'Descartar',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppColors.iconMuted,
                  onPressed: onDescartar,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _MetaChip(mutacao.autor),
              _MetaChip('Filial ${mutacao.filial}'),
              _MetaChip(_quando(mutacao.criadoEm)),
              if (mutacao.protheusRef != null)
                _MetaChip('Ref ${mutacao.protheusRef}'),
            ],
          ),
          if (mutacao.erro != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mutacao.erro!,
                style: TextStyle(fontSize: 11.5, color: AppColors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _quando(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 98),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: cor,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(fontSize: 11, color: AppColors.smallText),
    );
  }
}

class _FilaVazia extends StatelessWidget {
  const _FilaVazia();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_done_rounded,
              size: 44,
              color: AppColors.iconMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Nada pendente para o Protheus.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              'O Protheus esta em modo somente leitura; movimentos aparecem aqui apenas como rascunho local quando existirem.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.smallText),
            ),
          ],
        ),
      ),
    );
  }
}
