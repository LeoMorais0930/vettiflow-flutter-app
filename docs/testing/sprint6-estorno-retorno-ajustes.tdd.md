# Sprint 6 - Estorno, Retorno e Ajustes TDD

## Fonte

Jornadas derivadas do roadmap local `docs/sprints_protheus_vettiflow.md` e da leitura real read-only da `SD3` no Protheus dev/HML.

## Jornadas

1. Como gestor de producao, quero separar estorno de OP, retorno de OP, devolucao manual e requisicao manual para nao misturar movimentos com significados diferentes.
2. Como analista operacional, quero ver documento, OP, usuario, data, motivo, produto, local e quantidade para auditar movimentos especiais.
3. Como time de integracao, quero que essa auditoria continue somente leitura enquanto regras oficiais, motivos e configuracoes nao estiverem 100% mapeados.

## RED

| Garantia | Comando | Resultado |
|---|---|---|
| API exige funcao de leitura de auditoria de estoque | `api/venv/Scripts/python -m pytest tests/test_mssql_read_backend.py -q` | Falhou porque `app.mssql` ainda nao tinha `inventory_audit_movements` |
| Flutter exige modelo, repositorio, rota e tela de auditoria | `flutter test test/protheus_inventory_audit_test.dart` | Falhou porque os arquivos `protheus_inventory_audit.dart`, `protheus_inventory_audit_repository.dart` e `protheus_inventory_audit_page.dart` ainda nao existiam |

## GREEN

| # | O que esta garantido | Teste ou comando | Tipo | Resultado |
|---|---|---|---|---|
| 1 | `/api/v1/auditoria-estoque` delega filtros `filial`, `documento`, `op`, `produto`, `tipo` e `limit` para o backend MSSQL | `api/tests/test_mssql_read_backend.py::test_auditoria_estoque_delega_para_sql_server` | Integracao API | PASS |
| 2 | Snapshot Dart separa `ER0/999`, `DE1/499`, `DE0/400` e `RE0/501` em tipos distintos | `test/protheus_inventory_audit_test.dart::inventory audit snapshot separates special movement types` | Unitario | PASS |
| 3 | Cliente Flutter usa apenas `GET /api/v1/auditoria-estoque` com token `X-API-Token` | `test/protheus_inventory_audit_test.dart::API inventory audit repository sends read-only filters and token` | Unitario/repository | PASS |
| 4 | Tela dedicada mostra movimentos oficiais e selo de somente leitura | `test/protheus_inventory_audit_test.dart::inventory audit page shows official movements read-only` | Widget | PASS |
| 5 | Rota separada `/auditoria-estoque-protheus` fica registrada no app | `test/protheus_inventory_audit_test.dart::app registers dedicated Protheus inventory audit route` | Unitario | PASS |

Comandos GREEN executados:

```text
api/venv/Scripts/python -m pytest tests/test_mssql_read_backend.py -q
9 passed, 1 warning
```

```text
flutter test test/protheus_inventory_audit_test.dart
4 passed
```

Validacao ampla ao fim da sprint:

```text
api/venv/Scripts/python -m pytest tests -q
19 passed, 1 warning
```

```text
flutter test
126 passed
```

```text
flutter analyze
No issues found
```

## Evidencia Real Read-Only

Consulta direta pelo novo leitor `inventory_audit_movements(filial='04')`, sem qualquer escrita:

```text
TOTAL 20
RESUMO estorno_op=1, retorno_op=3, devolucao_manual=10, requisicao_manual=6
ER0/999 estorno_op 016234010 01623401001 550-0899 05 22.0 TATIANE
DE1/499 retorno_op 016234010 01623401001 500-0899 05 22.0 TATIANE
DE1/499 retorno_op 016234010 01623401001 MOD08010201002 05 0.04 TATIANE
DE1/499 retorno_op 016234010 01623401001 MOD08010901002 05 0.02 TATIANE
DE0/400 devolucao_manual Q0000048X 203-059 01 300.0 artur motivo 056
DE0/400 devolucao_manual Q00000477 730-0784 10 17.0 artur motivo 056
DE0/400 devolucao_manual Q00000467 407-002 03 1306.0 artur motivo 056
RE0/501 requisicao_manual Q0000045Y 550-0764 06 16.0 vinicius motivo 051
RE0/501 requisicao_manual Q00000455 550-0907 05 5.0 matheus motivo 051
RE0/501 requisicao_manual Q00000449 550-0899 06 11.0 vinicius motivo 051
RE0/501 requisicao_manual Q0000042U 575-0759 06 5.0 matheus motivo 051
RE0/501 requisicao_manual Q0000042U 550-0779 06 9.0 matheus motivo 051
```

## Gaps

Esta sprint mapeia os movimentos historicos, mas nao fecha a regra oficial de cada rotina. `D3_MOTTRA` aparece como codigo de motivo em exemplos reais (`056`, `051`), entao ainda falta localizar a fonte oficial da descricao desses motivos. Tambem falta confirmar se existe workflow/aprovacao/tabela auxiliar para justificar cada estorno, devolucao manual ou requisicao manual.

## Regra de Seguranca

Nenhum endpoint de escrita foi criado. A sprint usa somente `GET` no VettiFlow e `SELECT` no SQL Server Protheus.
