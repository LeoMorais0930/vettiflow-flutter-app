import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/account_menu.dart';

class MobileAppBar extends StatelessWidget {
  const MobileAppBar({super.key});
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surface,
    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
    child: const Row(
      children: [
        Expanded(
          child: Text(
            'Painel',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.title,
            ),
          ),
        ),
        AccountMenu(),
      ],
    ),
  );
}
