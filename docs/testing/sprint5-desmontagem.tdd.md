# Sprint 5 - Desmontagem TDD

## Fonte

Jornadas derivadas do roadmap local `docs/sprints_protheus_vettiflow.md` e do historico real consultado em modo read-only no Protheus dev/HML.

## Jornadas

1. Como gestor de producao, quero consultar desmontagens Protheus em uma tela separada para nao misturar `RE7/DE7` com kanban de OP.
2. Como analista operacional, quero ver produto origem, componentes retornados, locais e documento para comparar a desmontagem oficial.
3. Como time de integracao, quero um endpoint read-only para reconciliar desmontagens sem inserir, atualizar ou excluir nada no Protheus.

## RED

| Garantia | Comando | Resultado |
|---|---|---|
| API exige funcao de leitura de desmontagens | `api/venv/Scripts/python -m pytest tests/test_mssql_read_backend.py -q` | Falhou porque `app.mssql` ainda nao tinha `dismantling_movements` |
| Flutter exige modelo, repositorio, rota e tela de desmontagens | `flutter test test/protheus_dismantlings_test.dart` | Falhou porque os arquivos `protheus_dismantlings.dart`, `protheus_dismantling_repository.dart` e `protheus_dismantlings_page.dart` ainda nao existiam |

## GREEN

| # | O que esta garantido | Teste ou comando | Tipo | Resultado |
|---|---|---|---|---|
| 1 | `/api/v1/desmontagens` delega filtros `filial`, `documento`, `produto` e `limit` para o backend MSSQL | `api/tests/test_mssql_read_backend.py::test_desmontagens_delega_para_sql_server` | Integracao API | PASS |
| 2 | Snapshot Dart decodifica `RE7/999` e `DE7/499` em origem desmontada e componentes retornados | `test/protheus_dismantlings_test.dart::dismantling snapshot decodes paired RE7/DE7 structure` | Unitario | PASS |
| 3 | Cliente Flutter usa apenas `GET /api/v1/desmontagens` com token `X-API-Token` | `test/protheus_dismantlings_test.dart::API dismantling repository sends read-only filters and token` | Unitario/repository | PASS |
| 4 | Tela dedicada mostra desmontagens oficiais sem acao de envio | `test/protheus_dismantlings_test.dart::dismantling page shows official returns read-only` | Widget | PASS |
| 5 | Rota separada `/desmontagens-protheus` fica registrada no app | `test/protheus_dismantlings_test.dart::app registers dedicated Protheus dismantling route` | Unitario | PASS |

Comandos GREEN executados:

```text
api/venv/Scripts/python -m pytest tests/test_mssql_read_backend.py -q
8 passed, 1 warning
```

```text
flutter test test/protheus_dismantlings_test.dart
4 passed
```

Validacao ampla ao fim da sprint:

```text
api/venv/Scripts/python -m pytest tests -q
18 passed, 1 warning
```

```text
flutter test
122 passed
```

```text
flutter analyze
No issues found
```

```text
git diff --check
sem problemas
```

## Evidencia Real Read-Only

Consulta direta pelo novo leitor `dismantling_movements(filial='04')`, sem qualquer escrita:

```text
DOC Q000004AV TOTAL 0 DIVERG 0
DOC Q000003YV TOTAL 1 DIVERG 0
Q000003YV 575-0888 10 retornos 8 pareada
DOC DESMONT23 TOTAL 1 DIVERG 0
DESMONT23 500-0907 07 retornos 17 pareada
DOC RECENTES TOTAL 5 DIVERG 1
DESMONT20 575-0899 07 retornos 3 pareada
Q000003YV 575-0888 10 retornos 8 pareada
DESMONT23 500-0907 07 retornos 17 pareada
DESMONT22 550-0907 06 retornos 5 pareada
DES200325   retornos 1 sem_origem
Q000004AV_ROWS 0
```

## Gaps

`Q000004AV` nao existe na `SD3` acessivel no recorte atual. A tela ainda e uma consulta geral; filtros visuais por documento/produto podem entrar numa sprint futura sem alterar o contrato read-only.

Esta sprint mapeia movimentos historicos de desmontagem, mas nao valida o calculo oficial de rateio. Esse ponto fica marcado como pesquisa futura porque a rotina Protheus pode depender de custo medio, estrutura, saldo, valor retornado, perda/sucata, parametros de desmontagem ou outros movimentos/documentos alem de `RE7/DE7`.

## Regra de Seguranca

Nenhum endpoint de escrita foi criado. A sprint usa somente `GET` no VettiFlow e `SELECT` no SQL Server Protheus.
