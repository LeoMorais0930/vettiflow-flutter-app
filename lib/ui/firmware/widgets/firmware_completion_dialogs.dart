import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/firmware_models.dart';

Future<List<DefectRecord>?> showFirmwareDefectsDialog(
  BuildContext context, {
  required int maxQuantity,
}) {
  final compact = MediaQuery.sizeOf(context).width < 720;

  if (compact) {
    return showModalBottomSheet<List<DefectRecord>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _DefectsSheet(compact: true, maxQuantity: maxQuantity),
    ).then((v) => v);
  }

  return showDialog<List<DefectRecord>>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      backgroundColor: Colors.transparent,
      child: _DefectsSheet(maxQuantity: maxQuantity),
    ),
  );
}

/// [currentStage] é a etapa em que a tela esta operando (ex: firmware = Gravacao).
Future<Operator?> showFirmwarePinDialog(
  BuildContext context,
  FirmwareOperation operation, {
  List<DefectRecord> defects = const [],
  WorkStage currentStage = WorkStage.firmware,
  bool Function(Operator operator)? isOperatorAllowed,
}) {
  final compact = MediaQuery.sizeOf(context).width < 720;

  if (compact) {
    return showModalBottomSheet<Operator>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PinSheet(
        operation: operation,
        defects: defects,
        currentStage: currentStage,
        isOperatorAllowed: isOperatorAllowed,
        compact: true,
      ),
    );
  }

  return showDialog<Operator>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      backgroundColor: Colors.transparent,
      child: _PinSheet(
        operation: operation,
        defects: defects,
        currentStage: currentStage,
        isOperatorAllowed: isOperatorAllowed,
      ),
    ),
  );
}

// ────────────────────────────────────────────────────────────────────
// Defeitos
// ────────────────────────────────────────────────────────────────────

class _DefectsSheet extends StatefulWidget {
  const _DefectsSheet({required this.maxQuantity, this.compact = false});

  final int maxQuantity;
  final bool compact;

  @override
  State<_DefectsSheet> createState() => _DefectsSheetState();
}

class _DefectsSheetState extends State<_DefectsSheet> {
  final _quantities = <String, int>{};
  final _controllers = <String, TextEditingController>{};

  int get _maxQty => widget.maxQuantity <= 0 ? 1 : widget.maxQuantity;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggle(String code) {
    setState(() {
      if (_quantities.containsKey(code)) {
        _quantities.remove(code);
      } else {
        _quantities[code] = 1;
        _controllers.putIfAbsent(code, () => TextEditingController()).text =
            '1';
      }
    });
  }

  void _setQty(String code, int value) {
    setState(() => _quantities[code] = value.clamp(1, _maxQty));
  }

