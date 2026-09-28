# Suporte — consulta do Protheus

24/09/2026. Jornadas derivadas do pedido de avançar para o suporte, mantendo
o padrão dos setores anteriores e a leitura do DEV/ADVPL.

## Jornadas e garantias

| Comportamento | Evidência |
|---|---|
| Consultar somente 06/07 pelo endpoint do suporte, com mês e paginação limitada | `api/tests/test_support_read.py` valida padrão 06, seleção 07, local inválido, datas invertidas, limite e métodos de escrita rejeitados |
| Reunir SD1/SD2 antes da contagem/paginação | Teste de `kind=fiscal` inspeciona as duas consultas, sem expandir o escopo para OPs de outros armazéns |
| Manter mês e reiniciar página ao trocar filtros | `test/support_workspace_test.dart` navega entre abas e entre 06/07 |
| Nota sem efeito no estoque e referências fiscais visíveis | Teste com TES 079/CFOP 2915 abre os detalhes e referências do Protheus |
| Mobile, saldo atual e tentativas de consulta com erro | Testes do suporte em 390×844 e repetição de resposta 503 |
| Defeito local não some quando a OP termina e não vira conserto concluído | OP local com uma etapa, dois itens defeituosos; diálogo preserva dados e identifica a origem local |
| Acesso por atalho | Suporte/gestão navegam; operador de produção sem gestão não recebe o atalho |

## RED → GREEN

Antes da implementação, os três testes de API falharam: endpoint 404 e ausência
do filtro fiscal conjunto. Os testes de interface, com os providers do protótipo
anterior, falharam porque nenhuma consulta era emitida e não havia abas de estoque
nem tratamento de erro da API. Logs locais em `.dart_tool/local-run/support-red.log`.

Na primeira execução integrada, o teste de erro repetido detectou que um Future
de uma nova consulta podia falhar antes de o próximo frame inscrever o FutureBuilder.
Agora o Future é observado imediatamente; o mesmo Future ainda exibe o erro na tela.
O teste continuou exercitando duas respostas 503, sem absorver o erro no teste.

A expectativa de ausência do atalho foi ajustada para Juliana, operadora sem gestão;
a conta Paula usada inicialmente era a gestora do SMD. O comportamento de acesso
existente não foi alterado para satisfazer essa expectativa incorreta.

## Validação

- `api/venv/Scripts/python.exe -m pytest api/tests -q`: **47 passaram**.
- `flutter test --coverage --reporter expanded`: **160 passaram**.
- `flutter analyze`: **nenhum problema**.
- `git diff --check`: sem erros.
- `flutter build web --no-pub --dart-define-from-file=.dart_tool/vettiflow-local-defines.json`: build concluído.

Cobertura de linhas da execução completa: `support_page.dart` 90,0% (36/40),
`warehouse_read_page.dart` 90,9% (571/628), `warehouse_read_repository.dart`
97,9% (46/47). Não foi medida cobertura Python nesta rodada. O protótipo antigo,
fora das rotas, não faz parte da nova consulta.

Chamadas HTTP locais com o token existente e a API ligada ao HMLp12 conferiram
as cinco visões nos dois locais. Histórico completo: 8.755 registros no 06 e
6.492 no 07; inventário: 3.735 e 7.349, respectivamente. As notas dos três meses
retornaram exatamente 5 itens no 06 e 13 no 07, incluindo efeitos in/out/none
conforme TES atual. Todas as respostas têm `readOnly=true` e paginação limitada.

Validação no navegador local após recarregar o build: visão geral 06 com 8.755
registros; troca para 07 com 6.492; aba Notas em setembro/2026 com 2 itens.
A nota 000134, série E, aparece como serviço sem efeito no estoque, enquanto
a nota 013941 aparece como saída. Detalhes e referências fiscais abriram.
O teste mobile foi feito por widget a 390×844; a inspeção visual no navegador
foi desktop. A consulta foi deixada aberta em `/suporte` com filtros padrão.

Não houve checkpoint em Git: o checkout contém trabalho amplo pré-existente
de vários setores. A evidência foi preservada aqui sem criar commits misturando
esse trabalho. Não houve escrita no Protheus, execução de ADVPL, push ou publicação.

## Limites

Não estão implementados atendimento persistente, diagnóstico, requisição de
peças, assinatura ou conciliação automática de defeito/remessa/retorno. Os testes
não afirmam que SD3 ou SC2 representam o estado de um conserto.
