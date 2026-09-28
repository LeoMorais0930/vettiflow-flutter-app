import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/local_production_report.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_report.dart';
import 'package:vetti_flow_1_0/ui/reports/warehouse_report_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final start = DateTime(2026, 8, 31, 23), finish = DateTime(2026, 9, 1, 1);
  final order = ProductionOrderFlow(
    number: 'OP1',
    productCode: 'P1',
    productName: 'Produto',
    quantity: 100,
    orderWarehouse: '05',
    currentStage: ProductionStage.completed,
    status: ProductionRunStatus.completed,
    priority: 'Normal',
    createdAt: DateTime(2026, 6),
    updatedAt: finish,
    plannedStages: const [ProductionStage.soldering],
    timings: {
      ProductionStage.soldering: ProductionStageTiming(
        startedAt: start,
        completedAt: finish,
        pausedDuration: const Duration(minutes: 30),
      ),
      ProductionStage.testing: ProductionStageTiming(
        startedAt: start,
        completedAt: finish,
      ),
    },
    operatorSessions: [
      ProductionOperatorSession(
        stage: ProductionStage.soldering,
        operatorName: 'Ana',
        operatorPin: 'SECRET',
        startedAt: start,
        completedAt: finish,
        pausedDuration: const Duration(minutes: 30),
        producedQuantity: 7,
      ),
      ProductionOperatorSession(
        stage: ProductionStage.soldering,
        operatorName: 'Bia',
        operatorPin: 'HIDDEN',
        startedAt: finish,
      ),
    ],
    pauseEvents: [
      ProductionPauseEvent(
        stage: ProductionStage.soldering,
        operatorName: 'Ana',
        operatorPin: 'SECRET',
        reason: PauseReason.cafe,
        createdAt: DateTime(2026, 9, 1),
        resumedAt: DateTime(2026, 9, 1, 0, 30),
      ),
    ],
    testDefects: const [
      DefectRecord(code: 'T1', title: 'Defeito', quantity: 2),
    ],
  );
  ReportFilters filters(
    String analysis, {
    String stage = 'all',
    String operator = '',
  }) => ReportFilters(
    analysis: analysis,
    start: DateTime(2026, 9),
    end: DateTime(2026, 9, 30),
    stage: stage,
    operator: operator,
  );
  test(
    'local operator report uses completion date, existing duration and declared quantity without PIN',
    () {
      final report = buildLocalProductionReport(
        [order],
        filters('local_operators', operator: 'ana'),
        at: DateTime(2026, 9, 24),
      );
      expect(report.isLocal, isTrue);
      expect(report.total, 1);
      final row = (report.local!['rows'] as List).single as List;
      expect(row, contains('1h 30min 0s'));
      expect(row, contains('7 un'));
      expect(jsonEncode(report.local), isNot(contains('SECRET')));
      expect(report.filterLabels.join(' '), contains('Operador: ana'));
    },
  );
  test('custom completed stage is included even when OP predates month', () {
    final report = buildLocalProductionReport(
      [order],
      filters('local_stages', stage: 'soldering'),
      at: DateTime(2026, 9, 24),
    );
    expect(report.total, 1);
    expect((report.local!['rows'] as List).single, contains('1h 30min 0s'));
    final old = buildLocalProductionReport(
      [order],
      ReportFilters(
        analysis: 'local_stages',
        start: DateTime(2026, 7),
        end: DateTime(2026, 7, 31),
      ),
      at: DateTime(2026, 9, 24),
    );
    expect(old.total, 0);
  });
  test('local reports build PDF snapshots for all four analyses', () async {
    for (final analysis in [
      'local_stages',
      'local_operators',
      'local_pauses',
      'local_quality',
    ]) {
      final report = buildLocalProductionReport(
        [order],
        filters(analysis),
        at: DateTime(2026, 9, 24),
      );
      expect((report.local!['rows'] as List), isNotEmpty);
      final bytes = await buildWarehouseReportPdf(report);
      expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    }
  });
}
