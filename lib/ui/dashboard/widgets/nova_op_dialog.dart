import 'dart:async';
import 'package:vetti_flow_1_0/ui/production/production_route_field.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/protheus_product_lookup.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class NovaOpDialog extends StatefulWidget {
  final List<String> produtos;
  final List<String> responsaveis;
  final ValueChanged<NovaOrdemDTO> onCreate;
  final Future<ProtheusProductLookup?> Function(String code)? onLookupProduto;
  final Future<List<ProtheusProduct>> Function(String query)? onSearchProdutos;
  final String? currentOperatorName;
  final VoidCallback onClose;
  final bool isDesktop;

  const NovaOpDialog({
    super.key,
    required this.produtos,
    required this.responsaveis,
    required this.onCreate,
    this.onLookupProduto,
    this.onSearchProdutos,
    this.currentOperatorName,
    required this.onClose,
    this.isDesktop = true,
  });

  @override
  State<NovaOpDialog> createState() => _NovaOpDialogState();
}

class _NovaOpDialogState extends State<NovaOpDialog> {
  static const _prioridades = ['Baixa', 'Media', 'Alta'];
  static const _filiais = ['04'];

  late String _produto;
  late final TextEditingController _codigoController;
  late final TextEditingController _produtoController;
  late final TextEditingController _prazoController;
  late final TextEditingController _pinController;
  late final FocusNode _codigoFocusNode;
  Timer? _lookupDebounce;
  ProtheusProductLookup? _lookup;
  String? _lookupMessage;
  var _lookupRequest = 0;
  var _isLookingUp = false;
  int _qtd = 50;
  List<ProductionStage> _plannedStages = [...ProductionRouteField.available];
  bool get _canPlanProduction => [
    'tatiane',
    'andressa',
  ].contains(widget.currentOperatorName?.trim().toLowerCase());
  String _prazo = '';
  String _prioridade = 'Media';
  String _filial = '04';
  String _armazem = '';
  String? _pinError;
  var _showAllCommitments = false;
  final Set<String> _openComponentWarehousePickers = {};
  final Set<String> _confirmedComponentWarehouseChoices = {};

  @override
  void initState() {
    super.initState();
    _produto = widget.produtos.isNotEmpty ? widget.produtos.first : '';
    _codigoController = TextEditingController();
    _produtoController = TextEditingController(text: _produto);
    _prazoController = TextEditingController();
    _pinController = TextEditingController();
    _codigoFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _codigoController.dispose();
    _produtoController.dispose();
    _prazoController.dispose();
    _pinController.dispose();
    _codigoFocusNode.dispose();
    super.dispose();
  }

  bool get _isValid =>
      (widget.onLookupProduto == null
          ? _produto.isNotEmpty
          : _lookup != null) &&
      _qtd > 0 &&
      _componentsNeedingWarehouseConfirmation.isEmpty;

  bool get _requiresProtheusPin => _lookup?.components.isNotEmpty ?? false;

  void _submit() {
    if (!_isValid) return;
    final pin = _pinController.text.trim();
    if (_requiresProtheusPin && pin.isEmpty) {
      setState(() => _pinError = 'Informe o PIN para movimentar o Protheus.');
      return;
    }
    widget.onCreate(
      NovaOrdemDTO(
        produto: _lookup?.label ?? _produto,
        productCode: _lookup?.product.code,
        productName: _lookup?.product.description,
        productUnit: _lookup?.product.unit,
        components: _lookup?.components ?? const [],
        smdReleaseOrders: _lookup?.smdReleaseOrders ?? const [],
        filial: _filial,
        armazem: _armazem,
        openedBy: widget.currentOperatorName,
        operatorPin: pin.isEmpty ? null : pin,
        qtd: _qtd,
        responsavel: '',
        prazo: _prazo.trim().isEmpty ? null : _prazo.trim(),
        prioridade: _prioridade,
        plannedStages:
            _canPlanProduction && (_armazem.isEmpty || _armazem == '05')
            ? _plannedStages
            : const [],
      ),
    );
  }

