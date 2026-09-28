# Expedição — consulta e separação do fluxo local

24/09/2026. Jornadas derivadas do pedido de concluir o mapeamento dos setores
com a expedição, usando DEV/ADVPL e preservando a leitura do Protheus.

## Garantias

| Comportamento | Teste |
|---|---|
| Endpoint fixo no local físico 10, mês, paginação e escrita rejeitada | `api/tests/test_expedition_read.py` |
| Detalhe fiscal só parte de SD2 ativo do 10 e busca SF2 por filial/documento/série/contraparte/loja/tipo | Teste de identidade fiscal e parâmetros SQL |
| Cabeçalho ausente/ambíguo não vira informação presumida | Testes de detalhe ausente e cabeçalho duplicado; 404/422/503 sem vazar conexão |
| Filtro mensal permanece nas abas e volta à página 1 | `test/expedition_workspace_test.dart` |
| Nota sem efeito no estoque, pedido real, transportadora e rastreio vazio | Teste com TES 609 e abertura dos detalhes de SD2 |
| Mobile e saldo atual; acesso à conferência em rota distinta | Teste a 390×844, navegação pelo botão de conferência local |
| Origem local segue a sequência e não inventa PED- ou “teste aprovado” | Teste de OP começando diretamente na expedição |
| Atalho por perfil | Expedição/admin acessam; operadora de produção sem gestão não recebe atalho |
| Despacho parcial/total local anterior continua funcionando | Dois testes existentes em `test/widget_test.dart`, na rota `/expedicao/fluxo-local` |

## RED e GREEN

Antes da implementação, os quatro testes Python falharam com endpoint 404 e
função de detalhe ausente. Os testes Flutter não compilavam pela ausência da
nova `ExpeditionReadPage`; essa era a implementação esperada pelos testes.
Depois, o teste da conferência local falhou porque faltava a identificação do
fluxo e ainda havia referências fabricadas. Logs RED locais:
`.dart_tool/local-run/expedition-red.log` e `expedition-local-red.log`.

Após implementar, passaram 51 testes Python e os cinco testes focados Flutter.
A primeira suíte completa detectou que um teste antigo tentava tocar “Iniciar
conferencia” fora da área visível após o aviso local ser adicionado. O teste
foi ajustado para rolar até os botões/abas, sem suprimir a verificação de toque.
A suíte completa passou novamente.

## Comandos e resultados

- `api/venv/Scripts/python.exe -m pytest api/tests -q`: **51 passaram**.
- `flutter test --coverage --reporter expanded`: **165 passaram**.
- `flutter analyze`: nenhum problema.
- `flutter build web --no-pub --dart-define-from-file=.dart_tool/vettiflow-local-defines.json`: concluído.
- `git diff --check`: sem erros.

O teste do atalho recebeu também o caso de operadora sem gestão. A execução
focada posterior passou (5 testes), com `--coverage-path=coverage/expedition.lcov.info`:
`expedition_read_page.dart` **100% (13/13)**. Na suíte completa, o repositório
de leitura ficou em **98% (49/50)** e a tela compartilhada em **91% (616/677)**.
Não foi medida cobertura Python nesta rodada. O legado de conferência local
não foi reescrito nem coberto integralmente nesta entrega.

## Verificação com o DEV e navegador

Chamadas HTTP locais conferiram as cinco visões do 10: 93.412 registros de
histórico, 2.183 de estoque, 6.757 OPs e 6.076 contagens; respostas paginadas e
`readOnly=true`. O recorte fiscal dos três meses retornou 1.664 itens. O detalhe
de uma saída encontrou cabeçalho, pedido e transportadora, sem fabricar rastreio.
Resultados resumidos no JSON de evidências da auditoria.

No navegador, a visão geral de setembro mostrou 1.056 registros. A aba Notas
mostrou 256 itens, em seis páginas de 50. A nota 013975 abriu pedido 016053,
item 01, transportadora cadastrada, 1 volume/CAIXAS e rastreio não informado.
A tela foi inspecionada visualmente em desktop; o mobile foi validado por widget.
A expedição foi deixada aberta em `/expedicao`.

## Limites preservados

Nenhuma escrita SQL, rotina ADVPL, emissão de nota, envio de email, compilação
de fonte Protheus, push ou publicação. O build e a API são locais. Não houve
checkpoint Git porque o checkout contém trabalho amplo pré-existente; a
evidência da rodada fica neste relatório, sem misturar commits de outros setores.

Pedidos não faturados, conciliação entre OP local e nota/retorno, coleta/entrega
efetiva e PDF mensal continuam pendentes. Rastreio/log e documento fiscal não
foram tratados como prova de entrega nem como autorização SEFAZ.
