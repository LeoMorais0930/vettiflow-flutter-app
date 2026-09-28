# Produção: consulta e sequência — 24/09/2026

Jornadas derivadas da orientação de Leonardo: Tatiane/Andressa escolhem início, etapas e fim; Protheus permanece somente leitura; histórico da produção inclui destinos fora do 05.

## RED e GREEN

Antes da implementação, `test/production_workspace_test.dart` falhou ao compilar pelas ausências de ProductionReadPage e plannedStages na criação. Os testes da API falharam com rota 404 e ausência do escopo de OPs vinculadas. Esses eram os recursos novos exercitados pelos testes.

Após implementar:

- `flutter test --coverage --reporter expanded`: 154 testes aprovados na suíte geral.
- Após adicionar a verificação do atalho de gestão: oito testes de `production_workspace_test.dart` aprovados. A suíte passa a conter 155 testes; não foi repetida inteira após adicionar somente esse teste.
- `flutter analyze`: sem problemas.
- `api/venv/Scripts/python.exe -m pytest api/tests -q`: 44 aprovados, com aviso já existente de depreciação de httpx.

## Garantias

| Comportamento | Evidência |
|---|---|
| Escolher a primeira e a última etapa na criação | DTO → repositório → store; Teste → Soldagem, sem expedição inserida |
| Encerrar em um posto único | OP de fechamento fica completed; dispatchedQuantity continua zero |
| Voltar respeita a sequência escolhida | Voltar de Soldagem para Teste em uma sequência personalizada |
| Rejeitar sequência inválida/repetida | Erro antes de criar qualquer OP local |
| Reordenar no celular, cancelar sem salvar | Teste de diálogo a 390 × 844 |
| Exibir o destino planejado | Operador vê Fim da sequência quando a OP termina em gravação |
| Consulta paginada com mês | GET /api/v1/producao; mês preservado entre abas; fração e destino 10 visíveis |
| Abrir consulta por Tatiane, Andressa e ADM | Teste do atalho Produção · Protheus |
| Proteger o escopo e ocultar erros internos | API fixa local 05, limita página a 100, valida datas, só aceita GET e retorna erro genérico |

Na suíte geral, cobertura de linhas: consulta compartilhada 89,9%; seletor novo de etapas 100%. ProductionFlowStore legado fica em 70,8% no arquivo inteiro; não foi alegada cobertura de 80% para seus fluxos antigos de persistência/serialização. As novas transições são exercitadas pelos testes focais. Não foram criados commits de checkpoint para não agregar as numerosas alterações anteriores já existentes no diretório; a evidência RED/GREEN está registrada aqui.

Consultas reais somente SELECT: setembro retornou 19 OPs abertas emitidas no mês, 49 apontamentos e 316 consumos, incluindo produto acabado no 10 ligado a OP do 05.

Após incluir o teste do atalho, os dois arquivos novos de UI (`production_read_page.dart` e `production_route_field.dart`) atingiram 100% de cobertura de linhas na execução focal.

Build web concluído e servido em 127.0.0.1:5174. API reiniciada em 127.0.0.1:8000. A chamada HTTP real a `/api/v1/producao` retornou 200, readOnly=true e destinos 05/10. No navegador, a tela mostrou 139 OPs abertas sem corte; selecionar setembro reduziu para 19. Trocar para Apontamentos preservou o mês e mostrou 49 registros com Tatiane/Andressa e o armazém efetivo. Layout conferido sem sobreposição. O componente novo de sequência foi verificado em desktop e celular pelos testes de widget.
