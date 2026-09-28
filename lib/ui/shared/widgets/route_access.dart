import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator_access.dart';

class RouteAccess extends StatelessWidget {
  const RouteAccess({super.key, required this.route, required this.builder});
  final String route;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) {
    final operator = context.watch<OperatorAssignmentStore?>()?.currentOperator;
    if (operator?.canAccessRoute(route) == true) return builder(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Acesso ao setor')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                operator == null
                    ? 'Entre para acessar sua área.'
                    : 'Este setor não faz parte do seu acesso.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  operator?.homeRoute ?? '/login',
                  (_) => false,
                ),
                child: Text(operator == null ? 'Entrar' : 'Ir para minha área'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
