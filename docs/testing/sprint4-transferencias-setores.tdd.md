# Sprint 4 - Transferencias entre setores

## Source plan

Jornadas derivadas de `docs/sprints_protheus_vettiflow.md` e da leitura real do Protheus em modo somente leitura.

## User journeys

1. Como gestor, quero consultar transferencias oficiais entre locais sem misturar com baixa de OP.
2. Como operador, quero enxergar origem, destino, produto, quantidade e documento de cada transferencia.
3. Como desenvolvedor, quero parear `RE4/999` e `DE4/499` por documento/produto/quantidade/data.
4. Como gestor, quero ver divergencia quando o par `RE4/DE4` estiver incompleto.

## RED evidence

Comando:

```powershell
.\api\venv\Scripts\python.exe -m pytest api\tests\test_mssql_read_backend.py -k transferencias
```

Resultado esperado/falha:

```text
AttributeError: module 'app.mssql' has no attribute 'transfer_movements'
```

Comando:

```powershell
flutter test test/protheus_transfers_test.dart
```

Resultado esperado/falha:

```text
Error when reading 'lib/data/models/protheus_transfers.dart'
Error when reading 'lib/data/repositories/protheus_transfer_repository.dart'
```

## GREEN evidence

Comando:

```powershell
.\api\venv\Scripts\python.exe -m pytest api\tests\test_mssql_read_backend.py -k transferencias
```

Resultado:

```text
1 passed, 6 deselected, 1 warning
```

Comando:

```powershell
flutter test test/protheus_transfers_test.dart
```

Resultado:

```text
3 passed
All tests passed!
```

Comando de regressao ampliada:

```powershell
.\api\venv\Scripts\python.exe -m pytest api\tests
flutter test
flutter analyze
git diff --check
rg com padroes locais redigidos para senhas e usuario sensiveis
```

Resultado:

```text
API: 17 passed, 1 warning
Flutter: 118 passed
Analyze: No issues found
Diff check: sem erros
Secret scan: sem ocorrencias para senhas/logins sensiveis
```

## Real read-only validation

Comando executado sem imprimir credenciais:

```powershell
python -c "from app import mssql; data=mssql.transfer_movements(filial='04', limit=5); print(...)"
```

Resultado confirmado:

```text
filial 04
total 5
Q0000049I 550-0845 70 -> 05 500.0 pareada
Q00000499 300-072 70 -> 01 1500.0 pareada
016226062 460-015 01 -> 10 1.0 pareada
016226061 103-071 05 -> 10 200.0 pareada
016226061 103-073 05 -> 10 800.0 pareada
divergencias 0
```

## Test specification

| # | What is guaranteed | Test file or command | Test type | Result |
|---|---|---|---|---|
| 1 | API exposes `/api/v1/transferencias` and delegates to SQL Server read helper | `api/tests/test_mssql_read_backend.py` | integration | PASS |
| 2 | Flutter decodes transfer snapshot with route `01 -> 05` and movements `RE4/999`, `DE4/499` | `test/protheus_transfers_test.dart` | unit | PASS |
| 3 | Flutter repository sends filial, produto, origem, destino, limit and `X-API-Token` | `test/protheus_transfers_test.dart` | unit | PASS |
| 4 | OP detail panel shows official transfers in read-only mode | `test/protheus_transfers_test.dart` | widget | PASS |
| 5 | Real SQL Server read returns paired transferencias without Protheus mutation | real read-only validation | integration | PASS |

## Coverage and known gaps

Coverage formal nao foi gerada nesta sprint. A suite Flutter completa passou, os testes da API passaram, a analise estatica passou, o diff check nao encontrou whitespace quebrado e o scan de segredos nao encontrou credenciais sensiveis.

Gaps para a proxima sprint:

1. Criar tela operacional propria para buscar transferencias por periodo/local, fora do detalhe da OP.
2. Ampliar amostras oficiais para confirmar `01 -> 05` e `01 -> 70`.
3. A Sprint 5 deve separar desmontagem (`RE7/DE7`) do modulo de transferencia comum.
