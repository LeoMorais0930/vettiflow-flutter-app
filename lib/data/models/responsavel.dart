import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';

class Responsavel {
  final String nome;
  final String iniciais;
  final Color cor;

  const Responsavel({
    required this.nome,
    required this.iniciais,
    required this.cor,
  });

  static final List<Responsavel> todos = _fromOperators();

  static const _palette = [
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFDC2626),
    Color(0xFFD97706),
    Color(0xFF0891B2),
    Color(0xFFC026D3),
    Color(0xFF4F46E5),
    Color(0xFF16A34A),
    Color(0xFFEA580C),
  ];

  static Responsavel? byNome(String nome) {
    for (final r in todos) {
      if (r.nome == nome) return r;
    }
    return null;
  }

  static List<Responsavel> _fromOperators() {
    final names = <String>{};
    final responsaveis = <Responsavel>[];
    for (final operator in Operator.all) {
      if (operator.area == WorkArea.system) continue;
      if (!names.add(operator.name)) continue;
      responsaveis.add(
        Responsavel(
          nome: operator.name,
          iniciais: _initials(operator.name),
          cor: _palette[responsaveis.length % _palette.length],
        ),
      );
    }
    return List.unmodifiable(responsaveis);
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      final first = parts.first;
      return first.substring(0, first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
