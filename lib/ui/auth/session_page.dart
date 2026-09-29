import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_auth_session.dart';

class SessionPage extends StatelessWidget {
  const SessionPage({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ProtheusAuthSession>();
    return Scaffold(
      appBar: AppBar(title: const Text('Conta VettiFlow')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Login confirmado: ${auth.username ?? ""}'),
              const SizedBox(height: 16),
              const Text(
                'Seu usuário ainda não tem um setor vinculado no VettiFlow. Solicite o cadastro ao administrador.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: auth.logout, child: const Text('Sair')),
            ],
          ),
        ),
      ),
    );
  }
}
