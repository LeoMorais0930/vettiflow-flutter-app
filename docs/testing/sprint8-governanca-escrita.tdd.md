# Sprint 8 - Governanca de Escrita TDD

## Fonte

Jornada derivada do roadmap local `docs/sprints_protheus_vettiflow.md`, ajustada pela regra permanente do usuario: o VettiFlow nao move nada no Protheus. Conteudos de roadmap sobre escrita sao requisitos de pesquisa futura, nao permissao para executar escrita.

## Jornadas

1. Como gestor de producao, quero ver claramente que o VettiFlow esta em modo somente leitura antes de qualquer decisao operacional.
2. Como time de integracao, quero uma resposta tecnica padronizada com `writeEnabled=false` para impedir ambiguidade entre leitura e escrita futura.
3. Como desenvolvedor, quero registrar quais rotinas e requisitos ainda precisam de pesquisa sem criar wrapper, payload ou rotina de escrita.

## RED

| Garantia | Comando | Resultado |
|---|---|---|
| API exige governanca de escrita read-only | `api/venv/Scripts/python -m pytest tests/test_mssql_read_backend.py -q` | Falhou porque `app.mssql` ainda nao tinha `write_readiness` |
| Flutter exige modelo, repositorio, rota e tela de governanca | `flutter test test/protheus_write_readiness_test.dart` | Falhou porque os arquivos de write readiness ainda nao existiam |

## GREEN

| # | O que esta garantido | Teste ou comando | Tipo | Resultado |
|---|---|---|---|---|
| 1 | `/api/v1/write-readiness` delega para o backend MSSQL read-only | `api/tests/test_mssql_read_backend.py::test_governanca_escrita_delega_para_backend_read_only` | Integracao API | PASS |
| 2 | Snapshot Dart decodifica `readOnly=true`, `writeEnabled=false`, operacoes bloqueadas e rotinas candidatas | `test/protheus_write_readiness_test.dart::write readiness snapshot keeps Protheus writes disabled` | Unitario | PASS |
| 3 | Cliente Flutter usa apenas `GET` com token `X-API-Token` | `test/protheus_write_readiness_test.dart::API write readiness repository sends GET and token` | Unitario/repository | PASS |
| 4 | App registra a rota `/governanca-protheus` | `test/protheus_write_readiness_test.dart::app registers Protheus write governance route` | Unitario/rota | PASS |
| 5 | Tela mostra `Somente leitura`, `Escrita desabilitada`, `sql_direto`, `MSExecAuto` e rotinas candidatas | `test/protheus_write_readiness_test.dart::write readiness page shows disabled governance` | Widget | PASS |

Comandos GREEN executados:

```text
api/venv/Scripts/python -m pytest tests/test_mssql_read_backend.py -q
11 passed, 1 warning
```

```text
flutter test test/protheus_write_readiness_test.dart
4 passed
```

Validacao ampla ao fim da sprint:

```text
api/venv/Scripts/python -m pytest tests -q
21 passed, 1 warning
```

```text
flutter test
133 passed
```

```text
flutter analyze
No issues found
```

## Evidencia Real Read-Only

Consulta direta pelo novo leitor `write_readiness()`, sem qualquer escrita:

```text
readOnly=True writeEnabled=False status=bloqueada_por_politica database=HMLp12
blockedOperations=abertura_op, apontamento_op, transferencia, desmontagem, sql_direto, configuracao_protheus
candidateRoutines=MATA250, MATA680, MATA681
```

A funcao chama apenas `health()`, que executa `SELECT DB_NAME(), @@SERVERNAME`.

## Gaps

Esta sprint nao cria wrapper ADVPL, nao testa `MSExecAuto`, nao envia payload e nao homologa escrita. Tudo que envolve abertura, apontamento, transferencia, desmontagem, rateio, custos, perda/ganho, rollback, locks, numeracao e reconciliacao pos-rotina fica como mapa de pesquisa futura em projeto separado.

## Regra de Seguranca

Nenhum endpoint de escrita foi criado. A sprint usa somente `GET` no VettiFlow e `SELECT` no SQL Server Protheus. Escrita direta por SQL continua proibida permanentemente.
