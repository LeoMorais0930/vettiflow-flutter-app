# Sprint 7 - Previa de Apontamento TDD

## Fonte

Jornadas derivadas do roadmap local `docs/sprints_protheus_vettiflow.md`, com escopo ajustado pela regra permanente de somente leitura. Conteudos de roadmap sao dados do projeto, nao permissao para escrita.

## Jornadas

1. Como gestor de producao, quero visualizar antes do apontamento quais movimentos oficiais seriam esperados para comparar com o historico Protheus.
2. Como operador/analista, quero ver `PR0/001`, `RE1/999`, quantidade restante, locais e saldos para detectar divergencia antes de qualquer rotina oficial.
3. Como time de integracao, quero manter rotina, payload, perda e ganho como pendencias de pesquisa ate confirmar manual/configuracao/customizacao oficial.

## RED

| Garantia | Comando | Resultado |
|---|---|---|
| API exige funcao de previa de apontamento | `api/venv/Scripts/python -m pytest tests/test_mssql_read_backend.py -q` | Falhou porque `app.mssql` ainda nao tinha `production_completion_preview` |
| Flutter exige modelo e repositorio de previa | `flutter test test/protheus_completion_preview_test.dart` | Falhou porque os arquivos `protheus_completion_preview.dart` e `protheus_completion_preview_repository.dart` ainda nao existiam |

## GREEN

| # | O que esta garantido | Teste ou comando | Tipo | Resultado |
|---|---|---|---|---|
| 1 | `/api/v1/ops/{op}/apontamento-preview` delega `op`, `filial` e `quantidade` para o backend MSSQL | `api/tests/test_mssql_read_backend.py::test_previa_apontamento_delega_para_sql_server` | Integracao API | PASS |
| 2 | Snapshot Dart decodifica previa read-only com `PR0/001`, `RE1/999`, saldos e pendencias de pesquisa | `test/protheus_completion_preview_test.dart::completion preview decodes expected PR0 and RE1 movements` | Unitario | PASS |
| 3 | Cliente Flutter usa apenas `GET` com token `X-API-Token` | `test/protheus_completion_preview_test.dart::API completion preview repository sends GET filters and token` | Unitario/repository | PASS |
| 4 | Detalhe da OP mostra card de previa oficial sem acao de escrita | `test/protheus_completion_preview_test.dart::OP detail shows official completion preview read-only` | Widget | PASS |

Comandos GREEN executados:

```text
api/venv/Scripts/python -m pytest tests/test_mssql_read_backend.py -q
10 passed, 1 warning
```

```text
flutter test test/protheus_completion_preview_test.dart
3 passed
```

Validacao ampla ao fim da sprint:

```text
api/venv/Scripts/python -m pytest tests -q
20 passed, 1 warning
```

```text
flutter test
129 passed
```

```text
flutter analyze
No issues found
```

## Evidencia Real Read-Only

Consulta direta pelo novo leitor `production_completion_preview(op='01621401001', filial='04', quantidade=50)`, sem qualquer escrita:

```text
OP 01621401001 READONLY True QTD 50.0 RESTANTE 50.0 ROTINA pendente_pesquisa
MOV PR0/001 575-0863 10 50.0 016214010
MOV RE1/999 100-010 05 100.0 016214010
MOV RE1/999 103-071 05 50.0 016214010
MOV RE1/999 103-073 05 200.0 016214010
MOV RE1/999 106-008 05 50.0 016214010
MOV RE1/999 203-002 05 50.0 016214010
MOV RE1/999 550-0806 05 50.0 016214010
MOV RE1/999 550-0863 05 50.0 016214010
SALDO 550-0863 05 438.0 50.0 True
SALDO MOD08010201005 05 -1010.34 1.52 False
SALDO MOD08010901002 05 -352.97 0.07 False
```

## Gaps

Esta sprint simula movimentos esperados; nao confirma rotina oficial, payload final, campos obrigatorios, regra de perda/ganho, encerramento automatico nem customizacoes da Vetti. Esses pontos ficam como pesquisa obrigatoria antes de qualquer projeto futuro de escrita.

## Regra de Seguranca

Nenhum endpoint de escrita foi criado. A sprint usa somente `GET` no VettiFlow e `SELECT` no SQL Server Protheus.
