# Sprint 1 - Locais oficiais Protheus

## Source plan

Jornadas derivadas de `docs/sprints_protheus_vettiflow.md` e do roadmap `docs/roadmap_profundo_protheus_movimentacoes_2026-09-09.md`.

## User journeys

1. Como gestor do VettiFlow, quero que o app leia os locais oficiais do Protheus para nao depender de um mapa incompleto.
2. Como operador, quero que locais como PTH e terceiros existam no app para a OP ou transferencia nao cair em um armazem desconhecido.
3. Como desenvolvedor, quero um contrato testado entre API e Flutter para evoluir as proximas sprints com seguranca.
4. Como gestor, quero que o app deixe explicito que o Protheus esta em modo somente leitura.
5. Como desenvolvedor, quero que `push` e `finalizar` nao chamem HTTP enquanto o produto estiver em leitura apenas.

## RED evidence

Comando:

```powershell
.\api\venv\Scripts\python.exe -m pytest api\tests\test_mssql_read_backend.py
```

Resultado esperado/falha:

```text
FAILED test_locais_delega_para_sql_server
AttributeError: module 'app.mssql' has no attribute 'warehouses'
```

Comando:

```powershell
flutter test test\warehouse_routing_test.dart test\protheus_warehouses_test.dart
```

Resultado esperado/falha:

```text
Error when reading 'lib/data/repositories/protheus_warehouse_repository.dart'
Expected: WorkArea.production
Actual: null
```

Comando:

```powershell
.\api\venv\Scripts\python.exe -m pytest api\tests\test_mssql_read_backend.py
```

Resultado esperado/falha:

```text
KeyError: 'readOnly'
```

Comando:

```powershell
flutter test test\protheus_read_only_test.dart
```

Resultado esperado/falha:

```text
The method 'healthInfo' isn't defined for the type 'ProtheusSyncClient'
```

## GREEN evidence

Comando:

```powershell
.\api\venv\Scripts\python.exe -m pytest api\tests\test_mssql_read_backend.py
```

Resultado:

```text
5 passed, 1 warning in 0.44s
```

Comando:

```powershell
flutter test test\warehouse_routing_test.dart test\protheus_warehouses_test.dart
```

Resultado:

```text
All tests passed!
```

Comando:

```powershell
flutter test test\protheus_read_only_test.dart test\warehouse_routing_test.dart test\protheus_warehouses_test.dart
```

Resultado:

```text
All tests passed!
```

Comando final focado:

```powershell
flutter test test\protheus_read_only_test.dart test\warehouse_routing_test.dart test\protheus_warehouses_test.dart test\fila_protheus_page_test.dart test\api_token_test.dart test\abertura_op_protheus_test.dart test\full_branch_smoke_test.dart
```

Resultado:

```text
17 passed
All tests passed!
```

Comando de analise estatica:

```powershell
flutter analyze
```

Resultado:

```text
No issues found! (ran in 6.0s)
```

## Real read-only validation

Comando executado com `VF_PROTHEUS_DATABASE` alternando entre `HMLp12` e `VettiP12`, sem imprimir credenciais:

```powershell
python -c "from app import mssql; rows=mssql.warehouses('04'); print(...)"
```

Resultado confirmado nas duas bases:

```text
01 - ALMOXARIFADO
02 - USA
03 - PRODUCAO SMD
04 - PRODUCAO PTH
05 - PRODUCAO MEC
06 - ASSIST TECNICA
07 - SUPORTE EXTERNO
08 - ITENS OBSOLETOS
10 - EXPEDICAO
11 - ESTOQUE ADRIAN
12 - ITENS ENTREGA FUTURA
70 - TERCEIROS - MAURO
71 - TER.- FENIX JUNDIAI
72 - TER. - GWANDS SP
73 - TER. TRAFO
```

## Test specification

| # | What is guaranteed | Test file or command | Test type | Result |
|---|---|---|---|---|
| 1 | API `/api/v1/locais` delegates to SQL Server helper with filial | `api/tests/test_mssql_read_backend.py` | integration | PASS |
| 2 | SQL Server helper returns official NNR fields | real read-only validation | integration | PASS |
| 3 | Flutter decodes official warehouse payload from API | `test/protheus_warehouses_test.dart` | unit | PASS |
| 4 | Warehouse model classifies PTH, terceiros and special locations | `test/protheus_warehouses_test.dart` | unit | PASS |
| 5 | Static routing knows `04`, `70`, `72` and keeps legacy labels | `test/warehouse_routing_test.dart` | unit | PASS |
| 6 | API health declares read-only mode | `api/tests/test_mssql_read_backend.py` | integration | PASS |
| 7 | Flutter health client exposes database/company/readOnly | `test/protheus_read_only_test.dart` | unit | PASS |
| 8 | Fila Protheus shows read-only mode and no write actions | `test/protheus_read_only_test.dart` | widget | PASS |
| 9 | Queue shortcut uses read-only local draft language | `test/fila_protheus_page_test.dart` | widget | PASS |
| 10 | `push` and `finalizar` return local read-only errors without HTTP | `test/api_token_test.dart`, `test/full_branch_smoke_test.dart`, `test/abertura_op_protheus_test.dart` | unit | PASS |

## Coverage and known gaps

Coverage was not run for the whole project in this slice. Focused RED/GREEN tests were run for the API endpoint, Flutter API repository, model classification, routing fallback, UI read-only state, and local write-blocking behavior. Static analysis passed with `flutter analyze`.

Remaining post-Sprint 1 gap:

1. Replace more UI dropdowns with dynamic locations from `GET /api/v1/locais` instead of relying only on the static fallback.
