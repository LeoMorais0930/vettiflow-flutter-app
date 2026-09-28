import 'package:flutter/material.dart';
import 'account_menu.dart';

class VettiTopBar extends StatelessWidget {
  const VettiTopBar({
    super.key,
    required this.title,
    required this.operatorName,
    this.operatorRole,
    this.compact = false,
  });
  final String title, operatorName;
  final String? operatorRole;
  final bool compact;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final narrow = size.maxWidth < 600;
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: narrow ? 12 : 24,
          vertical: 14,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B202E), Color(0xFF123A52)],
          ),
          border: Border(bottom: BorderSide(color: Color(0xFF1F5875))),
        ),
        child: Row(
          children: [
            Semantics(
              label: 'VettiFlow',
              child: ExcludeSemantics(
                child: Text(
                  narrow ? 'VF' : 'Vetti\nFlow',
                  style: const TextStyle(
                    color: Color(0xFF9EE5FF),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.05,
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 32,
              color: Colors.white24,
              margin: EdgeInsets.symmetric(horizontal: narrow ? 12 : 22),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: narrow ? 18 : 22,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Protheus em consulta',
                    style: TextStyle(color: Color(0xFFB7D0DF), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AccountMenu(dark: true, showName: size.maxWidth >= 760),
          ],
        ),
      );
    },
  );
}