  List<DefectRecord> get _records => FirmwareDefect.all
      .where((defect) => _quantities.containsKey(defect.code))
      .map(
        (defect) => DefectRecord(
          code: defect.code,
          title: defect.title,
          quantity: _quantities[defect.code]!,
        ),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final selectedDefects = _records;
    final totalDefects = selectedDefects.fold<int>(
      0,
      (sum, defect) => sum + defect.quantity,
    );
    final exceedsOrder = totalDefects > _maxQty;

    return _ModalSurface(
      compact: widget.compact,
      maxWidth: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.compact) const _SheetHandle(),
          const Text(
            'Houve defeitos?',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecione os defeitos encontrados durante a gravacao. Se nao houve, continue sem selecionar.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final defect in FirmwareDefect.all)
                _DefectChip(
                  defect: defect,
                  selected: _quantities.containsKey(defect.code),
                  onTap: () => _toggle(defect.code),
                ),
            ],
          ),
          if (selectedDefects.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEFDFBF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quantidade por defeito',
                    style: const TextStyle(
                      color: AppColors.orangeText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final defect in selectedDefects) ...[
                    _FirmwareDefectQuantityRow(
                      code: defect.code,
                      title: defect.title,
                      controller: _controllers[defect.code]!,
                      onChanged: (value) => _setQty(defect.code, value),
                      onStep: (delta) {
                        final next = (_quantities[defect.code]! + delta).clamp(
                          1,
                          _maxQty,
                        );
                        _controllers[defect.code]!.text = '$next';
                        _setQty(defect.code, next);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    exceedsOrder
                        ? 'Total $totalDefects maior que a quantidade da OP ($_maxQty).'
                        : 'Total: $totalDefects de $_maxQty un.',
                    style: TextStyle(
                      color: exceedsOrder
                          ? const Color(0xFFD45B5B)
                          : AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _DialogButton(
                  label: 'Cancelar',
                  onPressed: () => Navigator.of(context).pop(null),
                  fillColor: const Color(0xFFF6F9FB),
                  foregroundColor: AppColors.muted,
                  borderColor: AppColors.border,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _DialogButton(
                  label: selectedDefects.isEmpty
                      ? 'Continuar sem defeitos'
                      : 'Continuar com $totalDefects un',
                  onPressed: exceedsOrder
                      ? null
                      : () => Navigator.of(context).pop(selectedDefects),
                  fillColor: exceedsOrder
                      ? const Color(0xFFCBD7E1)
                      : AppColors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DefectChip extends StatelessWidget {
  const _DefectChip({
    required this.defect,
    required this.selected,
    required this.onTap,
  });

  final FirmwareDefect defect;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF4DB) : const Color(0xFFF8FBFD),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.orange : const Color(0xFFE3EDF4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? AppColors.orange : const Color(0xFFEBF1F6),
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Text(
                defect.code,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              defect.title,
              style: TextStyle(
                color: selected ? AppColors.orangeText : AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirmwareDefectQuantityRow extends StatelessWidget {
  const _FirmwareDefectQuantityRow({
    required this.code,
    required this.title,
    required this.controller,
    required this.onChanged,
    required this.onStep,
  });

  final String code;
  final String title;
  final TextEditingController controller;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE3EDF4)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              code,
              style: const TextStyle(
                color: AppColors.orangeText,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _FirmwareStepButton(
            icon: Icons.remove_rounded,
            onTap: () => onStep(-1),
          ),
          SizedBox(
            width: 50,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 7),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed != null) onChanged(parsed);
              },
            ),
          ),
          _FirmwareStepButton(icon: Icons.add_rounded, onTap: () => onStep(1)),
        ],
      ),
    );
  }
}

class _FirmwareStepButton extends StatelessWidget {
  const _FirmwareStepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFD8E6EE)),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// PIN dialog — input de 4 digitos com auto-verificacao
// ────────────────────────────────────────────────────────────────────

class _PinSheet extends StatefulWidget {
  const _PinSheet({
    required this.operation,
    this.defects = const [],
    this.currentStage = WorkStage.firmware,
    this.isOperatorAllowed,
    this.compact = false,
  });

  final FirmwareOperation operation;
  final List<DefectRecord> defects;
  final WorkStage currentStage;
  final bool Function(Operator operator)? isOperatorAllowed;
  final bool compact;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _pinController = TextEditingController();
  Operator? _resolvedOperator;
  bool _wrongStage = false;
  bool _invalidPin = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _onPinChanged(String value) {
    if (value.length < 4) {
      setState(() {
        _resolvedOperator = null;
        _wrongStage = false;
        _invalidPin = false;
      });
      return;
    }

    final op = context.read<OperatorAssignmentStore>().findByPin(value);
    setState(() {
      _resolvedOperator = op;
      _invalidPin = op == null;
      _wrongStage =
          op != null &&
          !(widget.isOperatorAllowed?.call(op) ??
              op.stage == widget.currentStage);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ModalSurface(
      compact: widget.compact,
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.compact) const _SheetHandle(),
          const Text(
            'Assinatura do operador',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Digite o PIN para concluir a ${widget.operation.number}.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // PIN input
          const Text(
            'PIN (4 digitos)',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pinController,
            onChanged: _onPinChanged,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 12,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF8FBFD),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _invalidPin
                      ? const Color(0xFFD45B5B)
                      : AppColors.border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _invalidPin
                      ? const Color(0xFFD45B5B)
                      : _resolvedOperator != null
                      ? AppColors.green
                      : AppColors.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _invalidPin
                      ? const Color(0xFFD45B5B)
                      : _resolvedOperator != null
                      ? AppColors.green
                      : AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Resultado da verificacao
          if (_invalidPin)
            _PinFeedback(
              icon: Icons.error_outline_rounded,
              color: const Color(0xFFD45B5B),
              bgColor: const Color(0xFFFFF0F0),
              borderColor: const Color(0xFFE8C4C4),
              text: 'PIN nao encontrado. Verifique e tente novamente.',
            ),

          if (_resolvedOperator != null && !_wrongStage)
            _PinFeedback(
              icon: Icons.check_circle_rounded,
              color: AppColors.green,
              bgColor: const Color(0xFFE7F6EC),
              borderColor: const Color(0xFFBFE5CC),
              text:
                  'Operador: ${_resolvedOperator!.name} (${_resolvedOperator!.stage.label})',
            ),

          if (_wrongStage && _resolvedOperator != null)
            _PinFeedback(
              icon: Icons.warning_amber_rounded,
              color: AppColors.orangeText,
              bgColor: const Color(0xFFFFF8EC),
              borderColor: const Color(0xFFEFDFBF),
              text:
                  'PIN de ${_resolvedOperator!.name}, vinculado a etapa "${_resolvedOperator!.stage.label}". '
                  'Voce esta na etapa "${widget.currentStage.label}".',
            ),

          if (widget.defects.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEFDFBF)),
              ),
              child: Text(
                'Defeitos: ${widget.defects.map((d) => '${d.code} (${d.quantity})').join(', ')}',
                style: const TextStyle(
                  color: AppColors.orangeText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _DialogButton(
                  label: 'Cancelar',
                  onPressed: () => Navigator.of(context).pop(null),
                  fillColor: const Color(0xFFF6F9FB),
                  foregroundColor: AppColors.muted,
                  borderColor: AppColors.border,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _DialogButton(
                  label: 'Concluir OP',
                  onPressed: _resolvedOperator != null && !_wrongStage
                      ? () => Navigator.of(context).pop(_resolvedOperator)
                      : null,
                  fillColor: _resolvedOperator != null && !_wrongStage
                      ? AppColors.green
                      : const Color(0xFFCBD7E1),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinFeedback extends StatelessWidget {
  const _PinFeedback({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Componentes compartilhados
// ────────────────────────────────────────────────────────────────────

class _ModalSurface extends StatelessWidget {
  const _ModalSurface({
    required this.child,
    required this.compact,
    required this.maxWidth,
  });

  final Widget child;
  final bool compact;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: compact ? Alignment.bottomCenter : Alignment.center,
      child: Container(
        width: compact ? double.infinity : null,
        constraints: BoxConstraints(
          maxWidth: compact ? double.infinity : maxWidth,
        ),
        margin: EdgeInsets.only(
          left: compact ? 10 : 0,
          right: compact ? 10 : 0,
          bottom: compact ? 10 : 0,
        ),
        padding: EdgeInsets.fromLTRB(
          compact ? 24 : 36,
          compact ? 16 : 32,
          compact ? 24 : 36,
          compact ? 24 : 28,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 22 : 16),
        ),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.fillColor,
    required this.foregroundColor,
    this.onPressed,
    this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color fillColor;
  final Color foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: fillColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: const Color(0xFFE4EDF4),
          disabledForegroundColor: AppColors.muted,
          side: BorderSide(color: borderColor ?? fillColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 50,
        height: 4,
        margin: const EdgeInsets.only(bottom: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFCBD7E1),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
