import 'package:intl/intl.dart';
import 'production_flow.dart';
import 'warehouse_report.dart';

String reportDuration(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 1 << 50);
  return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}min ${seconds % 60}s';
}

/// Snapshot of the existing store. Reading reports never changes an OP or session.
WarehouseReport buildLocalProductionReport(
  List<ProductionOrderFlow> source,
  ReportFilters filters, {
  DateTime? at,
}) {
  final now = at ?? DateTime.now();
  final end = filters.end == null
      ? null
      : DateTime(filters.end!.year, filters.end!.month, filters.end!.day + 1);
  bool inPeriod(DateTime? date) =>
      date != null &&
      !date.isAfter(now) &&
      (filters.start == null || !date.isBefore(filters.start!)) &&
      (end == null || date.isBefore(end));
  bool stageMatches(ProductionStage stage) =>
      filters.stage == 'all' || filters.stage == stage.name;
  bool operatorMatches(String name) =>
      filters.operator.trim().isEmpty ||
      name.toLowerCase().contains(filters.operator.trim().toLowerCase());
  const coreStages = {
    ProductionStage.firmware,
    ProductionStage.soldering,
    ProductionStage.testing,
    ProductionStage.closing,
  };
  final orders = source.where((order) {
    final production =
        order.orderWarehouse.trim() == '05' ||
        (order.orderWarehouse.trim().isEmpty &&
            (order.timings.keys.any(coreStages.contains) ||
                order.operatorSessions.any(
                  (s) => coreStages.contains(s.stage),
                )));
    final query = filters.query.trim().toLowerCase();
    return production &&
        (filters.product.trim().isEmpty ||
            order.productCode == filters.product.trim()) &&
        (filters.op.trim().isEmpty || order.number == filters.op.trim()) &&
        (query.isEmpty ||
            '${order.number} ${order.productCode} ${order.productName}'
                .toLowerCase()
                .contains(query));
  }).toList();
  final rows = <List<String>>[];
  final dates = <DateTime>[];
  final involvedOrders = <String>{},
      products = <String>{},
      operators = <String>{};
  final metrics = <String, String>{};
  final notes = <String>[
    'Origem: eventos do VettiFlow neste dispositivo. Não são lançamentos do Protheus e não são somados aos apontamentos oficiais.',
    'OPs locais do 05; registros antigos sem armazém são incluídos quando contêm etapas de produção. Cada OP mantém sua própria sequência de etapas.',
  ];
  void record(ProductionOrderFlow order, DateTime date) {
    dates.add(date);
    involvedOrders.add(order.number);
    products.add(
      order.productCode.isEmpty ? order.productName : order.productCode,
    );
  }

  List<String> headers;
  final stamp = DateFormat('dd/MM/yyyy HH:mm');
  String product(ProductionOrderFlow order) =>
      '${order.number} · ${order.productLabel}';

  if (filters.analysis == 'local_operators') {
    headers = [
      'Encerramento',
      'OP / produto',
      'Etapa',
      'Operador',
      'Tempo ativo',
      'Qtde declarada',
    ];
    var worked = Duration.zero;
    final events = [
      for (final order in orders)
        for (final session in order.operatorSessions)
          if (inPeriod(session.completedAt) &&
              stageMatches(session.stage) &&
              operatorMatches(session.operatorName))
            (order: order, session: session),
    ]..sort((a, b) => b.session.completedAt!.compareTo(a.session.completedAt!));
    for (final event in events) {
      final session = event.session;
      final duration = session.workedDuration(now);
      worked += duration;
      record(event.order, session.completedAt!);
      operators.add(session.operatorName);
      rows.add([
        stamp.format(session.completedAt!),
        product(event.order),
        session.stage.label,
        session.operatorName,
        reportDuration(duration),
        '${reportNumber(session.producedQuantity)} un',
      ]);
    }
    metrics.addAll({
      'Sessões encerradas': '${events.length}',
      'Operadores registrados': '${operators.length}',
      'OPs': '${involvedOrders.length}',
      'Tempo ativo das sessões': reportDuration(worked),
    });
    notes.addAll([
      'Período pelo encerramento da sessão. O tempo ativo usa workedDuration, a regra existente do app: duração da sessão menos pausas. Sessões em andamento ficam fora.',
      'A duração integral pertence à sessão encerrada no recorte, inclusive se começou antes. Tempos de pessoas simultâneas são somados como tempo de trabalho, não como tempo decorrido da OP.',
      'Qtde declarada é producedQuantity da sessão, preenchida nas pausas pela lógica atual. Não é o total final da etapa; zero pode significar que não houve quantidade declarada. Não é usado para classificar eficiência por pessoa.',
    ]);
  } else if (filters.analysis == 'local_pauses') {
    headers = [
      'Retomada',
      'OP / produto',
      'Etapa',
      'Operador',
      'Motivo',
      'Duração',
    ];
    var paused = Duration.zero;
    final events = [
      for (final order in orders)
        for (final event in order.pauseEvents)
          if (inPeriod(event.resumedAt) &&
              stageMatches(event.stage) &&
              operatorMatches(event.operatorName))
            (order: order, event: event),
    ]..sort((a, b) => b.event.resumedAt!.compareTo(a.event.resumedAt!));
    for (final item in events) {
      final event = item.event;
      final duration = event.pauseDuration(now);
      paused += duration;
      record(item.order, event.resumedAt!);
      operators.add(event.operatorName);
      rows.add([
        stamp.format(event.resumedAt!),
        product(item.order),
        event.stage.label,
        event.operatorName,
        event.reasonLabel,
        reportDuration(duration),
      ]);
    }
    metrics.addAll({
      'Pausas encerradas': '${events.length}',
      'Operadores registrados': '${operators.length}',
      'OPs': '${involvedOrders.length}',
      'Tempo das pausas': reportDuration(paused),
    });
    notes.add(
      'Período pela retomada. Duração integral das pausas encerradas no recorte; pausas ainda abertas ficam fora. Não representa tempo parado da linha, pois pessoas podem pausar simultaneamente.',
    );
  } else if (filters.analysis == 'local_quality') {
    headers = [
      'Teste concluído',
      'OP / produto',
      'Lote em teste',
      'Ocorrências de defeito',
      'Tipos registrados',
    ];
    final tested =
        orders
            .where((o) => inPeriod(o.latestCompletion(ProductionStage.testing)))
            .toList()
          ..sort(
            (a, b) => b
                .latestCompletion(ProductionStage.testing)!
                .compareTo(a.latestCompletion(ProductionStage.testing)!),
          );
    var withDefects = 0;
    for (final order in tested) {
      final date = order.latestCompletion(ProductionStage.testing)!;
      record(order, date);
      if (order.totalDefects > 0) withDefects++;
      rows.add([
        stamp.format(date),
        product(order),
        '${order.quantity} un',
        '${order.totalDefects}',
        order.testDefects
            .map((d) => '${d.code} · ${d.title}: ${d.quantity}')
            .join('; '),
      ]);
    }
    metrics.addAll({
      'OPs com teste concluído': '${tested.length}',
      'OPs com defeito registrado': '$withDefects',
      'Produtos': '${products.length}',
    });
    notes.add(
      'Período pela conclusão do teste. O lote é a quantidade da OP; defeitos usam os registros atuais de testDefects. Tipos podem atingir a mesma peça: a soma é de ocorrências, não uma taxa de rejeição ou quantidade de peças únicas.',
    );
  } else {
    headers = ['Etapa', 'Produto', 'Conclusões', 'Tempo total', 'Tempo médio'];
    final groups =
        <
          String,
          ({
            ProductionStage stage,
            String product,
            int count,
            Duration duration,
          })
        >{};
    var completions = 0;
    for (final order in orders) {
      for (final entry in order.allTimings) {
        final timing = entry.value;
        if (!inPeriod(timing.completedAt) ||
            timing.startedAt == null ||
            !stageMatches(entry.key)) {
          continue;
        }
        final duration = timing.elapsed(now);
        if (duration.isNegative) continue;
        record(order, timing.completedAt!);
        completions++;
        final key =
            '${entry.key.name}|${order.productCode}|${order.productName}';
        final old = groups[key];
        groups[key] = (
          stage: entry.key,
          product: order.productLabel,
          count: (old?.count ?? 0) + 1,
          duration: (old?.duration ?? Duration.zero) + duration,
        );
      }
    }
    final sorted = groups.values.toList()
      ..sort(
        (a, b) => a.stage.index != b.stage.index
            ? a.stage.index.compareTo(b.stage.index)
            : a.product.compareTo(b.product),
      );
    for (final group in sorted) {
      rows.add([
        group.stage.label,
        group.product,
        '${group.count}',
        reportDuration(group.duration),
        reportDuration(
          Duration(microseconds: group.duration.inMicroseconds ~/ group.count),
        ),
      ]);
    }
    metrics.addAll({
      'Etapas concluídas': '$completions',
      'OPs': '${involvedOrders.length}',
      'Produtos': '${products.length}',
    });
    notes.add(
      'Período pela conclusão da etapa. O tempo usa ProductionStageTiming.elapsed, já descontando as pausas da lógica do app. Média da duração integral das etapas concluídas, inclusive quando iniciadas antes do mês; não é tempo trabalhado dentro do mês nem soma das sessões individuais.',
    );
  }
  dates.sort();
  final retained = rows.take(100).toList();
  final notice =
      '${retained.length} de ${rows.length} linhas. Indicadores consideram todo o recorte; refine os filtros para detalhar mais.';
  notes.add(notice);
  return WarehouseReport({
    'id': 'local-${now.microsecondsSinceEpoch}',
    'database': 'VettiFlow local',
    'company': 'Vetti',
    'filial': '',
    'sector': 'producao',
    'warehouses': ['05'],
    'scopeNote': notes.first,
    'total': dates.length,
    'summary': [],
    'series': [],
    'products': [],
    'items': [],
    'warehouseSummary': [],
    'productGroupCount': 0,
    'seriesGroupCount': 0,
    'detailStatus': 'not_requested',
    'detailLimit': 100,
    'firstRecord': dates.isEmpty
        ? ''
        : DateFormat('yyyyMMdd').format(dates.first),
    'lastRecord': dates.isEmpty
        ? ''
        : DateFormat('yyyyMMdd').format(dates.last),
    'databaseLatestRecord': '',
    'startedAt': now.toIso8601String(),
    'asOf': now.toIso8601String(),
    'filters': {
      'analysis': filters.analysis,
      'start': filters.start?.toIso8601String().substring(0, 10),
      'end': filters.end?.toIso8601String().substring(0, 10),
      'query': filters.query.trim(),
      'product': filters.product.trim(),
      'op': filters.op.trim(),
      if (['local_operators', 'local_pauses'].contains(filters.analysis))
        'operator': filters.operator.trim(),
      if (filters.analysis != 'local_quality')
        'stageLabel': filters.stage == 'all'
            ? 'Todas'
            : ProductionStage.values
                  .firstWhere((s) => s.name == filters.stage)
                  .label,
    },
    'local': {
      'metrics': [
        for (final metric in metrics.entries)
          {'label': metric.key, 'value': metric.value},
      ],
      'headers': headers,
      'rows': retained,
      'rowCount': rows.length,
      'notice': notice,
      'notes': notes,
    },
  });
}
