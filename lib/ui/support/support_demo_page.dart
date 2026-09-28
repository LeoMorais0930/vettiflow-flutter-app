import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/layout/app_breakpoints.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

class SupportOrder {
  const SupportOrder({
    required this.number,
    required this.product,
    required this.defectCode,
    required this.defect,
    required this.quantity,
    required this.origin,
    required this.status,
  });

  final String number;
  final String product;
  final String defectCode;
  final String defect;
  final String quantity;
  final String origin;
  final String status;
}

/// Protótipo anterior, preservado como referência. Não faz parte das rotas.
class SupportDemoPage extends StatefulWidget {
  const SupportDemoPage({super.key});

  @override
  State<SupportDemoPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportDemoPage> {
  var _selectedIndex = 0;
  var _conferenceStatus = 'Aguardando';

  List<SupportOrder> _supportOrdersFrom(List<ProductionOrderFlow> orders) {
    return [
      for (final order in orders)
        if (order.testDefects.isNotEmpty)
          for (final defect in order.testDefects)
            SupportOrder(
              number: order.number,
              product: order.productLabel,
              defectCode: defect.code,
              defect: defect.title,
              quantity: '${defect.quantity} un',
              origin: ProductionStage.testing.label,
              status: _supportStatus(order),
            ),
    ];
  }

  List<SupportOrder> _currentSupportOrders() =>
      _supportOrdersFrom(context.read<ProductionFlowStore>().orders);

  SupportOrder? _selectedOrder(List<SupportOrder> orders) {
    if (orders.isEmpty) return null;
    final index = _selectedIndex.clamp(0, orders.length - 1).toInt();
    return orders[index];
  }

  void _startConference() {
    setState(() => _conferenceStatus = 'Em conferencia');
  }

  void _pauseConference() {
    setState(() => _conferenceStatus = 'Pausada');
  }

  Future<void> _confirmConference() async {
    final order = _selectedOrder(_currentSupportOrders());
    if (order == null) return;
    final confirmed = await showSupportConfirmDialog(context, order);
    if (!mounted || confirmed != true) return;
    setState(() => _conferenceStatus = 'Confirmada');
  }

  Future<void> _requestItems() async {
    final order = _selectedOrder(_currentSupportOrders());
    if (order == null) return;
    await showSupportRequestDialog(context, order);
  }

  @override
  Widget build(BuildContext context) {
    final orders = _supportOrdersFrom(
      context.watch<ProductionFlowStore>().orders,
    );
    final selectedIndex = orders.isEmpty
        ? 0
        : _selectedIndex.clamp(0, orders.length - 1).toInt();
    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = constraints.maxWidth >= 1180
            ? AppFormFactor.expanded
            : AppBreakpoints.fromWidth(constraints.maxWidth);
        final isMobile = formFactor != AppFormFactor.expanded;

        if (isMobile) {
          return _MobileSupportLayout(
            orders: orders,
            selectedIndex: selectedIndex,
            conferenceStatus: _conferenceStatus,
            onSelect: (index) => setState(() => _selectedIndex = index),
            onStart: _startConference,
            onPause: _pauseConference,
            onConfirm: _confirmConference,
            onRequest: _requestItems,
          );
        }

        return _DesktopSupportLayout(
          orders: orders,
          selectedIndex: selectedIndex,
          conferenceStatus: _conferenceStatus,
          onSelect: (index) => setState(() => _selectedIndex = index),
          onStart: _startConference,
          onPause: _pauseConference,
          onConfirm: _confirmConference,
          onRequest: _requestItems,
        );
      },
    );
  }

  String _supportStatus(ProductionOrderFlow order) {
    if (order.currentStage == ProductionStage.completed ||
        order.currentStage == ProductionStage.storage) {
      return 'Concluida';
    }
    return 'Aguardando';
  }
}

class _DesktopSupportLayout extends StatelessWidget {
  const _DesktopSupportLayout({
    required this.orders,
    required this.selectedIndex,
    required this.conferenceStatus,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onConfirm,
    required this.onRequest,
  });

  final List<SupportOrder> orders;
  final int selectedIndex;
  final String conferenceStatus;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onConfirm;
  final VoidCallback onRequest;

