# Evidências — almoxarifado somente leitura

Data: 24/09/2026. Jornadas derivadas do pedido de consultar o almoxarifado,
incluindo histórico, para ADM, Vera e Luis. Escopo detalhado em
[contrato do almoxarifado](../setores/almoxarifado/consulta-tecnica.md).

## RED → GREEN

- `api/tests/test_warehouse.py`: falha inicial pela ausência de `app.warehouse`.
  Após implementação, 15 testes passaram. O teste de movimentos relacionados
  também falhou pela ausência de `related_movements` antes da implementação.
- `test/warehouse_workspace_test.dart`: falha inicial pela ausência do
  repositório e da nova tela. Após implementação, seis testes passaram.
- As consultas reais ao DEV identificaram um sombreamento do alias de SB2/SB7
  pelo alias de SB1. Corrigido e protegido por teste; as duas consultas foram
  repetidas com sucesso.

## Garantias verificadas

| Garantia | Evidência |
|---|---|
| Consultas com valores parametrizados, filtros antes da contagem/paginação e limite de página | Testes Python |
| Sem endpoint POST novo; token existente continua obrigatório quando configurado | Testes HTTP com TestClient |
| Datas, armazém, filial, tipo e limites inválidos são recusados | Testes HTTP |
| Falhas não expõem mensagens internas de conexão | Testes HTTP |
| Transferências não exigem igualdade de código dos produtos | Testes SQL + consultas reais |
| Desmontagem pode mostrar origem e destinos em locais diferentes | Teste de chave + consulta real |
| Quantidades fracionadas preservadas | Testes Python/Dart e exemplo real 0,83 |
| ADM, Vera e Luis têm atalho | Teste de widgets com perfis existentes |
| Navegação pelas cinco abas, busca, paginação e detalhes de OP | Testes de widgets |
| Falha de consulta permite tentar novamente; vazio não vira saldo fictício | Teste de widgets |
| Layout desktop 1366×900 e mobile 390×844 sem exceções de layout | Testes + inspeção das capturas |

## Comandos e resultados

- `api/venv/Scripts/python.exe -m pytest -q`, executado em `api`: **36 passed**.
- `flutter test --reporter expanded`: **139 testes passaram**.
- `flutter analyze --no-pub`: **No issues found**.
- `flutter build web --no-pub`: compilação concluída em `build/web`.
- `flutter test test/warehouse_workspace_test.dart --coverage --reporter expanded`:
  **6 testes passaram**. Cobertura de linhas: repositório novo **95,5%** (42/44),
  tela nova **85,3%** (436/511).
- Cobertura Python medida com `trace.Trace` da biblioteca padrão durante a
  execução dos testes do novo módulo: **85,7%** (114/133 linhas executáveis).
- `git diff --check`: sem erros.

As capturas `warehouse-desktop.png` e `warehouse-mobile.png` são de fixtures
dos testes, não uma fotografia dos saldos reais. A validação dos valores reais
foi feita separadamente por SELECT em HMLp12. Não houve execução de ADVPL,
escrita no Protheus, publicação ou teste de movimentação efetiva.

O teste de jornada completa já existente (`full_branch_smoke_test.dart`) também
passou na suíte geral. Não foi realizada automação de navegador real nesta
entrega. Não foram criados commits de checkpoint: o trabalho foi mantido no
diretório com as alterações anteriores do usuário preservadas.

## Revisão de padrão visual, período e perfis — 24/09/2026

Pedido: manter a identidade do app, consultar todo o período sem sobrecarga,
separar a consulta administrativa e usar os seis armazéns originais.

RED: testes Python falharam porque datas omitidas ainda viravam últimos 90 dias.
O teste Flutter falhou inicialmente pela ausência de `administrative`. O teste
de seleção de armazéns mostrou 15 códigos quando deveriam ser seis.

Implementado: VettiTopBar e painéis compartilhados; datas opcionais; 20/50/100
por página; consulta administrativa separada com bloqueio de outros perfis;
lista operacional 01/03/05/06/07/10; datas globais com cache de 60 segundos.

As garantias estão em `api/tests/test_warehouse.py`,
`test/warehouse_workspace_test.dart` e `test/warehouse_routing_test.dart`.
As capturas desta pasta usam fixtures, não são registros reais do DEV.

A árvore de trabalho já continha alterações de outras entregas. Não foram
criados commits de checkpoint para evitar incluir trabalho anterior neste
registro; a evidência RED/GREEN fica nos testes e neste documento.

Validação final da revisão:

- `flutter test --no-pub`: 143 testes passaram.
- `python -m pytest api/tests -q`: 39 testes passaram.
- `flutter analyze --no-pub`: nenhum problema.
- Build web com a configuração local: concluído.
- Cobertura medida na revisão: tela 87,3%, repositório 89,1%;
  API warehouse 89,0% por trace do Python (18 testes específicos).
- Navegador real: abriu HMLp12 com todo o período, confirmou 114.122 registros,
  mudou de 50 para 20 por página e abriu a página 2 de 5.707, com registros diferentes.
- Desktop e mobile: capturas inspecionadas, sem exceções de layout nos testes.
- Links internos: 18 documentos novos/atualizados conferidos, sem destino inexistente.

A revisão não executou escrita, compilação ADVPL ou alterações na VM/banco.
A API e o servidor web foram iniciados apenas na máquina local, em loopback.
