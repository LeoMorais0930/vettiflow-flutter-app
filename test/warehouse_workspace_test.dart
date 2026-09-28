import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_read_repository.dart';
import 'package:vetti_flow_1_0/ui/warehouse/warehouse_read_page.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['VF_CAPTURE_UI'] == '1') {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final file = File(r'C:\Windows\Fonts\segoeui.ttf');
      if (await file.exists()) {
        await (FontLoader(
          'WarehousePreview',
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
  });
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('format keeps fractions, zero and whole values', () {
    expect(warehouseNumber(0), '0');
    expect(warehouseNumber(100), '100');
    expect(warehouseNumber(2.17), '2,17');
    expect(warehouseNumber(null), '—');
  });
  testWidgets('ADM, Vera and Luis have a warehouse shortcut', (tester) async {
    for (final user in ['admin', 'vera', 'luis']) {
      final operator = Operator.all.firstWhere((o) => o.username == user);
      final store = OperatorAssignmentStore()
        ..authenticate(operator.username, operator.password);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: const MaterialApp(
            home: Scaffold(body: WarehouseNavigationButton()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(user == 'admin' ? 'Consulta administrativa' : 'Almoxarifado'),
        findsOneWidget,
        reason: user,
      );
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    }
  });
  testWidgets('warehouse follows shared header, all dates and bounded pages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <Uri>[];
    final repo = WarehouseReadRepository(
      baseUrl: 'http://api',
      httpClient: MockClient((r) async {
        requests.add(r.url);
        return http.Response(
          jsonEncode({
            'items': [],
            'total': 1000,
            'databaseLatestRecord': '20260918',
            'databaseFirstRecord': '19980203',
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      Provider.value(
        value: repo,
        child: const MaterialApp(home: WarehouseReadPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VettiTopBar), findsOneWidget);
    expect(find.text('Todo o período'), findsOneWidget);
    expect(
      find.textContaining('Último registro no DEV: 18/09/2026'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('warehouse-selector')), findsNothing);
    expect(requests.last.queryParameters.containsKey('start'), isFalse);
    expect(requests.last.queryParameters.containsKey('end'), isFalse);
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['page_size'], '50');
    await tester.tap(find.byKey(const ValueKey('page-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20 por página').last);
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['page_size'], '20');
    expect(requests.last.queryParameters['page'], '1');
  });
  testWidgets(
    'administrative warehouse route denies ordinary operator before querying',
    (tester) async {
      final user = Operator.all.firstWhere((o) => o.username == 'vera');
      final store = OperatorAssignmentStore()
        ..authenticate(user.username, user.password);
      var calls = 0;
      final repo = WarehouseReadRepository(
        baseUrl: 'http://api',
        httpClient: MockClient((r) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            Provider.value(value: repo),
          ],
          child: const MaterialApp(
            home: WarehouseReadPage(administrative: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Acesso administrativo'), findsOneWidget);
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
  testWidgets('admin selector contains only the six operational warehouses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final user = Operator.all.firstWhere((o) => o.username == 'admin');
    final store = OperatorAssignmentStore()
      ..authenticate(user.username, user.password);
    final repo = WarehouseReadRepository(
      baseUrl: 'http://api',
      httpClient: MockClient((r) async => http.Response('{}', 200)),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          Provider.value(value: repo),
        ],
        child: const MaterialApp(home: WarehouseReadPage(administrative: true)),
      ),
    );
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const ValueKey('warehouse-selector')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(dropdown.items!.map((item) => item.value), [
      '01',
      '03',
      '05',
      '06',
      '07',
      '10',
    ]);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  testWidgets('failed query can retry; empty result is not a fake balance', (
    tester,
  ) async {
    var fail = true;
    final repo = WarehouseReadRepository(
      baseUrl: 'http://api',
      httpClient: MockClient(
        (r) async => http.Response(
          fail ? '{}' : jsonEncode({'items': [], 'total': 0}),
          fail ? 503 : 200,
        ),
      ),
    );
    await tester.pumpWidget(
      Provider.value(
        value: repo,
        child: const MaterialApp(home: WarehouseReadPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar'), findsOneWidget);
    fail = false;
    await tester.ensureVisible(find.text('Tentar novamente'));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Nenhum registro encontrado'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Nenhum registro encontrado'), findsOneWidget);
  });
  testWidgets('desktop reads all tabs, order commitments and search filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <Uri>[];
    final repo = WarehouseReadRepository(
      baseUrl: 'http://api',
      httpClient: MockClient((r) async {
        requests.add(r.url);
        if (r.url.path.contains('/ops/')) {
          return http.Response(
            jsonEncode({
              'empenhos': [
                {
                  'produto': 'MP-1',
                  'local': '01',
                  'quantidadeOriginal': 2.17,
                  'quantidadeRestante': 0.83,
                },
              ],
              'movimentos': [
                {
                  'produto': 'PA-1',
                  'cf': 'PR0',
                  'tm': '001',
                  'quantidade': 1,
                  'local': '01',
                  'documento': 'DOC-1',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'test:1',
                'code': '200-172',
                'description': 'Componente para produção',
                'op': '01587201001',
                'quantity': 76.5,
                'unit': 'PC',
                'date': '20260918',
                'document': 'DOC-1',
                'kind': 'transfer',
                'flow': 'out',
                'warehouse': '01',
                'otherWarehouse': '05',
                'committed': 2.17,
                'reserved': 0.83,
                'awaitingClassification': 0,
                'produced': 50,
                'closed': 0,
                'reasonDescription': 'PRODUCAO VETTI',
                'peerCount': 1,
              },
            ],
            'total': 1,
            'summary': [
              {'kind': 'transfer', 'flow': 'out', 'reversed': 0, 'count': 1823},
              {'kind': 'receipt', 'flow': 'in', 'reversed': 0, 'count': 242},
              {'kind': 'receipt', 'flow': 'none', 'reversed': 0, 'count': 713},
            ],
            'latestMovement': '20260918',
            'asOf': '2026-09-24T15:00:00Z',
            'database': 'HMLp12',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      Provider.value(
        value: repo,
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'WarehousePreview',
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0077BD),
              ),
            ),
            home: const WarehouseReadPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (Platform.environment['VF_CAPTURE_UI'] == '1') {
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'docs/testing/warehouse-desktop.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    for (final tab in ['Histórico', 'Estoque', 'Inventário', 'OPs']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('01587201001'));
    await tester.pumpAndSettle();
    expect(find.textContaining('MP-1'), findsOneWidget);
    expect(find.textContaining('Restante: 0,83'), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar detalhes'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'DOC-1');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['query'], 'DOC-1');
    expect(requests.last.queryParameters['page'], '1');
    expect(requests.every((r) => r.path.startsWith('/api/v1/')), isTrue);
  });
  test(
    'repository uses GET and preserves decimal quantities and pagination',
    () async {
      final repo = WarehouseReadRepository(
        baseUrl: 'http://api',
        httpClient: MockClient((r) async {
          expect(r.method, 'GET');
          expect(r.url.queryParameters['page'], '2');
          expect(r.url.queryParameters['kind'], 'transfer');
          return http.Response(
            jsonEncode({
              'items': [
                {'quantity': 0.83},
              ],
              'total': 52,
            }),
            200,
          );
        }),
      );
      final data = await repo.fetch(view: 'history', page: 2, kind: 'transfer');
      expect(data.total, 52);
      expect(data.items.single['quantity'], 0.83);
    },
  );
  testWidgets(
    'history shows details, pagination and no write actions on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <Uri>[];
      final repo = WarehouseReadRepository(
        baseUrl: 'http://api',
        httpClient: MockClient((r) async {
          requests.add(r.url);
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'SD3:1',
                  'code': '200-172',
                  'description': 'Componente',
                  'kind': 'transfer',
                  'flow': 'out',
                  'quantity': 0.83,
                  'unit': 'PC',
                  'date': '20260908',
                  'document': '016333066',
                  'warehouse': '01',
                  'otherWarehouse': '05',
                  'reason': '055',
                  'reasonDescription': 'PRODUCAO VETTI',
                  'sequence': '123',
                  'peerCount': 1,
                  'affectsStock': 'S',
                },
              ],
              'total': 51,
              'summary': [],
              'asOf': '2026-09-24T10:00:00',
            }),
            200,
          );
        }),
      );
      final mobileBoundaryKey = GlobalKey();
      await tester.pumpWidget(
        Provider.value(
          value: repo,
          child: RepaintBoundary(
            key: mobileBoundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'WarehousePreview'),
              home: const WarehouseReadPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Histórico'));
      await tester.pumpAndSettle();
      if (Platform.environment['VF_CAPTURE_UI'] == '1') {
        await tester.runAsync(() async {
          final boundary =
              mobileBoundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'docs/testing/warehouse-mobile.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(find.textContaining('0,83'), findsWidgets);
      expect(find.text('Transferir'), findsNothing);
      expect(find.text('Dar baixa'), findsNothing);
      await tester.tap(find.text('200-172').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('016333066'), findsWidgets);
      expect(find.textContaining('PRODUCAO VETTI'), findsWidgets);
      await tester.tap(find.byTooltip('Fechar detalhes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Próxima página'));
      await tester.tap(find.byTooltip('Próxima página'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['page'], '2');
      expect(tester.takeException(), isNull);
    },
  );
}
