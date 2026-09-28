/// Credencial da API do Protheus, num lugar so.
///
/// A API exige `X-API-Token` quando esta configurada com `VF_API_TOKEN`. Sem o
/// cabecalho ela responde 401 — e sem token nenhum configurado do lado dela,
/// so atende localhost. O valor entra em tempo de build:
///
/// ```bash
/// flutter run --dart-define=VETTIFLOW_API_TOKEN=o-token-combinado
/// ```
class ApiSettings {
  const ApiSettings._();

  static const token = String.fromEnvironment('VETTIFLOW_API_TOKEN');

  /// Cabecalhos de toda chamada. O token so entra quando foi definido no
  /// build; sem ele a requisicao sai limpa, como antes.
  static Map<String, String> headers({bool json = false}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (token.isNotEmpty) 'X-API-Token': token,
    };
  }
}
