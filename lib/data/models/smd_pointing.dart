/// Apontamentos do VettiFlow. Não são registros de SD3/MATA250.
class SmdPointing {
  const SmdPointing({
    required this.id,
    required this.quantity,
    required this.at,
    required this.operatorName,
    this.note = '',
    this.reversalOf,
  });
  final String id;
  final num quantity;
  final DateTime at;
  final String operatorName;
  final String note;
  final String? reversalOf;
  bool get isReversal => reversalOf != null;
  Map<String, dynamic> toJson() => {
    'id': id,
    'quantity': quantity,
    'at': at.toIso8601String(),
    'operatorName': operatorName,
    'note': note,
    'reversalOf': reversalOf,
  };
  factory SmdPointing.fromJson(Map<String, dynamic> json) => SmdPointing(
    id: json['id'] as String,
    quantity: json['quantity'] as num,
    at: DateTime.parse(json['at'] as String),
    operatorName: json['operatorName'] as String,
    note: json['note'] as String? ?? '',
    reversalOf: json['reversalOf'] as String?,
  );
}

class SmdProgress {
  const SmdProgress({
    this.entries = const [],
    this.completedAt,
    this.completedBy,
  });
  final List<SmdPointing> entries;
  final DateTime? completedAt;
  final String? completedBy;
  num get produced => entries.fold<num>(
    0,
    (total, entry) =>
        total + (entry.isReversal ? -entry.quantity : entry.quantity),
  );
  num remaining(num planned) => (planned - produced).clamp(0, planned);
  bool isReversed(String id) => entries.any((e) => e.reversalOf == id);
  Map<String, dynamic> toJson() => {
    'entries': entries.map((e) => e.toJson()).toList(),
    'completedAt': completedAt?.toIso8601String(),
    'completedBy': completedBy,
  };
  factory SmdProgress.fromJson(Map<String, dynamic> json) => SmdProgress(
    entries: (json['entries'] as List? ?? [])
        .map((e) => SmdPointing.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
    completedBy: json['completedBy'] as String?,
  );
}
