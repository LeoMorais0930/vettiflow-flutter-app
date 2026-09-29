// Configuração da API do Protheus.
// A chave interna é adicional ao JWT individual em memória.
import 'package:http/http.dart' as http;
import 'protheus_auth_session.dart';

class ApiSettings {
  const ApiSettings._();

  static const token = String.fromEnvironment('VETTIFLOW_API_TOKEN');
  static const baseUrl = String.fromEnvironment(
    'VETTIFLOW_API_URL',
    defaultValue: 'http://localhost:8000',
  );
  static final session = ProtheusAuthSession(baseUrl: baseUrl, apiKey: token);
  static http.Client createClient() => session.createClient();

  /// Cabecalhos de toda chamada. O token so entra quando foi definido no
  /// build; sem ele a requisicao sai limpa, como antes.
  static Map<String, String> headers({bool json = false}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (token.isNotEmpty) 'X-API-Token': token,
    };
  }
}
