import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/repositories/commitment_review_repository.dart';
import 'package:vetti_flow_1_0/ui/protheus/commitment_review_page.dart';

class ReviewFake extends CommitmentReviewRepository {
  Map<String, dynamic>? sent;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> load(String op, String filial) async => {
    'order': {
      'numero': op,
      'produto': '550-0863E',
      'produtoDescricao': 'Central de alarme',
      'quantidadePlanejada': 1000,
      'local': '05',
    },
    'version': 0,
    'fingerprint': 'fixture',
    'canSave': true,
    'stale': false,
    'excluded': [],
    'items': [
      {
        'id': 1,
        'produto': '730-0910',
        'descricao': 'Placa eletrônica montada',
        'local': '03',
        'quantidade': 1000,
        'unidade': 'UN',
      },
      {
        'id': 2,
        'produto': '203-006',
        'descricao': 'Gabinete plástico',
        'local': '01',
        'quantidade': 1000,
        'unidade': 'UN',
      },
      {
        'id': 3,
        'produto': '301-012',
        'descricao': 'Parafuso de fixação',
        'local': '01',
        'quantidade': 4000,
        'unidade': 'UN',
      },
      {
        'id': 4,
        'produto': '406-020',
        'descricao': 'Cabo de conexão',
        'local': '01',
        'quantidade': 1000,
        'unidade': 'UN',
      },
      {
        'id': 5,
        'produto': '509-002',
        'descricao': 'Etiqueta de identificação',
        'local': '01',
        'quantidade': 1000,
        'unidade': 'UN',
      },
      {
        'id': 6,
        'produto': 'MOD001',
        'descricao': 'Mão de obra',
        'local': '10',
        'quantidade': 1000,
        'unidade': 'HR',
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> save(
    String op,
    String filial,
    Map<String, dynamic> body,
  ) async {
    if (fail) throw StateError('Falha ao salvar');
    sent = body;
    return {
      ...await load(op, filial),
      'version': 1,
      'excluded': body['excluded'],
    };
  }
}

class DispatchFake extends ReviewFake {
  int submissions = 0;
  @override
  Future<Map<String, dynamic>> load(String op, String filial) async => {
    ...await super.load(op, filial),
    'canSubmit': true,
    'executionEnabled': true,
  };
  @override
  Future<Map<String, dynamic>> submit(
    String op,
    String filial,
    Map<String, dynamic> body,
  ) async {
    submissions++;
    return {'id': 'queue-test', 'status': 'pendente'};
  }
}

void main() {
  testWidgets('only queues saved selection after confirmation', (tester) async {
    tester.view.physicalSize = const Size(1280, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = DispatchFake();
    await tester.pumpWidget(
      MaterialApp(
        home: CommitmentReviewPage(op: '01642901001', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exclude-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar revisão'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar ao Protheus'));
    await tester.pumpAndSettle();
    expect(repo.submissions, 0);
    expect(find.textContaining('1 empenho'), findsWidgets);
    await tester.tap(find.text('Confirmar envio'));
    await tester.pumpAndSettle();
    expect(repo.submissions, 1);
    expect(find.textContaining('Aguardando execução'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'review at $width supports exclude undo and save with no ERP claim',
      (tester) async {
        tester.view.physicalSize = Size(width, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repository = ReviewFake();
        await tester.pumpWidget(
          MaterialApp(
            home: CommitmentReviewPage(
              op: '01642901001',
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
        await tester.tap(find.byKey(const ValueKey('exclude-1')));
        await tester.pumpAndSettle();
        expect(find.text('Desfazer'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('exclude-1')));
        await tester.pumpAndSettle();
        expect(find.text('Desfazer'), findsNothing);
        await tester.ensureVisible(find.byKey(const ValueKey('exclude-2')));
        await tester.tap(find.byKey(const ValueKey('exclude-2')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Salvar revisão'));
        await tester.tap(find.text('Salvar revisão'));
        await tester.pumpAndSettle();
        expect((repository.sent!['excluded'] as List).single['id'], 2);
        expect(
          find.textContaining('Nenhum empenho foi excluído no Protheus'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('capture implemented review with demonstration data', (
    tester,
  ) async {
    final regular = FontLoader('ReviewFont')
      ..addFont(rootBundle.load('assets/fonts/IBMPlexSans-Regular.ttf'));
    await regular.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.physicalSize = const Size(1280, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'ReviewFont',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff0077bd),
            ),
          ),
          home: CommitmentReviewPage(
            op: '01642901001',
            repository: ReviewFake(),
            demonstration: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exclude-1')));
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 1);
      final png = await picture.toByteData(format: ui.ImageByteFormat.png);
      await Directory('output').create(recursive: true);
      await File(
        'output/revisao-empenhos.png',
      ).writeAsBytes(png!.buffer.asUint8List());
      picture.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
