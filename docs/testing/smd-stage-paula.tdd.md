# Evidencia TDD - etapa SMD e restricao da Paula

> Registro histórico da demo. Desde 24/09/2026, `/smd` consulta OPs e apontamentos oficiais, sem avanço local para gravação. Consulte [a entrega atual](smd-consulta.tdd.md) e o [guia do SMD](../setores/smd/README.md). As regras abaixo de avanço de etapas descrevem o fluxo local antigo, ainda existente no modelo/painel de gestão.

Data: 2026-08-04

## Jornada

Como responsavel pelo SMD, Paula deve apontar OPs no armazem 03 antes de a OP ir para gravacao, sem conseguir abrir OP ou movimentar etapas de producao/almoxarifado.

## Garantias

| # | Garantia | Teste/comando | Resultado |
|---|---|---|---|
| 1 | Toda etapa de trabalho, incluindo SMD, tem rota registrada no app. | `flutter test test\widget_test.dart` | PASS |
| 2 | Armazem 03 roteia para SMD; armazem 04 nao e tratado como armazem operacional. | `flutter test test\warehouse_routing_test.dart` | PASS |
| 3 | Almoxarifado avanca a OP para SMD, e SMD avanca para gravacao apos apontamento da Paula. | `flutter test test\widget_test.dart --plain-name "SMD stage advances to production firmware after Paula points it"` | PASS |
| 4 | Paula fica restrita a etapa SMD nas atribuicoes. | `flutter test test\widget_test.dart --plain-name "assignment managers only see their own sector"` | PASS |
| 5 | Paula nao consegue criar OP no armazem 03; ela apenas aponta. | `flutter test test\protheus_lookup_test.dart --plain-name "flow repository blocks Paula from creating SMD orders"` | PASS |
| 6 | A UI do Kanban comporta a etapa nova sem overflow nos testes de dashboard. | `flutter test` | PASS, 46 testes |
| 7 | Tatiane visualiza OPs de Almoxarifado/SMD no dashboard, mas nao ve botoes de movimentacao dessas etapas. | `flutter test test\widget_test.dart --plain-name "Tatiane"` | PASS |
| 8 | Tatiane continua podendo movimentar OPs que ja estao nas etapas de producao. | `flutter test test\widget_test.dart --plain-name "Tatiane"` | PASS |
| 9 | Login `paula / 1003` abre direto a tela SMD, sem permissao de gestao no dashboard. | `flutter test test\widget_test.dart --plain-name "Paula routes directly to SMD pointing screen"` | PASS |
| 10 | Armazem escolhido no componente e usado em SB2, SD3 e SD4, inclusive quando diferente do armazem de producao. | `flutter test test\protheus_movements_test.dart` | PASS |
| 11 | OP criada no armazem 05 nasce direto em Gravacao, sem passar por Almoxarifado/SMD. | `flutter test test\protheus_lookup_test.dart --plain-name "flow repository blocks OP creation outside operator warehouses"` | PASS |

## Banco

Migration aplicada localmente:

```sql
ALTER TYPE vettiflow.production_stage ADD VALUE IF NOT EXISTS 'smd' AFTER 'warehouse';
ALTER TYPE vettiflow.work_stage ADD VALUE IF NOT EXISTS 'smd' AFTER 'dashboard';
```

Conferencia legada no banco local:

```text
production_stage:warehouse,smd,firmware,soldering,testing,closing,expedition,storage,completed
work_stage:dashboard,smd,firmware,soldering,testing,closing,expedition,warehouse,support,tv
```

## Validacao final

```text
dart analyze lib test
No issues found!

flutter test
50 tests passed
```
