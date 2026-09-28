import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart'
    show reportDate;
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/read_period_filter.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

class WarehouseReleasePage extends StatefulWidget {
  const WarehouseReleasePage({super.key});
  @override
  State<WarehouseReleasePage> createState() => _WarehouseReleasePageState();
}

class _WarehouseReleasePageState extends State<WarehouseReleasePage> {
  String _query = '';
  DateTimeRange? _period;
  int _page = 0;
  bool _busy = false;
  bool _history = false;
  DateTime _date(ProductionOrderFlow o) =>
      _history ? o.warehouseReleases.last.at : o.createdAt;
  @override
  Widget build(BuildContext context) {
    final actor = context.watch<OperatorAssignmentStore>().currentOperator;
    final flow = context.watch<ProductionFlowStore>();
    final materials = context.watch<WarehouseRequestStore>();
    final allowed = actor != null && actor.canUseSector(AppSector.warehouse);
    final rows =
        flow.orders
            .where(
              (o) => _history
                  ? o.warehouseReleases.isNotEmpty
                  : o.currentStage == ProductionStage.warehouse,
            )
            .where(
              (o) =>
                  '${o.number} ${o.productLabel}'.toLowerCase().contains(
                    _query.toLowerCase(),
                  ) &&
                  (_period == null ||
                      !_date(o).isBefore(_period!.start) &&
                          _date(o).isBefore(
                            DateTime(
                              _period!.end.year,
                              _period!.end.month,
                              _period!.end.day + 1,
                            ),
                          )),
            )
            .toList()
          ..sort((a, b) => _date(b).compareTo(_date(a)));
    final pages = ((rows.length + 19) ~/ 20).clamp(1, 1000000);
    final page = _page.clamp(0, pages - 1);
    return LayoutBuilder(
      builder: (context, c) => Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            VettiTopBar(
              title: 'Almoxarifado',
              operatorName: actor?.name ?? 'Consulta',
              operatorRole: 'Liberação de OPs',
              compact: c.maxWidth < 920,
            ),
            Expanded(
              child: !allowed
                  ? const Center(
                      child: Text(
                        'Entre com uma conta do almoxarifado ou de gestão.',
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Voltar',
                                onPressed: () => Navigator.canPop(context)
                                    ? Navigator.pop(context)
                                    : Navigator.pushReplacementNamed(
                                        context,
                                        actor.canView(AppSector.warehouse)
                                            ? '/almoxarifado'
                                            : actor.homeRoute,
                                      ),
                                icon: const Icon(Icons.arrow_back),
                              ),
                              const Expanded(
                                child: Text(
                                  'Liberação de OPs',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.title,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Pedidos de materiais',
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  '/almoxarifado/materiais',
                                ),
                                icon: const Icon(Icons.inventory_2_outlined),
                              ),
                            ],
                          ),
                          const Text(
                            'Liberação local para a próxima etapa programada. Protheus somente leitura.',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('A liberar'),
                                selected: !_history,
                                onSelected: (_) => setState(() {
                                  _history = false;
                                  _page = 0;
                                }),
                              ),
                              ChoiceChip(
                                label: const Text('Liberadas'),
                                selected: _history,
                                onSelected: (_) => setState(() {
                                  _history = true;
                                  _page = 0;
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Buscar OP ou produto',
                            ),
                            onChanged: (v) => setState(() {
                              _query = v;
                              _page = 0;
                            }),
                          ),
                          const SizedBox(height: 8),
                          ReadPeriodFilter(
                            start: _period?.start,
                            end: _period?.end,
                            dateLabel: _history
                                ? 'Liberação da OP'
                                : 'Criação da OP',
                            onChanged: (v) => setState(() {
                              _period = v;
                              _page = 0;
                            }),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: rows.isEmpty
                                ? Center(
                                    child: Text(
                                      _history
                                          ? 'Nenhuma liberação neste período.'
                                          : 'Nenhuma OP aguardando liberação.',
                                    ),
                                  )
                                : ListView(
                                    children: [
                                      for (final o
                                          in rows.skip(page * 20).take(20))
                                        Card(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Text(
                                                  '${o.number} · ${o.productLabel}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                Text(o.quantityLabel),
                                                if (_history)
                                                  for (final release
                                                      in o.warehouseReleases)
                                                    Text(
                                                      '${reportDate(release.at.toIso8601String())} · ${release.operatorName} → ${release.destination.label}',
                                                    ),
                                                if (!_history)
                                                  Text(
                                                    'Próxima etapa: ${o.nextStageLabel}',
                                                  ),
                                                if (!_history)
                                                  Text(
                                                    '${materials.requests.where((r) => r.orderNumber == o.number && !r.manual && r.remainingQuantity > 0).length} pedidos de material ainda não entregues',
                                                  ),
                                                const SizedBox(height: 8),
                                                if (!_history &&
                                                    (actor.area ==
                                                            WorkArea
                                                                .warehouse ||
                                                        actor.area ==
                                                                WorkArea
                                                                    .system &&
                                                            actor
                                                                .canManageAssignments))
                                                  FilledButton(
                                                    onPressed: _busy
                                                        ? null
                                                        : () => _release(
                                                            o,
                                                            actor,
                                                          ),
                                                    child: Text(
                                                      'Liberar para ${o.nextStageLabel}',
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: page == 0
                                    ? null
                                    : () => setState(() => _page = page - 1),
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Text('${page + 1} / $pages'),
                              IconButton(
                                onPressed: page + 1 >= pages
                                    ? null
                                    : () => setState(() => _page = page + 1),
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _release(ProductionOrderFlow order, Operator actor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liberar OP?'),
        content: Text(
          '${order.number} · ${order.quantityLabel}\nPróxima: ${order.nextStageLabel}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Liberar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await context.read<ProductionFlowStore>().releaseWarehouseOrder(
        order.number,
        operator: actor,
        requests: context.read<WarehouseRequestStore>().requests,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OP liberada no VettiFlow.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message
                  : 'Não foi possível salvar a liberação.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
