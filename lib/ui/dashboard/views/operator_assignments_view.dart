import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_request.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart'
    show reportNumber;
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';
import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class CollaboratorsPage extends StatelessWidget {
  const CollaboratorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final actor = context.watch<OperatorAssignmentStore>().currentOperator;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            VettiTopBar(
              title: 'Colaboradores',
              operatorName: actor?.name ?? '',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: const OperatorAssignmentsView(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OperatorAssignmentsView extends StatefulWidget {
  const OperatorAssignmentsView({super.key});

  @override
  State<OperatorAssignmentsView> createState() =>
      _OperatorAssignmentsViewState();
}

class _OperatorAssignmentsViewState extends State<OperatorAssignmentsView> {
  var _selectedUsername =
      OperatorAssignmentStore.assignableOperators.first.username;

  void _assign(
    OperatorAssignmentStore store,
    String username,
    WorkStage stage,
  ) {
    try {
      store.assignStage(username, stage);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a etapa. Tente novamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<OperatorAssignmentStore>();
    final requestStore = context.watch<WarehouseRequestStore>();
    final operators = store.visibleAssignableOperators;
    final currentOperator = store.currentOperator;
    if (currentOperator?.canManageAssignments != true) {
      return const Text(
        'A gestão de colaboradores está disponível apenas aos gestores.',
      );
    }
    if (operators.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WarehouseRequestsPanel(
            assignmentStore: store,
            requestStore: requestStore,
            currentOperator: currentOperator,
          ),
          const SizedBox(height: 14),
          const _Panel(
            child: _PanelTitle(
              icon: Icons.lock_person_rounded,
              title: 'Sem equipe vinculada',
              subtitle:
                  'Este usuario ainda nao possui um setor para gerenciar.',
            ),
          ),
        ],
      );
    }
    final selected = operators.firstWhere(
      (operator) => operator.username == _selectedUsername,
      orElse: () => operators.first,
    );
    final selectedStage = store.stageFor(selected);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        if (compact) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WarehouseRequestsPanel(
                  assignmentStore: store,
                  requestStore: requestStore,
                  currentOperator: currentOperator,
                ),
                const SizedBox(height: 14),
                _TeamSummary(store: store),
                const SizedBox(height: 14),
                _MobileTeamAssignmentPanel(
                  operators: operators,
                  selected: selected,
                  selectedStage: selectedStage,
                  store: store,
                  onOperatorSelect: (username) =>
                      setState(() => _selectedUsername = username),
                  onAssign: (stage) => _assign(store, selected.username, stage),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WarehouseRequestsPanel(
              assignmentStore: store,
              requestStore: requestStore,
              currentOperator: currentOperator,
            ),
            const SizedBox(height: 16),
            _TeamSummary(store: store),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 390,
                  child: _PeoplePanel(
                    operators: operators,
                    selectedUsername: selected.username,
                    store: store,
                    onSelect: (username) =>
                        setState(() => _selectedUsername = username),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _AssignmentPanel(
                    operator: selected,
                    selectedStage: selectedStage,
                    onAssign: (stage) =>
                        _assign(store, selected.username, stage),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _WarehouseRequestsPanel extends StatelessWidget {
  const _WarehouseRequestsPanel({
    required this.assignmentStore,
    required this.requestStore,
    required this.currentOperator,
  });

  final OperatorAssignmentStore assignmentStore;
  final WarehouseRequestStore requestStore;
  final Operator? currentOperator;

  @override
  Widget build(BuildContext context) {
    final area = assignmentStore.currentManagedArea;
    final pending = requestStore.pendingForArea(area);
    final canCreate = requestStore.canCreateManualRequest(area);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final action = _WarehouseRequestCreateButton(
                canCreate: canCreate,
                onPressed: () => _showCreateRequestDialog(context),
              );

              if (constraints.maxWidth < 390) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _PanelTitle(
                      icon: Icons.assignment_turned_in_rounded,
                      title: 'Requisições',
                      subtitle: 'Confirme ou recuse pedidos do seu setor.',
                    ),
                    const SizedBox(height: 12),
                    action,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: _PanelTitle(
                      icon: Icons.assignment_turned_in_rounded,
                      title: 'Requisições de armazém',
                      subtitle:
                          'Confirme ou recuse itens pedidos para o seu setor.',
                    ),
                  ),
                  const SizedBox(width: 12),
                  action,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (pending.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE1EBF2)),
              ),
              child: const Text(
                'Nenhuma requisição pendente.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            for (final request in pending) ...[
              _WarehouseRequestTile(
                request: request,
                currentOperator:
                    requestStore.canHandle(request, currentOperator)
                    ? currentOperator
                    : null,
                onConfirm: () => _confirm(context, request),
                onReject: () => _showRejectDialog(context, request),
              ),
              if (request != pending.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  void _confirm(BuildContext context, WarehouseConfirmationRequest request) {
    final operator = currentOperator;
    if (operator == null) return;
    try {
      requestStore.confirm(request.id, operator);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${request.componentCode} confirmado.')),
      );
    } on StateError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showRejectDialog(
    BuildContext context,
    WarehouseConfirmationRequest request,
  ) async {
    final operator = currentOperator;
    if (operator == null) return;
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _RejectRequestDialog(request: request),
    );
    if (note == null || !context.mounted) return;
    try {
      requestStore.reject(request.id, operator, note);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${request.componentCode} recusado.')),
      );
    } on StateError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showCreateRequestDialog(BuildContext context) async {
    final operator = currentOperator;
    final area = assignmentStore.currentManagedArea;
    if (operator == null || !requestStore.canCreateManualRequest(area)) return;
    final request = await showDialog<_ManualRequestDraft>(
      context: context,
      builder: (_) => _CreateRequestDialog(area: area),
    );
    if (request == null || !context.mounted) return;
    requestStore.createManualRequest(
      productCode: request.productCode,
      productName: request.productName,
      componentCode: request.componentCode,
      componentDescription: request.componentDescription,
      quantity: request.quantity,
      filial: '04',
      orderWarehouse: request.orderWarehouse,
      requestedWarehouse: request.requestedWarehouse,
      requestedBy: operator.name,
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Requisicao criada.')));
  }
}

class _WarehouseRequestCreateButton extends StatelessWidget {
  const _WarehouseRequestCreateButton({
    required this.canCreate,
    required this.onPressed,
  });

  final bool canCreate;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: canCreate
          ? 'Criar requisição'
          : 'Disponível apenas para SMD e Almoxarifado',
      child: ElevatedButton.icon(
        key: const Key('warehouse-request-create'),
        onPressed: canCreate ? onPressed : null,
        icon: const Icon(Icons.add_task_rounded, size: 18),
        label: const Text(
          'Fazer requisição',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE8EEF2),
          disabledForegroundColor: AppColors.muted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _WarehouseRequestTile extends StatelessWidget {
  const _WarehouseRequestTile({
    required this.request,
    required this.currentOperator,
    required this.onConfirm,
    required this.onReject,
  });

  final WarehouseConfirmationRequest request;
  final Operator? currentOperator;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('warehouse-request-${request.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1D490)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4CC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Color(0xFF9A6A00),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.componentCode} - ${request.componentDescription}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${reportNumber(request.quantity)} ${request.unit} · ${request.warehouseLabel} · OP ${request.orderNumber}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pedido por ${request.requestedBy} para ${request.orderWarehouseLabel}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                key: Key('warehouse-request-reject-${request.id}'),
                onPressed: currentOperator == null ? null : onReject,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Recusar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              ElevatedButton.icon(
                key: Key('warehouse-request-confirm-${request.id}'),
                onPressed: currentOperator == null ? null : onConfirm,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Confirmar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF209F58),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RejectRequestDialog extends StatefulWidget {
  const _RejectRequestDialog({required this.request});

  final WarehouseConfirmationRequest request;

  @override
  State<_RejectRequestDialog> createState() => _RejectRequestDialogState();
}

class _RejectRequestDialogState extends State<_RejectRequestDialog> {
  final _controller = TextEditingController();
  var _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recusar requisicao'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.request.componentCode),
          const SizedBox(height: 12),
          TextField(
            key: const Key('warehouse-request-reject-note'),
            controller: _controller,
            minLines: 3,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Explique o saldo incorreto',
              errorText: _showError ? 'A explicacao e obrigatoria.' : null,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          key: const Key('warehouse-request-reject-submit'),
          onPressed: () {
            final note = _controller.text.trim();
            if (note.isEmpty) {
              setState(() => _showError = true);
              return;
            }
            Navigator.pop(context, note);
          },
          child: const Text('Recusar'),
        ),
      ],
    );
  }
}

class _ManualRequestDraft {
  const _ManualRequestDraft({
    required this.productCode,
    required this.productName,
    required this.componentCode,
    required this.componentDescription,
    required this.quantity,
    required this.orderWarehouse,
    required this.requestedWarehouse,
  });

  final String productCode;
  final String productName;
  final String componentCode;
  final String componentDescription;
  final int quantity;
  final String orderWarehouse;
  final String requestedWarehouse;
}

class _CreateRequestDialog extends StatefulWidget {
  const _CreateRequestDialog({required this.area});

  final WorkArea? area;

  @override
  State<_CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends State<_CreateRequestDialog> {
  final _productCodeController = TextEditingController();
  final _productNameController = TextEditingController();
  final _componentCodeController = TextEditingController();
  final _componentDescriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  late String _requestedWarehouse;
  var _orderWarehouse = '05';
  var _showError = false;

  @override
  void initState() {
    super.initState();
    final warehouses = _warehousesForArea(widget.area);
    _requestedWarehouse = warehouses.isEmpty ? '01' : warehouses.first;
  }

  @override
  void dispose() {
    _productCodeController.dispose();
    _productNameController.dispose();
    _componentCodeController.dispose();
    _componentDescriptionController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requestedWarehouses = _warehousesForArea(widget.area);
    final orderWarehouses = WarehouseRouting.operational.map(
      (item) => item.code,
    );

    return AlertDialog(
      title: const Text('Fazer requisicao'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RequestTextField(
                controller: _productCodeController,
                label: 'Codigo do produto',
              ),
              const SizedBox(height: 10),
              _RequestTextField(
                controller: _productNameController,
                label: 'Produto',
              ),
              const SizedBox(height: 10),
              _RequestTextField(
                controller: _componentCodeController,
                label: 'Codigo do item',
              ),
              const SizedBox(height: 10),
              _RequestTextField(
                controller: _componentDescriptionController,
                label: 'Item solicitado',
              ),
              const SizedBox(height: 10),
              _RequestTextField(
                controller: _quantityController,
                label: 'Quantidade',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _requestedWarehouse,
                decoration: const InputDecoration(
                  labelText: 'Armazem que vai confirmar',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final warehouse in requestedWarehouses)
                    DropdownMenuItem(
                      value: warehouse,
                      child: Text(
                        WarehouseRouting.labelForWarehouse(warehouse),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _requestedWarehouse = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _orderWarehouse,
                decoration: const InputDecoration(
                  labelText: 'Armazem destino',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final warehouse in orderWarehouses)
                    DropdownMenuItem(
                      value: warehouse,
                      child: Text(
                        WarehouseRouting.labelForWarehouse(warehouse),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _orderWarehouse = value);
                  }
                },
              ),
              if (_showError) ...[
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Preencha codigo, item e quantidade maior que zero.',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          key: const Key('warehouse-request-create-submit'),
          onPressed: () {
            final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
            if (_componentCodeController.text.trim().isEmpty ||
                _componentDescriptionController.text.trim().isEmpty ||
                quantity <= 0) {
              setState(() => _showError = true);
              return;
            }
            Navigator.pop(
              context,
              _ManualRequestDraft(
                productCode: _productCodeController.text.trim(),
                productName: _productNameController.text.trim(),
                componentCode: _componentCodeController.text.trim(),
                componentDescription: _componentDescriptionController.text
                    .trim(),
                quantity: quantity,
                orderWarehouse: _orderWarehouse,
                requestedWarehouse: _requestedWarehouse,
              ),
            );
          },
          child: const Text('Criar'),
        ),
      ],
    );
  }

  List<String> _warehousesForArea(WorkArea? area) {
    return WarehouseRouting.operational
        .where((target) => area == null || target.area == area)
        .map((target) => target.code)
        .toList();
  }
}

class _RequestTextField extends StatelessWidget {
  const _RequestTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _TeamSummary extends StatelessWidget {
  const _TeamSummary({required this.store});

  final OperatorAssignmentStore store;

  @override
  Widget build(BuildContext context) {
    final total = store.visibleAssignableOperators.length;
    final dashboard = store.visibleDashboardOperators.length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF071D2A), Color(0xFF105071)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summaryTiles = [
            _SummaryTile(label: 'Pessoas', value: '$total'),
            _SummaryTile(label: 'Gestao', value: '$dashboard'),
            _SummaryTile(
              label: 'Setor',
              value: store.currentManagedArea == null ? 'Geral' : '1',
            ),
          ];
          final textBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Equipe e designacoes',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gestao de ${store.currentAreaLabel}. Cada gestor visualiza apenas as pessoas do proprio setor.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                textBlock,
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 10, children: summaryTiles),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: textBlock),
              const SizedBox(width: 14),
              Wrap(spacing: 10, runSpacing: 10, children: summaryTiles),
            ],
          );
        },
      ),
    );
  }
}

class _PeoplePanel extends StatelessWidget {
  const _PeoplePanel({
    required this.operators,
    required this.selectedUsername,
    required this.store,
    required this.onSelect,
  });

  final List<Operator> operators;
  final String selectedUsername;
  final OperatorAssignmentStore store;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.groups_2_rounded,
            title: 'Colaboradores',
            subtitle: 'Selecione uma pessoa para alterar a etapa.',
          ),
          const SizedBox(height: 16),
          for (final area in WorkArea.values) ...[
            _PeopleGroup(
              label: area.label,
              operators: operators
                  .where((operator) => operator.area == area)
                  .toList(),
              selectedUsername: selectedUsername,
              store: store,
              onSelect: onSelect,
            ),
            if (operators.any((operator) => operator.area == area))
              const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class _PeopleGroup extends StatelessWidget {
  const _PeopleGroup({
    required this.label,
    required this.operators,
    required this.selectedUsername,
    required this.store,
    required this.onSelect,
  });

  final String label;
  final List<Operator> operators;
  final String selectedUsername;
  final OperatorAssignmentStore store;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (operators.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textCode,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        for (final operator in operators) ...[
          _PersonRow(
            operator: operator,
            stage: store.stageFor(operator),
            selected: selectedUsername == operator.username,
            onTap: () => onSelect(operator.username),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MobileTeamAssignmentPanel extends StatelessWidget {
  const _MobileTeamAssignmentPanel({
    required this.operators,
    required this.selected,
    required this.selectedStage,
    required this.store,
    required this.onOperatorSelect,
    required this.onAssign,
  });

  final List<Operator> operators;
  final Operator selected;
  final WorkStage selectedStage;
  final OperatorAssignmentStore store;
  final ValueChanged<String> onOperatorSelect;
  final ValueChanged<WorkStage> onAssign;

  @override
  Widget build(BuildContext context) {
    final stages = store.stagesFor(selected);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.groups_2_rounded,
            title: 'Equipe',
            subtitle: 'Escolha a pessoa e onde ela vai trabalhar.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('mobile-operator-selector'),
            initialValue: selected.username,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Colaborador',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            selectedItemBuilder: (context) => [
              for (final operator in operators)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    operator.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            items: [
              for (final operator in operators)
                DropdownMenuItem(
                  value: operator.username,
                  child: Text(
                    operator.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (username) {
              if (username != null) onOperatorSelect(username);
            },
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE1EBF2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(name: selected.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selected.role,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _SoftChip(
                          icon: _stageIcon(selectedStage),
                          label: selectedStage.label,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('mobile-stage-picker'),
              onPressed: stages.isEmpty
                  ? null
                  : () => _showStagePicker(context, stages),
              icon: Icon(_stageIcon(selectedStage), size: 18),
              label: const Text(
                'Alterar etapa',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _PermissionControl(operator: selected),
        ],
      ),
    );
  }

  Future<void> _showStagePicker(
    BuildContext context,
    List<WorkStage> stages,
  ) async {
    final stage = await showModalBottomSheet<WorkStage>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) =>
          _StagePickerSheet(stages: stages, selectedStage: selectedStage),
    );
    if (stage != null) onAssign(stage);
  }
}

class _AssignmentPanel extends StatelessWidget {
  const _AssignmentPanel({
    required this.operator,
    required this.selectedStage,
    required this.onAssign,
  });

  final Operator operator;
  final WorkStage selectedStage;
  final ValueChanged<WorkStage> onAssign;

  @override
  Widget build(BuildContext context) {
    final store = context.read<OperatorAssignmentStore>();
    final stages = store.stagesFor(operator);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(name: operator.name, large: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operator.name,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SoftChip(
                          icon: Icons.alternate_email_rounded,
                          label: operator.username,
                        ),
                        _SoftChip(
                          icon: Icons.verified_user_rounded,
                          label: operator.role,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE1EBF2)),
            ),
            child: Row(
              children: [
                _StageIcon(stage: selectedStage, large: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Etapa atual',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedStage.label,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _PermissionControl(operator: operator),
          const SizedBox(height: 20),
          const Text(
            'Designar para',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final stage in stages)
                _StageButton(
                  stage: stage,
                  selected: stage == selectedStage,
                  onTap: () => onAssign(stage),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PermissionControl extends StatelessWidget {
  const _PermissionControl({required this.operator});
  final Operator operator;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<OperatorAssignmentStore>();
    final level = store.permissionFor(operator);
    final editable = store.canSetPermission(operator);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Acesso ao setor',
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<OperatorPermission>(
              key: ValueKey('permission-${operator.username}'),
              value: level,
              isExpanded: true,
              isDense: true,
              items: [
                for (final permission in OperatorPermission.values)
                  DropdownMenuItem(
                    value: permission,
                    child: Text(permission.label),
                  ),
              ],
              onChanged: !editable
                  ? null
                  : (value) {
                      if (value == null || value == level) return;
                      try {
                        store.setPermission(operator.username, value);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Acesso de ${operator.name} atualizado.',
                            ),
                          ),
                        );
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Não foi possível salvar o acesso. Tente novamente.',
                            ),
                          ),
                        );
                      }
                    },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(switch (level) {
          OperatorPermission.operation =>
            'Trabalha na etapa atribuída, sem consultas ou relatórios.',
          OperatorPermission.consultation =>
            'Também consulta dados e relatórios do seu setor.',
          OperatorPermission.manager => 'Consulta o setor e organiza a equipe.',
        }, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        if (!editable)
          const Text(
            'Acesso definido pelo responsável do setor.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
      ],
    );
  }
}

class _StagePickerSheet extends StatelessWidget {
  const _StagePickerSheet({required this.stages, required this.selectedStage});

  final List<WorkStage> stages;
  final WorkStage selectedStage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6E3EA),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Escolher etapa',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            for (final stage in stages) ...[
              _StagePickerTile(
                stage: stage,
                selected: stage == selectedStage,
                onTap: () => Navigator.pop(context, stage),
              ),
              if (stage != stages.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _StagePickerTile extends StatelessWidget {
  const _StagePickerTile({
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final WorkStage stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _stageColor(stage);
    return Material(
      color: selected ? color.withValues(alpha: 0.1) : const Color(0xFFF8FBFD),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('mobile-stage-${stage.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              _StageIcon(stage: stage),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stage.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: color, size: 21),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.075),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showIcon = constraints.maxWidth >= 120;
        final textBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );

        if (!showIcon) return textBlock;

        return Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: textBlock),
          ],
        );
      },
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.operator,
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final Operator operator;
  final WorkStage stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF7FF) : const Color(0xFFF8FBFD),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE1EBF2),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final veryNarrow = constraints.maxWidth < 150;
              return Row(
                children: [
                  if (!veryNarrow) ...[
                    _Avatar(name: operator.name),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          operator.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stage.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!veryNarrow) _StageIcon(stage: stage),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StageButton extends StatelessWidget {
  const _StageButton({
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final WorkStage stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _stageColor(stage);
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? color : Colors.white,
          foregroundColor: selected ? Colors.white : AppColors.text,
          side: BorderSide(color: selected ? color : const Color(0xFFD8E6EE)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        icon: Icon(_stageIcon(stage), size: 18),
        label: Text(stage.label),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 98,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? math.min(constraints.maxWidth, 220.0)
            : 220.0;

        return SizedBox(
          width: width,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6FA),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Icon(icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textCode,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.large = false});

  final String name;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 58.0 : 36.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0077BD), Color(0xFF74D4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(large ? 18 : 12),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: large ? 18 : 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'VF';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

class _StageIcon extends StatelessWidget {
  const _StageIcon({required this.stage, this.large = false});

  final WorkStage stage;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = _stageColor(stage);
    final size = large ? 48.0 : 34.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: large ? 0.14 : 0.11),
        borderRadius: BorderRadius.circular(large ? 16 : 12),
      ),
      child: Icon(_stageIcon(stage), color: color, size: large ? 24 : 18),
    );
  }
}

Color _stageColor(WorkStage stage) {
  return switch (stage) {
    WorkStage.dashboard => const Color(0xFF0F6B8F),
    WorkStage.smd => const Color(0xFF0E9C8A),
    WorkStage.firmware => AppColors.primary,
    WorkStage.soldering => const Color(0xFFE16A3D),
    WorkStage.testing => const Color(0xFF209F58),
    WorkStage.closing => const Color(0xFF7458D8),
    WorkStage.expedition => const Color(0xFF334B5D),
    WorkStage.warehouse => const Color(0xFF8B6B22),
    WorkStage.support => const Color(0xFF7C3AED),
    WorkStage.tv => const Color(0xFF111827),
  };
}

IconData _stageIcon(WorkStage stage) {
  return switch (stage) {
    WorkStage.dashboard => Icons.dashboard_rounded,
    WorkStage.smd => Icons.developer_board_rounded,
    WorkStage.firmware => Icons.memory_rounded,
    WorkStage.soldering => Icons.precision_manufacturing,
    WorkStage.testing => Icons.fact_check_rounded,
    WorkStage.closing => Icons.inventory_2_rounded,
    WorkStage.expedition => Icons.local_shipping_rounded,
    WorkStage.warehouse => Icons.warehouse_rounded,
    WorkStage.support => Icons.support_agent_rounded,
    WorkStage.tv => Icons.tv_rounded,
  };
}