  void _scheduleLookup(String value) {
    _lookupDebounce?.cancel();
    final code = value.trim();
    if (code.isEmpty) {
      setState(() {
        _lookup = null;
        _lookupMessage = null;
        _produtoController.clear();
        _isLookingUp = false;
        _showAllCommitments = false;
        _openComponentWarehousePickers.clear();
        _confirmedComponentWarehouseChoices.clear();
      });
      return;
    }
    _lookupDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _lookupProduto(code),
    );
  }

  Future<void> _lookupProduto(String code) async {
    final lookup = widget.onLookupProduto;
    if (lookup == null) return;
    final request = ++_lookupRequest;
    setState(() {
      _isLookingUp = true;
      _lookupMessage = null;
    });
    try {
      final result = await lookup(code);
      if (!mounted || request != _lookupRequest) return;
      setState(() {
        if (result != null) {
          final allowedWarehouses = _orderWarehousesForCurrentOperator(result);
          final currentWarehouse = WarehouseRouting.normalizeCode(_armazem);
          final defaultWarehouse = WarehouseRouting.normalizeCode(
            result.defaultWarehouse,
          );
          final selectedWarehouse =
              _armazem.isNotEmpty &&
                  allowedWarehouses.contains(currentWarehouse)
              ? currentWarehouse
              : defaultWarehouse.isNotEmpty &&
                    allowedWarehouses.contains(defaultWarehouse)
              ? defaultWarehouse
              : allowedWarehouses.isNotEmpty
              ? allowedWarehouses.first
              : '';
          _lookup = selectedWarehouse.isEmpty
              ? result
              : result.selectWarehouse(selectedWarehouse);
          _filial = result.filial;
          _armazem = selectedWarehouse;
          _produto = result.label;
          _produtoController.text = result.label;
          _lookupMessage = null;
          _showAllCommitments = false;
          _openComponentWarehousePickers.clear();
          _confirmedComponentWarehouseChoices.clear();
        } else {
          _lookup = null;
          _produtoController.clear();
          _lookupMessage = code.contains('-')
              ? 'Código não encontrado no Protheus.'
              : 'Selecione um código completo da lista do Protheus.';
          _showAllCommitments = false;
          _openComponentWarehousePickers.clear();
          _confirmedComponentWarehouseChoices.clear();
        }
        _isLookingUp = false;
      });
    } catch (e, st) {
      debugPrint('Erro ao consultar produto no Protheus/FastAPI: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted || request != _lookupRequest) return;
      setState(() {
        _lookup = null;
        _produtoController.clear();
        _lookupMessage = 'Não consegui consultar o Protheus/FastAPI agora.';
        _isLookingUp = false;
        _showAllCommitments = false;
        _openComponentWarehousePickers.clear();
        _confirmedComponentWarehouseChoices.clear();
      });
    }
  }

  String? _productionGateMessage() {
    final lookup = _lookup;
    if (lookup == null) return null;
    if (!lookup.isReleasedBySmd) {
      return 'Aviso: produto sem OP SMD vinculada no Protheus.';
    }
    final shortages = lookup.stockShortagesFor(_qtd);
    if (shortages.isEmpty) return null;
    final shortage = shortages.first;
    return 'Aviso: estoque insuficiente em ${shortage.component.code}: precisa '
        '${shortage.requiredQuantity}, disponivel ${shortage.availableQuantity}.';
  }

  Future<Iterable<ProtheusProduct>> _searchProdutos(
    TextEditingValue value,
  ) async {
    final query = value.text.trim();
    if (query.isEmpty) return const [];
    final search = widget.onSearchProdutos;
    if (search != null) return search(query);

    final normalized = query.toLowerCase();
    return widget.produtos
        .where((produto) => produto.toLowerCase().contains(normalized))
        .take(12)
        .map(_productFromLabel);
  }

  void _selectProduct(ProtheusProduct product) {
    _codigoController.text = product.code;
    _codigoController.selection = TextSelection.collapsed(
      offset: product.code.length,
    );
    _lookupProduto(product.code);
  }

  ProtheusProduct _productFromLabel(String label) {
    final parts = label.split(' - ');
    return ProtheusProduct(
      code: parts.first.trim(),
      description: parts.length > 1 ? parts.sublist(1).join(' - ') : label,
      filial: _filial,
      type: '',
      unit: '',
      group: '',
    );
  }

  void _selectWarehouse(String? value) {
    if (value == null) return;
    final warehouse = WarehouseRouting.normalizeCode(value);
    if (!WarehouseRouting.canOperatorCreateOrder(
      widget.currentOperatorName,
      warehouse,
    )) {
      return;
    }
    setState(() {
      _armazem = warehouse;
      _lookup = _lookup?.selectWarehouse(warehouse);
      _openComponentWarehousePickers.clear();
      _confirmedComponentWarehouseChoices.clear();
    });
  }

  void _selectComponentWarehouse(String componentCode, String? value) {
    if (value == null) return;
    final warehouse = WarehouseRouting.normalizeCode(value);
    if (!WarehouseRouting.canSourceMaterialFromWarehouse(warehouse)) return;
    setState(() {
      _openComponentWarehousePickers.add(componentCode);
      _confirmedComponentWarehouseChoices.add(componentCode);
      _lookup = _lookup?.selectComponentWarehouse(componentCode, warehouse);
    });
  }

  List<ProtheusProductComponent> get _componentsNeedingWarehouseConfirmation {
    final lookup = _lookup;
    if (lookup == null || _armazem.isEmpty || _qtd <= 0) return const [];
    return [
      for (final component in lookup.components)
        if (_componentNeedsWarehouseConfirmation(component)) component,
    ];
  }

  bool _componentNeedsWarehouseConfirmation(
    ProtheusProductComponent component,
  ) {
    if (!component.shouldValidateStock) return false;
    final orderWarehouse = WarehouseRouting.normalizeCode(_armazem);
    final componentWarehouse = WarehouseRouting.normalizeCode(
      component.armazem,
    );
    if (orderWarehouse.isEmpty || componentWarehouse.isEmpty) return false;

    final requiredQuantity = component.requiredQuantityFor(_qtd);
    final selectedCanCover = component.stockAvailable >= requiredQuantity;
    final hasWarehouseThatCanCover = component.warehouseBalances.any(
      (balance) =>
          WarehouseRouting.normalizeCode(balance.armazem).isNotEmpty &&
          WarehouseRouting.canSourceMaterialFromWarehouse(balance.armazem) &&
          balance.availableQuantity >= requiredQuantity,
    );
    if (!hasWarehouseThatCanCover && !selectedCanCover) return false;

    final isUsingAnotherWarehouse = componentWarehouse != orderWarehouse;
    final canCompleteFromAnotherWarehouse =
        component.missingQuantityFor(_qtd) > 0 &&
        component.warehousesThatCanCover(_qtd).isNotEmpty;
    if (!isUsingAnotherWarehouse && !canCompleteFromAnotherWarehouse) {
      return false;
    }

    return !_confirmedComponentWarehouseChoices.contains(component.code) ||
        !selectedCanCover;
  }

  List<String> _orderWarehousesForCurrentOperator(
    ProtheusProductLookup lookup,
  ) {
    final operatorName = widget.currentOperatorName?.trim();
    if (operatorName == null || operatorName.isEmpty) {
      return lookup.availableWarehouses;
    }
    final operatorWarehouses =
        WarehouseRouting.orderCreationWarehousesForOperator(operatorName);
    if (operatorWarehouses.isNotEmpty) return operatorWarehouses;
    return lookup.availableWarehouses;
  }

  String? _warehouseGateMessage() {
    final lookup = _lookup;
    final operatorName = widget.currentOperatorName?.trim();
    if (lookup == null || operatorName == null || operatorName.isEmpty) {
      return null;
    }
    final allowedWarehouses = _orderWarehousesForCurrentOperator(lookup);
    if (allowedWarehouses.isEmpty) {
      return null;
    }
    if (_armazem.isNotEmpty &&
        !WarehouseRouting.canOperatorCreateOrder(operatorName, _armazem)) {
      return '$operatorName pode apontar, mas não pode abrir OP no ${WarehouseRouting.labelForWarehouse(_armazem)}.';
    }
    // Itens atendidos por outro armazem viram pendencia de confirmacao para
    // aquele setor. A permissao aqui vale apenas para onde a OP sera aberta.
    return null;
  }

  String? _warehouseSelectionGateMessage() {
    final pending = _componentsNeedingWarehouseConfirmation;
    if (pending.isEmpty) return null;
    final first = pending.first.code;
    final suffix = pending.length == 1
        ? first
        : '$first e mais ${pending.length - 1}';
    return 'Confirme o armazém de origem dos materiais que não saem do armazém da OP: $suffix.';
  }

  Future<void> _selectDueDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(today.year + 5, today.month, today.day),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _prazo = _formatPtBrDate(selected);
      _prazoController.text = _prazo;
    });
  }

  String _formatPtBrDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final productionGateMessage =
        _warehouseGateMessage() ??
        _warehouseSelectionGateMessage() ??
        _productionGateMessage();
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(widget.isDesktop ? 22 : 18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borderLight)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nova Ordem de Produção',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Será criada com status "A abrir".',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              _CloseButton(onTap: widget.onClose),
            ],
          ),
        ),

        // Form
        Padding(
          padding: EdgeInsets.all(widget.isDesktop ? 22 : 18),
          child: Column(
            children: [
              _FormField(
                label: 'Código Protheus',
                child: RawAutocomplete<ProtheusProduct>(
                  textEditingController: _codigoController,
                  focusNode: _codigoFocusNode,
                  displayStringForOption: (product) => product.code,
                  optionsBuilder: _searchProdutos,
                  onSelected: _selectProduct,
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          key: const Key('nova-op-product-code'),
                          controller: controller,
                          focusNode: focusNode,
                          textCapitalization: TextCapitalization.characters,
                          decoration: _inputDecoration(
                            hint: 'Digite código ou descrição',
                            suffix: _isLookingUp
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : null,
                          ),
                          style: _inputStyle(),
                          onChanged: _scheduleLookup,
                          onFieldSubmitted: (_) =>
                              _lookupProduto(controller.text.trim()),
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    return _ProductOptionsView(
                      options: options.toList(),
                      onSelected: onSelected,
                    );
                  },
                ),
              ),
              if (_lookupMessage != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _lookupMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
              if (productionGateMessage != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    productionGateMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 15),
              _FormField(
                label: 'Produto encontrado',
                child: TextFormField(
                  key: const Key('nova-op-product-name'),
                  readOnly: true,
                  decoration: _inputDecoration(
                    hint: 'Selecione uma opção ou informe um código válido',
                  ),
                  controller: _produtoController,
                  style: _inputStyle(),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      label: 'Filial',
                      child: DropdownButtonFormField<String>(
                        key: const Key('nova-op-branch'),
                        isExpanded: true,
                        initialValue: _filial,
                        decoration: _inputDecoration(),
                        style: _inputStyle(),
                        items: _filiais
                            .map(
                              (filial) => DropdownMenuItem(
                                value: filial,
                                child: Text('Filial $filial - VT'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _filial = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _FormField(
                      label: 'Armazém',
                      child: DropdownButtonFormField<String>(
                        key: const Key('nova-op-warehouse'),
                        isExpanded: true,
                        initialValue: _armazem.isNotEmpty ? _armazem : null,
                        decoration: _inputDecoration(
                          hint: 'Aguardando produto',
                        ),
                        style: _inputStyle(),
                        items:
                            (_lookup == null
                                    ? const <String>[]
                                    : _orderWarehousesForCurrentOperator(
                                        _lookup!,
                                      ))
                                .map(
                                  (warehouse) => DropdownMenuItem(
                                    value: warehouse,
                                    child: Text(
                                      WarehouseRouting.labelForWarehouse(
                                        warehouse,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: _lookup == null ? null : _selectWarehouse,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      label: 'Quantidade',
                      child: TextFormField(
                        key: const Key('nova-op-quantity'),
                        initialValue: '$_qtd',
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(),
                        style: _inputStyle(),
                        onChanged: (v) =>
                            setState(() => _qtd = int.tryParse(v) ?? 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _FormField(
                      label: 'Prazo (opcional)',
                      child: TextFormField(
                        key: const Key('nova-op-due-date'),
                        controller: _prazoController,
                        readOnly: true,
                        decoration: _inputDecoration(
                          hint: 'Selecionar data',
                          suffix: const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                        ),
                        style: _inputStyle(),
                        onTap: _selectDueDate,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              if (_canPlanProduction &&
                  (_armazem.isEmpty || _armazem == '05')) ...[
                ProductionRouteField(
                  stages: _plannedStages,
                  onChanged: (stages) =>
                      setState(() => _plannedStages = stages),
                ),
                const SizedBox(height: 15),
              ],
              _FormField(
                label: 'Prioridade',
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _prioridade,
                  decoration: _inputDecoration(),
                  style: _inputStyle(),
                  items: _prioridades
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _prioridade = v);
                  },
                ),
              ),
              if (_lookup != null) ...[
                const SizedBox(height: 15),
                _ProductLookupSummary(
                  lookup: _lookup!,
                  orderQuantity: _qtd,
                  selectedWarehouse: _armazem,
                  currentOperatorName: widget.currentOperatorName,
                  openComponentWarehousePickers: _openComponentWarehousePickers,
                  showAllCommitments: _showAllCommitments,
                  onToggleCommitments: () => setState(
                    () => _showAllCommitments = !_showAllCommitments,
                  ),
                  onComponentWarehouseChanged: _selectComponentWarehouse,
                ),
              ],
              if (_lookup != null) ...[
                const SizedBox(height: 15),
                _FormField(
                  label: 'PIN do responsável',
                  child: TextFormField(
                    key: const Key('nova-op-operator-pin'),
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDecoration(
                      hint: 'Assinatura para movimentar Protheus',
                    ).copyWith(errorText: _pinError),
                    style: _inputStyle(),
                    onChanged: (_) {
                      if (_pinError != null) {
                        setState(() => _pinError = null);
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),

        // Footer
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isDesktop ? 22 : 18,
            vertical: widget.isDesktop ? 15 : 14,
          ),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.borderLight)),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isValid ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.45,
                    ),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      vertical: widget.isDesktop ? 11 : 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        widget.isDesktop ? 9 : 11,
                      ),
                    ),
                    textStyle: GoogleFonts.ibmPlexSans(
                      fontSize: widget.isDesktop ? 13.5 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Criar OP'),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: widget.onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgButton,
                  foregroundColor: AppColors.textCode,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: widget.isDesktop ? 11 : 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      widget.isDesktop ? 9 : 11,
                    ),
                  ),
                  textStyle: GoogleFonts.ibmPlexSans(
                    fontSize: widget.isDesktop ? 13.5 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.isDesktop) {
      return GestureDetector(
        onTap: widget.onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 440,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.92,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x520F172A),
                    blurRadius: 64,
                    offset: Offset(0, 24),
                  ),
                ],
              ),
              child: SingleChildScrollView(child: content),
            ),
          ),
        ),
      );
    }

    // Mobile: bottom sheet
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(child: content),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13.5,
          color: AppColors.muted,
        ),
        suffixIcon: suffix == null
            ? null
            : Padding(padding: const EdgeInsets.all(12), child: suffix),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.isDesktop ? 9 : 11),
          borderSide: const BorderSide(color: Color(0xFFDFE3E9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.isDesktop ? 9 : 11),
          borderSide: const BorderSide(color: Color(0xFFDFE3E9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.isDesktop ? 9 : 11),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 11,
          vertical: widget.isDesktop ? 10 : 13,
        ),
        filled: true,
        fillColor: AppColors.surface,
      );

  TextStyle _inputStyle() =>
      GoogleFonts.ibmPlexSans(fontSize: 13.5, color: AppColors.textStrong);
}

class _ProductOptionsView extends StatelessWidget {
  const _ProductOptionsView({required this.options, required this.onSelected});

  final List<ProtheusProduct> options;
  final AutocompleteOnSelected<ProtheusProduct> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 10,
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(9),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 396, maxHeight: 260),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.borderLight),
            itemBuilder: (context, index) {
              final product = options[index];
              return InkWell(
                onTap: () => onSelected(product),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.code,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProductLookupSummary extends StatelessWidget {
  const _ProductLookupSummary({
    required this.lookup,
    required this.orderQuantity,
    required this.selectedWarehouse,
    required this.currentOperatorName,
    required this.openComponentWarehousePickers,
    required this.showAllCommitments,
    required this.onToggleCommitments,
    required this.onComponentWarehouseChanged,
  });

  final ProtheusProductLookup lookup;
  final int orderQuantity;
  final String selectedWarehouse;
  final String? currentOperatorName;
  final Set<String> openComponentWarehousePickers;
  final bool showAllCommitments;
  final VoidCallback onToggleCommitments;
  final void Function(String componentCode, String? warehouse)
  onComponentWarehouseChanged;

  @override
  Widget build(BuildContext context) {
    final componentsCountLabel =
        '${lookup.components.length} componente${lookup.components.length == 1 ? '' : 's'}';
    final warehouseChoices = lookup.components
        .where(
          (component) =>
              component.shouldValidateStock &&
              component.missingQuantityFor(orderQuantity) > 0 &&
              component.warehousesThatCanCover(orderQuantity).isNotEmpty,
        )
        .toList();
    final modCount = lookup.components
        .where((component) => !component.shouldValidateStock)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFD),
            border: Border.all(color: AppColors.borderLight),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lookup.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textStrong,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${lookup.product.type} · ${lookup.product.unit} · grupo ${lookup.product.group}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              if (lookup.components.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  componentsCountLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (lookup.components.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Empenhos da OP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textCode,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onToggleCommitments,
                icon: Icon(
                  showAllCommitments
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                ),
                label: Text(
                  showAllCommitments
                      ? 'Recolher'
                      : 'Detalhar ($componentsCountLabel)',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (showAllCommitments)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.borderLight),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                children: [
                  for (final entry in lookup.components.asMap().entries) ...[
                    _ComponentCommitmentCard(
                      component: entry.value,
                      orderQuantity: orderQuantity,
                      selectedWarehouse: selectedWarehouse,
                      currentOperatorName: currentOperatorName,
                      keepWarehousePickerOpen: openComponentWarehousePickers
                          .contains(entry.value.code),
                      onWarehouseChanged: onComponentWarehouseChanged,
                    ),
                    if (entry.key != lookup.components.length - 1)
                      const Divider(height: 1, color: AppColors.borderLight),
                  ],
                ],
              ),
            )
          else
            _CommitmentsCollapsedSummary(
              components: lookup.components,
              orderQuantity: orderQuantity,
              warehouseChoices: warehouseChoices,
              modCount: modCount,
              onExpand: onToggleCommitments,
            ),
          if (!showAllCommitments && lookup.components.length > 3) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onToggleCommitments,
              icon: const Icon(Icons.open_in_full_rounded, size: 14),
              label: Text(
                warehouseChoices.isEmpty
                    ? 'Expandir e revisar todos'
                    : 'Expandir para escolher armazéns',
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _CommitmentsCollapsedSummary extends StatelessWidget {
  const _CommitmentsCollapsedSummary({
    required this.components,
    required this.orderQuantity,
    required this.warehouseChoices,
    required this.modCount,
    required this.onExpand,
  });

  final List<ProtheusProductComponent> components;
  final int orderQuantity;
  final List<ProtheusProductComponent> warehouseChoices;
  final int modCount;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final visibleChoices = warehouseChoices.take(3).toList();
    final hasChoices = warehouseChoices.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onExpand,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasChoices ? const Color(0xFFFFFBEB) : AppColors.bgHeader,
          border: Border.all(
            color: hasChoices ? const Color(0xFFEED38B) : AppColors.borderLight,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasChoices
                      ? Icons.inventory_2_outlined
                      : Icons.check_circle_outline_rounded,
                  size: 17,
                  color: hasChoices ? AppColors.orangeText : AppColors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasChoices
                        ? '${warehouseChoices.length} item${warehouseChoices.length == 1 ? '' : 's'} precisa${warehouseChoices.length == 1 ? '' : 'm'} completar por outro armazém'
                        : 'Sem escolhas pendentes de armazém',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: hasChoices
                          ? AppColors.orangeText
                          : AppColors.textStrong,
                    ),
                  ),
                ),
              ],
            ),
            if (visibleChoices.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final component in visibleChoices) ...[
                _CollapsedChoiceLine(
                  component: component,
                  orderQuantity: orderQuantity,
                ),
                if (component != visibleChoices.last) const SizedBox(height: 4),
              ],
            ],
            const SizedBox(height: 8),
            Text(
              hasChoices
                  ? 'Expanda para escolher o armazém de cada item.'
                  : 'Expanda apenas se quiser revisar quantidades e armazéns.',
              style: const TextStyle(
                fontSize: 11.2,
                color: AppColors.textSecondary,
              ),
            ),
            if (modCount > 0) ...[
              const SizedBox(height: 5),
              Text(
                '$modCount MOD ${modCount == 1 ? 'está' : 'estão'} como custo/mão de obra, sem saldo físico.',
                style: const TextStyle(
                  fontSize: 10.8,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CollapsedChoiceLine extends StatelessWidget {
  const _CollapsedChoiceLine({
    required this.component,
    required this.orderQuantity,
  });

  final ProtheusProductComponent component;
  final int orderQuantity;

  @override
  Widget build(BuildContext context) {
    final missing = component.missingQuantityFor(orderQuantity);
    final unit = component.unit.isEmpty ? 'un' : component.unit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFE9C46A)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.priority_high_rounded,
            size: 14,
            color: AppColors.orangeText,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              component.code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.2,
                fontWeight: FontWeight.w800,
                color: AppColors.textStrong,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'faltam ${formatProductionQuantity(missing)} $unit',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentCommitmentCard extends StatelessWidget {
  const _ComponentCommitmentCard({
    required this.component,
    required this.orderQuantity,
    required this.selectedWarehouse,
    required this.currentOperatorName,
    required this.keepWarehousePickerOpen,
    required this.onWarehouseChanged,
  });

  final ProtheusProductComponent component;
  final int orderQuantity;
  final String selectedWarehouse;
  final String? currentOperatorName;
  final bool keepWarehousePickerOpen;
  final void Function(String componentCode, String? warehouse)
  onWarehouseChanged;

  @override
  Widget build(BuildContext context) {
    final requiredQuantity = component.requiredQuantityFor(orderQuantity);
    final missing = component.missingQuantityFor(orderQuantity);
    final alternatives = component.warehousesThatCanCover(orderQuantity);
    final selectedFromOtherWarehouse =
        component.shouldValidateStock &&
        selectedWarehouse.isNotEmpty &&
        component.armazem.isNotEmpty &&
        component.armazem != selectedWarehouse;
    final coverageOptions = _coverageOptions(requiredQuantity);
    final needsExternalWarehouseChoice =
        component.shouldValidateStock &&
        missing > 0 &&
        coverageOptions.any(
          (balance) =>
              balance.armazem != component.armazem &&
              balance.availableQuantity >= requiredQuantity,
        );
    final highlightExternalWarehouse =
        selectedFromOtherWarehouse || needsExternalWarehouseChoice;
    final highlightColor = selectedFromOtherWarehouse
        ? const Color(0xFFEAF5FB)
        : const Color(0xFFFFF8E1);
    final highlightBorder = selectedFromOtherWarehouse
        ? const Color(0xFF8EC8E8)
        : const Color(0xFFE9C46A);
    final commitmentLabel = component.commitmentQuantity > 0
        ? 'Quantidade empenhada ${formatProductionQuantity(component.commitmentQuantity)}.'
        : '';
    final originalLabel = component.originalQuantity > 0
        ? 'Quantidade original ${formatProductionQuantity(component.originalQuantity)}.'
        : '';
    final status = component.shouldValidateStock
        ? _availabilityStatus(missing)
        : const _ComponentAvailabilityStatus(
            label: 'MOD: custo/mão de obra. Sem saldo físico para validar.',
            others: '',
            color: AppColors.textSecondary,
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: double.infinity,
      margin: EdgeInsets.symmetric(
        horizontal: highlightExternalWarehouse ? 8 : 12,
        vertical: highlightExternalWarehouse ? 8 : 10,
      ),
      padding: EdgeInsets.all(highlightExternalWarehouse ? 10 : 0),
      decoration: BoxDecoration(
        color: highlightExternalWarehouse ? highlightColor : Colors.transparent,
        border: Border.all(
          color: highlightExternalWarehouse
              ? highlightBorder
              : Colors.transparent,
          width: highlightExternalWarehouse ? 1.2 : 0,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      component.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textStrong,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      component.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (highlightExternalWarehouse) ...[
                      const SizedBox(height: 5),
                      _ExternalWarehouseBadge(
                        confirmed: selectedFromOtherWarehouse,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _InlineReadOnlyField(
                width: 84,
                text: formatProductionQuantity(requiredQuantity),
              ),
              const SizedBox(width: 8),
              _ComponentWarehouseField(
                component: component,
                options: coverageOptions,
                onWarehouseChanged: onWarehouseChanged,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: status.label,
                  style: TextStyle(
                    color: status.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (status.others.isNotEmpty)
                  TextSpan(
                    text: ' Outros: ${status.others}.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
              ],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.3),
          ),
          if (commitmentLabel.isNotEmpty || originalLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [
                commitmentLabel,
                originalLabel,
              ].where((label) => label.isNotEmpty).join(' '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.8,
                color: AppColors.textMuted,
              ),
            ),
          ],
          if (missing > 0 ||
              selectedFromOtherWarehouse ||
              keepWarehousePickerOpen) ...[
            const SizedBox(height: 6),
            if (coverageOptions.isNotEmpty) ...[
              _WarehouseCoveragePicker(
                component: component,
                requiredQuantity: requiredQuantity,
                alternatives: coverageOptions,
                onWarehouseChanged: onWarehouseChanged,
              ),
            ] else
              Text(
                alternatives.isEmpty
                    ? 'Nenhum outro armazém cobre a quantidade necessária.'
                    : 'Selecione de qual armazém tirar.',
                style: const TextStyle(
                  fontSize: 11.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<ProtheusWarehouseBalance> _coverageOptions(num requiredQuantity) {
    final options = <ProtheusWarehouseBalance>[];
    final seen = <String>{};
    for (final balance in component.warehouseBalances) {
      final selected =
          WarehouseRouting.canSourceMaterialFromWarehouse(balance.armazem) &&
          balance.armazem == component.armazem;
      final canCover =
          WarehouseRouting.canSourceMaterialFromWarehouse(balance.armazem) &&
          balance.availableQuantity >= requiredQuantity;
      if ((selected || canCover) && seen.add(balance.armazem)) {
        options.add(balance);
      }
    }
    options.sort((a, b) => b.availableQuantity.compareTo(a.availableQuantity));
    return options;
  }

  _ComponentAvailabilityStatus _availabilityStatus(num missing) {
    final local = WarehouseRouting.normalizeCode(component.armazem);
    final available = formatProductionQuantity(component.stockAvailable);
    final others = component.warehouseBalances
        .where(
          (balance) =>
              balance.armazem != local &&
              WarehouseRouting.canSourceMaterialFromWarehouse(balance.armazem),
        )
        .take(5)
        .map(
          (balance) =>
              '${WarehouseRouting.normalizeCode(balance.armazem)}: '
              '${formatProductionQuantity(balance.availableQuantity)}',
        )
        .join(', ');
    if (missing > 0) {
      return _ComponentAvailabilityStatus(
        label:
            'Almox. ${local.isEmpty ? '-' : local} tem $available disponível.',
        others: others,
        color: AppColors.danger,
      );
    }
    return _ComponentAvailabilityStatus(
      label: 'Disponível: $available aqui.',
      others: others,
      color: AppColors.green,
    );
  }
}

class _ComponentAvailabilityStatus {
  const _ComponentAvailabilityStatus({
    required this.label,
    required this.others,
    required this.color,
  });

  final String label;
  final String others;
  final Color color;
}

class _ExternalWarehouseBadge extends StatelessWidget {
  const _ExternalWarehouseBadge({required this.confirmed});

  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: confirmed ? const Color(0xFFDDF1FB) : const Color(0xFFFFE7B8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: confirmed ? const Color(0xFF9CCFE8) : const Color(0xFFE9C46A),
        ),
      ),
      child: Row(
        children: [
          Icon(
            confirmed ? Icons.swap_horiz_rounded : Icons.error_outline_rounded,
            size: 13,
            color: confirmed ? AppColors.primary : AppColors.orangeText,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              confirmed ? 'Usa outro armazém' : 'Escolha obrigatória',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: confirmed ? AppColors.primary : AppColors.orangeText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineReadOnlyField extends StatelessWidget {
  const _InlineReadOnlyField({required this.width, required this.text});

  final double width;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFBFDFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E8F2)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.ibmPlexMono(
          fontSize: 12,
          color: AppColors.textStrong,
        ),
      ),
    );
  }
}

class _ComponentWarehouseField extends StatelessWidget {
  const _ComponentWarehouseField({
    required this.component,
    required this.options,
    required this.onWarehouseChanged,
  });

  final ProtheusProductComponent component;
  final List<ProtheusWarehouseBalance> options;
  final void Function(String componentCode, String? warehouse)
  onWarehouseChanged;

  @override
  Widget build(BuildContext context) {
    final values = {
      if (component.armazem.isNotEmpty &&
          WarehouseRouting.canSourceMaterialFromWarehouse(component.armazem))
        component.armazem,
      for (final option in options)
        if (option.armazem.isNotEmpty &&
            WarehouseRouting.canSourceMaterialFromWarehouse(option.armazem))
          option.armazem,
    }.toList()..sort();
    final selected = values.contains(component.armazem)
        ? component.armazem
        : values.isNotEmpty
        ? values.first
        : null;

    final selectedLabel = selected == null
        ? '-'
        : WarehouseRouting.normalizeCode(selected);

    return PopupMenuButton<String>(
      key: ValueKey(
        'component-warehouse-${component.code}-${component.armazem}',
      ),
      tooltip: 'Escolher armazém',
      initialValue: selected,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 240),
      onSelected: (value) => onWarehouseChanged(component.code, value),
      itemBuilder: (context) => [
        for (final value in values)
          PopupMenuItem(
            value: value,
            child: SizedBox(
              width: 190,
              child: Text(
                WarehouseRouting.labelForWarehouse(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
      child: Container(
        width: 92,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFDFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD8E8F2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedLabel,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  color: AppColors.textStrong,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseCoveragePicker extends StatelessWidget {
  const _WarehouseCoveragePicker({
    required this.component,
    required this.requiredQuantity,
    required this.alternatives,
    required this.onWarehouseChanged,
  });

  final ProtheusProductComponent component;
  final num requiredQuantity;
  final List<ProtheusWarehouseBalance> alternatives;
  final void Function(String componentCode, String? warehouse)
  onWarehouseChanged;

  @override
  Widget build(BuildContext context) {
    ProtheusWarehouseBalance? selectedBalance;
    for (final balance in alternatives) {
      if (balance.armazem == component.armazem) {
        selectedBalance = balance;
        break;
      }
    }
    final selectedCovers =
        selectedBalance != null &&
        selectedBalance.availableQuantity >= requiredQuantity;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            !selectedCovers
                ? 'Solicitar transferência'
                : 'Selecionado: ${WarehouseRouting.labelForWarehouse(selectedBalance.armazem)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final balance in alternatives)
                _WarehouseCoverageOption(
                  component: component,
                  balance: balance,
                  requiredQuantity: requiredQuantity,
                  selected: component.armazem == balance.armazem,
                  onWarehouseChanged: onWarehouseChanged,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WarehouseCoverageOption extends StatelessWidget {
  const _WarehouseCoverageOption({
    required this.component,
    required this.balance,
    required this.requiredQuantity,
    required this.selected,
    required this.onWarehouseChanged,
  });

  final ProtheusProductComponent component;
  final ProtheusWarehouseBalance balance;
  final num requiredQuantity;
  final bool selected;
  final void Function(String componentCode, String? warehouse)
  onWarehouseChanged;

  @override
  Widget build(BuildContext context) {
    final canCover = balance.availableQuantity >= requiredQuantity;
    final selectedColor = selected ? AppColors.primary : AppColors.borderLight;
    final availableColor = balance.availableQuantity < 0
        ? AppColors.danger
        : canCover
        ? AppColors.primary
        : AppColors.orangeText;

    return InkWell(
      key: Key(
        'nova-op-component-warehouse-option-${component.code}-${balance.armazem}',
      ),
      borderRadius: BorderRadius.circular(999),
      onTap: () => onWarehouseChanged(component.code, balance.armazem),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF5FB) : const Color(0xFFF8FBFD),
          border: Border.all(color: selectedColor),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_rounded,
                size: 13,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              WarehouseRouting.normalizeCode(balance.armazem),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textStrong,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'disponível ${formatProductionQuantity(balance.availableQuantity)}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: availableColor,
              ),
            ),
            if (!canCover) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.warning_amber_rounded,
                size: 12,
                color: AppColors.orangeText,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textCode,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgButton,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: const SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: Text(
              '×',
              style: TextStyle(fontSize: 18, color: AppColors.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}
