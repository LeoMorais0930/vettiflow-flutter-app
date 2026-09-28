class LocalJsonPersistence {
  const LocalJsonPersistence(this.key);

  final String key;

  /// Existe so para a superficie bater com a implementacao de `dart:io`, que e
  /// quem de fato guarda a fila em arquivo. Sem isso o analisador — que resolve
  /// o export condicional para este stub — reclama de quem usa o override.
  static String? directoryOverride;

  String? read() => null;

  void write(String payload) {}

  void listen(void Function(String? payload) onChange) {}
}
