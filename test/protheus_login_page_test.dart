import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_auth_session.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator_access.dart';
import 'package:vetti_flow_1_0/ui/auth/login_page.dart';

void main() {
  for (final accepted in [true, false]) {
    testWidgets('Flutter login uses Protheus; accepted=$accepted', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final auth = ProtheusAuthSession(
        baseUrl: 'http://localhost:8000',
        client: MockClient((request) async {
          calls++;
          expect(request.headers['username'], 'leonardo.morais');
          expect(request.headers['password'], 'ERP-password');
          return accepted
              ? http.Response(
                  jsonEncode({
                    'access_token': 'token',
                    'token_type': 'Bearer',
                    'username': 'leonardo.morais',
                    'expiresAt':
                        DateTime.now().millisecondsSinceEpoch / 1000 + 300,
                  }),
                  200,
                )
              : http.Response('{}', 401);
        }),
      );
      final operators = OperatorAssignmentStore();
      addTearDown(auth.dispose);
      addTearDown(operators.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: operators),
          ],
          child: const MaterialApp(home: LoginPage()),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'leonardo.morais',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'ERP-password');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(auth.isAuthenticated, accepted);
      expect(operators.currentOperator?.isAdministrator ?? false, accepted);
      if (!accepted) {
        expect(find.textContaining('Acesso recusado'), findsOneWidget);
      }
      if (accepted) {
        await tester.pump(const Duration(minutes: 5, seconds: 1));
        expect(auth.isAuthenticated, false);
      }
    });
  }
  test('unknown identity does not inherit previous administrator', () {
    final operators = OperatorAssignmentStore();
    operators.acceptProtheusIdentity('leonardo.morais');
    expect(operators.currentOperator!.isAdministrator, true);
    operators.acceptProtheusIdentity('unknown-user');
    expect(operators.currentOperator, isNull);
    operators.dispose();
  });
}
