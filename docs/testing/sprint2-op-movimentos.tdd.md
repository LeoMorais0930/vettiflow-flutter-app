# Sprint 2 - Movimentos oficiais por OP

## Source plan

Jornadas derivadas de `docs/sprints_protheus_vettiflow.md` e do roadmap `docs/roadmap_profundo_protheus_movimentacoes_2026-09-09.md`.

## User journeys

1. Como gestor, quero abrir uma OP no VettiFlow e ver os movimentos oficiais do Protheus ligados a ela.
2. Como operador, quero distinguir entrada de acabado `PR0`, consumo `RE1`, reversao `ER0` e retorno `DE1`.
3. Como desenvolvedor, quero um endpoint read-only que agregue `SC2`, `SD4` e `SD3` sem criar risco de escrita.
4. Como gestor, quero ver divergencias como OP local `05` com acabado entrando no local `10`.

## RED evidence

Comando:

```powershell
.\api\venv\Scripts\python.exe -m pytest api\tests\test_mssql_read_backend.py
```

Resultado esperado/falha:

```text
AttributeError: module 'app.mssql' has no attribute 'op_movements'
```

Comando:

```powershell
flutter test test\protheus_op_movements_test.dart
```

Resultado esperado/falha:

```text
Error when reading 'lib/data/models/protheus_op_movements.dart'
Error when reading 'lib/data/repositories/protheus_op_movement_repository.dart'
```

## GREEN evidence

Comando:

```powershell
.\api\venv\Scripts\python.exe -m pytest api\tests\test_mssql_read_backend.py
```

Resultado:

```text
6 passed, 1 warning in 0.34s
```

Comando:

```powershell
flutter test test\protheus_op_movements_test.dart
```

Resultado:

```text
2 passed
All tests passed!
```

Comando final focado:

```powershell
.\api\venv\Scripts\python.exe -m pytest api\tests\test_mssql_read_backend.py && flutter test test\protheus_op_movements_test.dart test\protheus_read_only_test.dart test\warehouse_routing_test.dart test\protheus_warehouses_test.dart test\fila_protheus_page_test.dart test\api_token_test.dart test\abertura_op_protheus_test.dart test\full_branch_smoke_test.dart
```

Resultado:

```text
API: 6 passed, 1 warning in 0.32s
Flutter: 19 passed
All tests passed!
```

Comando de analise estatica:

```powershell
flutter analyze
```

Resultado:

```text
No issues found! (ran in 5.3s)
```

Comando de regressao ampliada:

```powershell
.\api\venv\Scripts\python.exe -m pytest api\tests
flutter test
```

Resultado:

```text
API: 16 passed, 1 warning in 0.37s
Flutter: 107 passed
All tests passed!
```

## Real read-only validation

Comando executado sem imprimir credenciais:

```powershell
python -c "from app import mssql; data=mssql.op_movements('01621401001','04'); print(...)"
```

Resultado confirmado:

```text
status: apontada_parcial
SC2: produto 575-0863, planejado 150, produzido 100, local 05
SD3: 10 movimentos oficiais
primeiro movimento: PR0/001, produto 575-0863, local 10, quantidade 100, documento 016214010, D3_NUMSEQ 416149
consumos seguintes: RE1/999 no local 05
divergencia: Produto acabado entrou em 10, diferente do local da OP 05.
```

## Test specification

| # | What is guaranteed | Test file or command | Test type | Result |
|---|---|---|---|---|
| 1 | API delegates `/api/v1/ops/{op}/movimentos` to SQL Server helper with filial | `api/tests/test_mssql_read_backend.py` | integration | PASS |
| 2 | SQL Server helper reads `SC2`, `SD4` and `SD3` without write route | real read-only validation | integration | PASS |
| 3 | Flutter repository calls the read endpoint and decodes status, commitments and movements | `test/protheus_op_movements_test.dart` | unit | PASS |
| 4 | Model exposes labels/totals for `PR0`, `RE1`, `ER0`, `DE1`, perda, ganho and estorno | `test/protheus_op_movements_test.dart` | unit | PASS |
| 5 | OP detail shows official Protheus movements in read-only mode | `test/protheus_op_movements_test.dart` | widget | PASS |

## Coverage and known gaps

Coverage was not run for the whole project in this slice. Focused RED/GREEN tests were run for API routing, Flutter decoding, model derivations, the OP detail card, and the read-only regressions from Sprint 1. Full API and Flutter test suites passed. Static analysis passed with `flutter analyze`.

Remaining post-Sprint 2 gaps:

1. Let dashboard OP numbers link automatically to official OPs when VettiFlow local numbers differ from Protheus `C2_NUM+C2_ITEM+C2_SEQUEN`.
2. Build Sprint 3 route rules using the observed `C2_LOCAL` x `PR0.D3_LOCAL` differences.
