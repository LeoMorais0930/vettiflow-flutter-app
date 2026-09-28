# Expedição — DEV e ADVPL

Verificado em 24/09/2026. Base HMLp12, empresa 010, filial 04, local 10
(`EXPEDICAO` em NNR). Exclusivamente SELECT; nenhum ADVPL executado ou alterado.
[SQL, parâmetros e resultados](expedicao-evidencias.json).

## O que movimenta

Recorte inclusivo de 24/06/2026 a 24/09/2026: **4.406 registros SD3, 100 itens
SD1 e 1.564 itens SD2**. Não somar isso como peças, pedidos ou cargas.

| Movimento interno | Registros recentes |
|---|---:|
| Apontamento PR0/001 | 766 |
| Consumo RE1/999 | 2.924 |
| Entrada por transferência DE4/499 | 464 |
| Saída por transferência RE4/999 | 236 |
| Ajuste DE0/400 | 7 |
| Desmontagem RE7/999 | 4 |
| Retorno da desmontagem DE7/499 | 5 |

Dos 766 PR0, 158 são vinculados a OPs do 05 e 608 a OPs do 10. Entrada do
acabado não equivale a venda nem a entrega ao cliente. O histórico completo
também contém RE0, DE6 e RE6; os tipos não classificados continuam visíveis.

Transferências recentes pareadas por filial/documento/data/sequência/estorno:

| Origem | Destino | Pares |
|---|---|---:|
| 01 | 10 | 247 |
| 03 | 10 | 2 |
| 05 | 10 | 181 |
| 06 | 10 | 7 |
| 07 | 10 | 6 |
| 08 | 10 | 2 |
| 70 | 10 | 11 |
| 10 | 01 | 2 |
| 10 | 05 | 5 |
| 10 | 06 | 22 |
| 10 | 07 | 199 |
| 10 | 10 | 8 |

Há transferência dentro do mesmo armazém; não descartar pelo local ser igual.
O pareamento mantém produtos distintos e não atribui automaticamente uma saída
de retorno a uma remessa anterior de outra data.

## Notas e saldo

Entradas recentes incluem conserto TES 079 (estoque N), devolução de venda
102/440 (S), retorno de mostruário 098 (S) e compra para consumo 028 (N).
Saídas incluem venda, exportação, remessa, garantia, bonificação e serviços.

Exemplos que exigem distinção: TES 609, faturamento antecipado, está com estoque
N; TES 610, remessa de entrega futura, S; TES 572, retorno de conserto, N;
TES 800, serviços, N. O aplicativo informa o cadastro **atual** da TES, sem
afirmar que ele era igual na data histórica. SD1 é filtrada pela digitação;
SD2, pela emissão.

Histórico completo consultado via API: 93.412 registros (SD3+SD1+SD2),
2.183 registros de estoque (144 com saldo não zero), 6.757 OPs
(40 abertas/6.717 encerradas) e 6.076 contagens de inventário. Há 2.431 itens
SD1 e 29.619 SD2 no total. Última data global retornada pelo DEV: 18/09/2026.

## Quem aparece

SYS_USR possui `expedicao`, nome “Bruna e Tamara”; também possui `bruna`, nome
Bruna Guerra, e `rafaela`, nome Rafaela Aparecida Alves. Isso não identifica
qual pessoa usou uma conta compartilhada em cada movimento.

No recorte, o login `expedicao` aparece em 376 PR0, 1.758 RE1 e 99 RE4 do 10.
Outros usuários também registram movimentos, conforme o JSON. SD3 comprova os
lançamentos, não quais menus/permissões o usuário possui nem que cada consumo
tenha sido digitado manualmente.

## Customizações encontradas

Raiz autêntica: `C:/Users/Leonardo Morais/Desktop/vetti/VettiFlow/protheus_advpl/vettip12`.

| Fonte | Regra observada no código |
|---|---|
| `pcp/atualizacao/RPCPA001.prw` | Apontamento por MATA250, com OP/quantidade/local e tratamento separado de perdas |
| `estoque/atualizacao/RESTA007.prw`, `RESTA008.prw`, `RESTA011.prw` | Transferências personalizadas chamando MATA261 |
| `faturamento/ponto de entrada/SF2460I.prw` | Na geração de nota, copia de SA4 o nome/tipo de rastreio da transportadora para campos customizados de SF2; também grava nome e pedido de referência |
| `faturamento/Cadastros/RFATC002.prw` | “Rastreio de Pedidos Faturados”; filtra F2_RASTREI=S, usa tipos PJ/NF/CR e permite gravar F2_CODRAST/F2_LOGRAST; chama envio de email |
| `faturamento/ponto de entrada/M460FIM.PRW` | Após gerar nota, consulta D2_PEDIDO/SC5 e atualiza dados de pagamento dos títulos SE1 |
| `faturamento/relatorio/RFATR004.prw`, `RFATR005.prw` | Fontes de relatórios com título Packing List; não executados ou reproduzidos nesta entrega |

A existência dos fontes não prova sua execução em cada documento. O app não
chama essas rotinas, não envia email e não lê credenciais de email.

## Rastreio: o que está preenchido

Há 485 cabeçalhos SF2 no recorte com pelo menos um item SD2 do 10: 482 têm
transportadora, 377 têm rastreio habilitado (259 CR e 118 NF), mas **nenhum tem
código ou log de rastreio preenchido**. No histórico completo: 8.934 cabeçalhos,
apenas quatro com código e log. Não inferir coleta/entrega a partir de nota,
transportadora cadastrada ou rastreio habilitado.

Não foram encontradas duplicidades de cabeçalho na identidade fiscal completa
consultada. Mesmo assim, o endpoint de detalhe detecta ambiguidade e não escolhe
um cabeçalho arbitrário. Volumes vêm de SF2 e são da nota inteira; pedido vem
do item SD2 selecionado, pois uma nota pode reunir mais de um pedido/local.

## Entrega

Consulta real do 10, com histórico completo paginado, filtros por mês, notas,
saldo, OPs, inventário e detalhes de transporte. A conferência local foi
preservada em rota identificada, sem pedido fictício ou origem fixa. Conciliação
operacional, pedidos não faturados, gravação no ERP e PDF mensal ficam pendentes.
