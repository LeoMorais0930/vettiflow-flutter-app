# Sprint 3 - Roteamento real de locais

## Source plan

Jornadas derivadas de `docs/sprints_protheus_vettiflow.md`, do roadmap profundo e da evidencia real da Sprint 2: OP `01621401001` com SC2 local `05`, entrada `PR0` no local `10` e consumos `RE1` no local `05`.

## User journeys

1. Como gestor, quero ver local da OP, local de consumo e local de entrada do acabado separados.
2. Como operador de expedicao, quero finalizar uma OP somente quando o destino do acabado estiver confiavel.
3. Como desenvolvedor, quero que o plano local PR0/RE1 respeite historico oficial sem escrever no Protheus.
4. Como gestor, quero registrar divergencia quando a sugestao do VettiFlow nao bater com o PR0 oficial.

## RED evidence

Comando:

```powershell
flutter test test/finished_goods_routing_test.dart test/protheus_movements_test.dart
```

Resultado esperado/falha:

```text
Error when reading 'lib/shared/models/finished_goods_routing.dart'
The getter 'finishedGoodsWarehouse' isn't defined for the type 'ProductionOrderFlow'
Expected: '10' / Actual: '05'
Expected: throws StateError / Actual: returned ProtheusProductionCompletionPlan
```

## GREEN evidence

Comando:

```powershell
flutter test test/finished_goods_routing_test.dart test/protheus_movements_test.dart
```

Resultado:

```text
14 passed
All tests passed!
```

Comando de regressao ampliada:

```powershell
flutter test
.\api\venv\Scripts\python.exe -m pytest api\tests
flutter analyze
git diff --check
rg com padroes locais redigidos para senhas e usuario sensiveis
```

Resultado:

```text
Flutter: 115 passed
API: 16 passed, 1 warning
Analyze: No issues found
Diff check: sem erros
Secret scan: sem ocorrencias para senhas/logins sensiveis
```

## Test specification

| # | What is guaranteed | Test file or command | Test type | Result |
|---|---|---|---|---|
| 1 | Produto historico `575-0863` em OP local `05` sugere acabado no local `10` | `test/finished_goods_routing_test.dart` | unit | PASS |
| 2 | Consumo usa armazem real do componente, separado do local de entrada do acabado | `test/finished_goods_routing_test.dart`, `test/protheus_movements_test.dart` | unit | PASS |
| 3 | Produtos sem historico em locais especiais bloqueiam conclusao local | `test/finished_goods_routing_test.dart` | unit/integration | PASS |
| 4 | Plano local PR0 usa destino acabado sugerido e RE1 continua no local do componente | `test/protheus_movements_test.dart` | unit | PASS |
| 5 | Divergencia entre sugestao e PR0 oficial gera aviso auditavel | `test/finished_goods_routing_test.dart` | unit | PASS |

## Coverage and known gaps

Coverage formal nao foi gerada nesta sprint. A suite focada passou, a suite Flutter completa passou, os testes da API passaram, a analise estatica passou e o diff check nao encontrou whitespace quebrado.

Gaps para a proxima sprint:

1. Transferencias entre setores ainda nao estao modeladas como fluxo proprio.
2. Historico `RE4/DE4` ainda nao aparece em uma tela operacional.
3. O mapa produto/familia deve crescer conforme novas evidencias oficiais forem lidas do Protheus.
