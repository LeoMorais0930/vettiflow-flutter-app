import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/layout/app_breakpoints.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/auth/widgets/login_brand_panel.dart';
import 'package:vetti_flow_1_0/ui/auth/widgets/login_form_panel.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _loginError;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final op = context.read<OperatorAssignmentStore>().authenticate(
      _userController.text,
      _passwordController.text,
    );

    if (op == null) {
      setState(() => _loginError = 'Usuario ou senha incorretos.');
      return;
    }

    setState(() => _loginError = null);
    Navigator.of(context).pushReplacementNamed(op.homeRoute);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = AppBreakpoints.fromWidth(constraints.maxWidth);
        final isDesktop = formFactor == AppFormFactor.expanded;

        if (!isDesktop) {
          return _MobileLoginLayout(
            formKey: _formKey,
            userController: _userController,
            passwordController: _passwordController,
            onSubmit: _submit,
            loginError: _loginError,
          );
        }

        return _DesktopLoginLayout(
          formKey: _formKey,
          userController: _userController,
          passwordController: _passwordController,
          onSubmit: _submit,
          loginError: _loginError,
        );
      },
    );
  }
}

class _DesktopLoginLayout extends StatelessWidget {
  const _DesktopLoginLayout({
    required this.formKey,
    required this.userController,
    required this.passwordController,
    required this.onSubmit,
    this.loginError,
  });

  final GlobalKey<FormState> formKey;
  final String? loginError;
  final TextEditingController userController;
  final TextEditingController passwordController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          const Positioned.fill(
            child: LoginBrandPanel(variant: LoginBrandVariant.desktopBackdrop),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(40, 40, 56, 40),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.20),
                        blurRadius: 34,
                        offset: const Offset(0, 22),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(36, 36, 36, 34),
                    child: LoginFormPanel(
                      formKey: formKey,
                      userController: userController,
                      passwordController: passwordController,
                      onSubmit: onSubmit,
                      loginError: loginError,
                    ),
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

class _MobileLoginLayout extends StatelessWidget {
  const _MobileLoginLayout({
    required this.formKey,
    required this.userController,
    required this.passwordController,
    required this.onSubmit,
    this.loginError,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController userController;
  final TextEditingController passwordController;
  final VoidCallback onSubmit;
  final String? loginError;

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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const SizedBox(
                  height: 256,
                  child: LoginBrandPanel(
                    variant: LoginBrandVariant.mobileBackdrop,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                    child: LoginFormPanel(
                      formKey: formKey,
                      userController: userController,
                      passwordController: passwordController,
                      onSubmit: onSubmit,
                      loginError: loginError,
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
