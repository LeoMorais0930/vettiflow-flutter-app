import 'dart:io';

/// Persistencia em arquivo para as plataformas com `dart:io` — Windows, macOS,
/// Linux e mobile.
///
/// A fila de mutacoes existe para manter rastreaveis os rascunhos locais.
/// Antes disso, no desktop, ela so vivia na memoria: fechar o app perdia tudo.
/// Aqui ela vai para o disco a cada mudanca e volta sozinha na abertura
/// seguinte.
///
/// A escrita passa por um arquivo temporario e um rename. Rename e atomico nos
/// sistemas que atendemos, entao um desligamento no meio da gravacao deixa o
/// arquivo anterior intacto em vez de um JSON pela metade.
class LocalJsonPersistence {
  const LocalJsonPersistence(this.key);

  final String key;

  /// Pasta usada no lugar da padrao do sistema. Os testes apontam para um
  /// diretorio temporario; em producao fica nula.
  static String? directoryOverride;

  /// Sem override, um teste nao encosta no arquivo real do usuario: a suite
  /// roda com `PendingMutationStore()` cru e nao pode herdar — nem sujar — a
  /// fila da maquina de quem roda os testes.
  static bool get _emTeste =>
      directoryOverride == null &&
      Platform.environment.containsKey('FLUTTER_TEST');

  static String? _pastaPadrao() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      final appData = env['APPDATA'];
      if (appData == null || appData.isEmpty) return null;
      return '$appData\\vetti_flow_1_0';
    }
    final home = env['HOME'];
    if (home == null || home.isEmpty) return null;
    if (Platform.isMacOS) {
      return '$home/Library/Application Support/vetti_flow_1_0';
    }
    final xdg = env['XDG_DATA_HOME'];
    if (xdg != null && xdg.isNotEmpty) return '$xdg/vetti_flow_1_0';
    return '$home/.local/share/vetti_flow_1_0';
  }

  File? _arquivo() {
    if (_emTeste) return null;
    final pasta = directoryOverride ?? _pastaPadrao();
    if (pasta == null) return null;
    final nome = key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File('$pasta${Platform.pathSeparator}$nome.json');
  }

  String? read() {
    final arquivo = _arquivo();
    if (arquivo == null) return null;
    try {
      if (!arquivo.existsSync()) return null;
      final conteudo = arquivo.readAsStringSync();
      return conteudo.isEmpty ? null : conteudo;
    } on IOException catch (erro) {
      stderr.writeln('fila local: falha ao ler ${arquivo.path}: $erro');
      return null;
    }
  }

  void write(String payload) {
    final arquivo = _arquivo();
    if (arquivo == null) return;
    try {
      arquivo.parent.createSync(recursive: true);
      final temporario = File('${arquivo.path}.tmp');
      temporario.writeAsStringSync(payload, flush: true);
      temporario.renameSync(arquivo.path);
    } on IOException catch (erro) {
      // Falhar aqui nao pode derrubar a operacao que o usuario acabou de
      // fazer: a mutacao segue valida em memoria.
      stderr.writeln('fila local: falha ao gravar ${arquivo.path}: $erro');
    }
  }

  /// Sem efeito fora do navegador: aqui so este processo escreve o arquivo,
  /// entao nao existe o equivalente a outra aba mexendo no mesmo storage.
  void listen(void Function(String? payload) onChange) {}
}