  SupportOrder? get selectedOrder =>
      orders.isEmpty ? null : orders[selectedIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          VettiTopBar(
            title: 'Suporte Tecnico',
            operatorName:
                context
                    .watch<OperatorAssignmentStore>()
                    .currentOperator
                    ?.name ??
                'Operador',
            operatorRole: 'Suporte',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 46, 40, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.maxContentWidth,
                    minWidth: 1040,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 390,
                        child: _SupportQueue(
                          orders: orders,
                          selectedIndex: selectedIndex,
                          onSelect: onSelect,
                        ),
                      ),
                      const SizedBox(width: 72),
                      Expanded(
                        child: selectedOrder == null
                            ? const _EmptySupportState()
                            : _SupportDetails(
                                order: selectedOrder!,
                                conferenceStatus: conferenceStatus,
                                onStart: onStart,
                                onPause: onPause,
                                onConfirm: onConfirm,
                                onRequest: onRequest,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileSupportLayout extends StatelessWidget {
  const _MobileSupportLayout({
    required this.orders,
    required this.selectedIndex,
    required this.conferenceStatus,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onConfirm,
    required this.onRequest,
  });

  final List<SupportOrder> orders;
  final int selectedIndex;
  final String conferenceStatus;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onConfirm;
  final VoidCallback onRequest;

  SupportOrder? get selectedOrder =>
      orders.isEmpty ? null : orders[selectedIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      body: SafeArea(
        child: Center(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 430),
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.pageBackground,
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                VettiTopBar(
                  title: 'Suporte Tecnico',
                  operatorName:
                      context
                          .watch<OperatorAssignmentStore>()
                          .currentOperator
                          ?.name ??
                      'Operador',
                  compact: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: _SupportHeader(compact: true),
                        ),
                        const SizedBox(height: 18),
                        if (orders.isEmpty)
                          const _EmptySupportState(compact: true)
                        else ...[
                          for (var i = 0; i < orders.length; i++) ...[
                            _SupportCard(
                              order: orders[i],
                              selected: i == selectedIndex,
                              compact: true,
                              onTap: () => onSelect(i),
                            ),
                            if (i < orders.length - 1)
                              const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 24),
                          _SupportDefectPanel(order: selectedOrder!),
                          const SizedBox(height: 18),
                          _SupportActions(
                            compact: true,
                            onStart: onStart,
                            onPause: onPause,
                            onConfirm: onConfirm,
                            onRequest: onRequest,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Status: $conferenceStatus',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportQueue extends StatelessWidget {
  const _SupportQueue({
    required this.orders,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<SupportOrder> orders;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SupportHeader(),
        const SizedBox(height: 38),
        for (var i = 0; i < orders.length; i++) ...[
          _SupportCard(
            order: orders[i],
            selected: i == selectedIndex,
            onTap: () => onSelect(i),
          ),
          if (i < orders.length - 1) const SizedBox(height: 23),
        ],
      ],
    );
  }
}

class _SupportHeader extends StatelessWidget {
  const _SupportHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OPs com defeito',
          style: TextStyle(
            color: AppColors.text,
            fontSize: compact ? 24 : 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        Text(
          compact
              ? 'Recebidas do teste.'
              : 'Recebe OPs que contem defeito apontado pelo teste da producao.',
          style: TextStyle(color: AppColors.muted, fontSize: compact ? 13 : 16),
        ),
      ],
    );
  }
}

class _EmptySupportState extends StatelessWidget {
  const _EmptySupportState({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.build_circle_outlined,
            color: AppColors.iconMuted,
            size: compact ? 34 : 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhuma OP com defeito.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 18 : 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'As OPs aparecem aqui quando o teste registrar defeitos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 12.5 : 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportDetails extends StatelessWidget {
  const _SupportDetails({
    required this.order,
    required this.conferenceStatus,
    required this.onStart,
    required this.onPause,
    required this.onConfirm,
    required this.onRequest,
  });

  final SupportOrder order;
  final String conferenceStatus;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onConfirm;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.number,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.product,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 38),
          _SupportMetrics(order: order, conferenceStatus: conferenceStatus),
          const SizedBox(height: 32),
          _SupportDefectPanel(order: order),
          const SizedBox(height: 54),
          const Text(
            'Acoes da conferencia',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'O suporte confere o defeito, pode requisitar componentes e confirma com PIN.',
            style: TextStyle(color: AppColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 36),
          _SupportActions(
            onStart: onStart,
            onPause: onPause,
            onConfirm: onConfirm,
            onRequest: onRequest,
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.order,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final SupportOrder order;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 10 : 8);

    return Material(
      color: selected ? const Color(0xFFEAF7FF) : Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: compact ? 118 : 126),
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 20,
            compact ? 14 : 16,
            compact ? 16 : 20,
            compact ? 13 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: compact ? 17 : 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                order.product,
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: compact ? 13 : 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: compact ? 10 : 12),
              Text(
                '${order.defectCode} ${order.defect} · ${order.quantity}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.smallText,
                  fontSize: compact ? 11 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportMetrics extends StatelessWidget {
  const _SupportMetrics({required this.order, required this.conferenceStatus});

  final SupportOrder order;
  final String conferenceStatus;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Defeito', order.defectCode),
      ('Recebido', order.quantity),
      ('Origem', order.origin),
      ('Conferencia', conferenceStatus),
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 18,
      children: [
        for (final metric in metrics)
          _MetricCard(
            label: metric.$1,
            value: metric.$2,
            wide: metric.$1 == 'Conferencia',
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.wide,
  });

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 205 : 160,
      constraints: const BoxConstraints(minHeight: 98),
      padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE4EDF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.label,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportDefectPanel extends StatelessWidget {
  const _SupportDefectPanel({required this.order});

  final SupportOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF4D7A7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Defeito recebido do teste',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${order.defectCode} - ${order.defect}: ${order.quantity}',
            style: const TextStyle(color: AppColors.orangeText),
          ),
          const SizedBox(height: 6),
          const Text(
            'Essa quantidade fica armazenada no suporte ate decisao de reparo.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _SupportActions extends StatelessWidget {
  const _SupportActions({
    required this.onStart,
    required this.onPause,
    required this.onConfirm,
    required this.onRequest,
    this.compact = false,
  });

  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onConfirm;
  final VoidCallback onRequest;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acoes',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          _ActionButton(
            label: 'Iniciar conferencia',
            onPressed: onStart,
            fillColor: AppColors.primary,
            foregroundColor: Colors.white,
            width: double.infinity,
            height: 54,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Pausar',
                  onPressed: onPause,
                  foregroundColor: AppColors.orangeText,
                  borderColor: AppColors.orange,
                  height: 54,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ActionButton(
                  label: 'Confirmar',
                  onPressed: onConfirm,
                  foregroundColor: AppColors.green,
                  borderColor: AppColors.green,
                  height: 54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: 'Fazer requisicao',
            onPressed: onRequest,
            foregroundColor: AppColors.primary,
            borderColor: AppColors.primary,
            width: double.infinity,
            height: 54,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            _ActionButton(
              label: 'Iniciar conferencia',
              onPressed: onStart,
              fillColor: AppColors.primary,
              foregroundColor: Colors.white,
              width: 270,
            ),
            _ActionButton(
              label: 'Pausar conferencia',
              onPressed: onPause,
              foregroundColor: AppColors.orangeText,
              borderColor: AppColors.orange,
              width: 270,
            ),
            _ActionButton(
              label: 'Confirmar conferencia',
              onPressed: onConfirm,
              foregroundColor: AppColors.green,
              borderColor: AppColors.green,
              width: 290,
            ),
          ],
        ),
        const SizedBox(height: 22),
        _ActionButton(
          label: 'Fazer requisicao ao almoxarifado',
          onPressed: onRequest,
          foregroundColor: AppColors.primary,
          borderColor: AppColors.primary,
          width: 360,
          height: 62,
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
    this.fillColor,
    this.borderColor,
    this.width,
    this.height = 74,
  });

  final String label;
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
            color: borderColor ?? fillColor ?? Colors.white,
            width: 2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

Future<bool?> showSupportConfirmDialog(
  BuildContext context,
  SupportOrder order,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmar conferencia'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${order.number} · ${order.defectCode} ${order.defect}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            const TextField(
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(hintText: 'Observacao opcional'),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(labelText: 'PIN', hintText: '7777'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
}

Future<void> showSupportRequestDialog(
  BuildContext context,
  SupportOrder order,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Requisicao ao almoxarifado'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${order.number} · ${order.defectCode} ${order.defect}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Item',
                hintText: 'Ex.: Conector barra 4 vias',
              ),
            ),
            const SizedBox(height: 14),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Quantidade',
                hintText: 'Ex.: 12 un',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Enviar requisicao'),
        ),
      ],
    ),
  );
}
