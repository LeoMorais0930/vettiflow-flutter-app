# Auditoria de movimentos Protheus × VettiFlow — 24/09/2026

Consulta real ao banco **HMLp12**, servidor WIN-L1NA6CE7LB4, empresa 010, filial 04. Período inclusivo: **24/06/2026 a 24/09/2026**. Somente SELECT; nenhuma escrita no Protheus. Captura: 2026-09-24T08:07:10.070628.

As quatro tabelas históricas consultadas terminam em **18/09/2026**. Não há registros de 19–24/09 nelas; esta auditoria não confirma a operação atual do banco de produção nem a data de restauração do dev. Os três meses são uma janela móvel, não junho/julho/agosto completos.

## Escopo e contagem

Varredura agregada de todas as linhas não excluídas no período, sem TOP/limite nas contagens. SD3 por emissão; SD1 por data de digitação/entrada; SD2 e SC2 por emissão. SD4 mostra o estado atual dos empenhos das OPs emitidas na janela, não um log histórico de reservas. Amostras SD3: até duas por combinação de local/CF/TM/estorno. Transferências: todas as linhas da janela. D3_ESTORNO foi separado na consulta; todos os valores retornados estão vazios. Não houve isolamento de snapshot entre consultas.

| Fonte | Registros no período | Significado |
| --- | --- | --- |
| SD3 | 15233 | Linhas de movimentos internos |
| SD1 | 1294 | Itens de notas de entrada, inclusive sem efeito em estoque |
| SD2 | 1584 | Itens de notas de saída, inclusive sem efeito em estoque |
| SC2 | 685 | Registros de OP emitidos na janela |

Contagens são linhas/itens, não unidades produzidas, notas únicas ou operações únicas. Um apontamento pode gerar muitas linhas de consumo. Quantidades de produtos/unidades diferentes não foram somadas. O indicador de estoque abaixo é o cadastro TES atual (SF4.F4_ESTOQUE), não uma reconciliação histórica de saldo.

## Visão por setor

| Setor | Locais | SD3 | Itens entrada | Itens saída | OPs emitidas |
| --- | --- | --- | --- | --- | --- |
| Almoxarifado | 01 | 1879 | 955 | 3 | 3 |
| SMD | 03 | 2317 | 221 | 0 | 49 |
| Produção MEC/PTH | 05, 04 | 3277 | 7 | 0 | 256 |
| Suporte | 06, 07 | 854 | 5 | 13 | 3 |
| Expedição | 10 | 4406 | 100 | 1564 | 278 |

Outros locais também foram incluídos na varredura para preservar o fluxo com terceiros e estoques especiais; por isso a soma dos cinco setores não representa o total da base.

### Produção (05 MEC e 04 PTH)

No 05: 139 entradas PR0, 1.773 consumos RE1, 763 entradas e 587 saídas por transferência, 1 entrada de ajuste, 4 saídas de ajuste, 1 saída e 9 retornos de componentes por desmontagem. Foram emitidas 254 OPs no 05. No 04: 2 OPs com 14 linhas de empenho, nenhum movimento SD3 e 5 itens de entrada sem atualização de estoque pela TES atual. A falta de SD3 no 04 não significa ausência de planejamento.

122 OPs do local 05 tiveram 158 entradas de acabado no 10. Outras 4 OPs do 05 entraram no 07. Portanto, local da OP e destino do acabado precisam continuar separados. Cinco entradas no 05 vieram de OPs do 70.

### Almoxarifado (01)

1.823 saídas e 37 entradas por transferência; 5 entradas de ajuste; 4 retornos de desmontagem. Também existem 2 entradas de produção e 8 consumos de componentes: este local não é exclusivamente armazenamento. Dos 955 itens de notas de entrada, 242 usam TES com estoque=S; os demais incluem fretes, serviços, consumo e outros registros sem atualização de estoque pelo cadastro atual. Há 3 itens de saída, todos com estoque=S.

### SMD (03)

66 entradas de produção em 44 OPs distintas e 2.081 consumos; 19 entradas e 150 saídas por transferência; 1 entrada de ajuste. Foram emitidas 49 OPs na janela. Das 221 linhas de notas de entrada, 185 têm estoque=S, incluindo compras e importações. As transferências saem para 05, 70, 07, 72, 10 e 01. OPs movimentadas e OPs emitidas são recortes diferentes.

### Suporte (06 e 07)

No 06: 302 entradas e 37 saídas por transferência, mais 8 saídas de ajuste. No 07: 488 entradas e 12 saídas por transferência, mais 7 entradas de acabado oriundas de OPs do 05 ou 10. Não houve RE1 nos locais 06/07 na janela. Há notas de retorno de mostruário, conserto e garantia no 06; no 07, saídas de garantia, serviços e bonificações. O cadastro TES distingue registros com e sem atualização de estoque. Essas evidências não revelam por si só o diagnóstico, a ordem de serviço ou o motivo de cada reparo.

### Expedição (10)

766 entradas de produção, 2.924 consumos RE1, 464 entradas e 236 saídas por transferência, 7 entradas de ajuste, 4 saídas e 5 retornos de desmontagem. Foram emitidas 278 OPs no local. Logo, expedição também participa de OPs. Há 1.564 itens de saída fiscal, 1.462 com estoque=S, abrangendo vendas, exportação, bonificação, mostruário, conserto, garantia e entrega futura. Dos 100 itens de entrada, 35 têm estoque=S; aparecem devolução de venda, retorno de mostruário e recebimento para conserto.

## Todos os tipos internos observados

| CF | TM | Interpretação | Linhas |
| --- | --- | --- | --- |
| DE0 | 400 | Entrada para ajuste (SF5: TM400) | 14 |
| DE4 | 499 | Entrada por transferência | 2952 |
| DE7 | 499 | Retorno de componentes da desmontagem | 18 |
| PR0 | 001 | Entrada de produção | 1099 |
| RE0 | 501 | Saída para ajuste (SF5: TM501) | 12 |
| RE1 | 999 | Consumo de componentes de OP | 8181 |
| RE4 | 999 | Saída por transferência | 2952 |
| RE7 | 999 | Saída de produto para desmontagem | 5 |

Não foram encontrados ER0/999 nem DE1/499 neste período do dev. Isso não invalida ocorrências em outros períodos ou bases. Os códigos 499/999 não constam como registros na SF5 consultada; as interpretações vêm dos pares observados e do mapeamento existente no projeto. Não se atribuiu uma rotina oficial específica a partir apenas desses códigos.

## Transferências e mudança de produto — lacuna confirmada no VettiFlow

As 5.904 linhas RE4/DE4 formam **2.952 pares** por filial + data + documento + D3_NUMSEQ: exatamente uma saída e uma entrada por chave nesta amostra. Em **11 pares o produto muda**, dez deles dentro do mesmo local. Um também muda a unidade PC → UN, sem diferença no valor numérico da quantidade; equivalência física não foi validada. A motivação da troca exige confirmação operacional.

Reexecutando apenas a função atual `_pair_transfer_rows` sobre os dados coletados, o app devolve 2.941 grupos pareados, 11 sem entrada e 11 sem saída. A função agrupa por documento/produto/quantidade/data, desconsiderando a sequência para o pareamento. Assim, essas 11 trocas reais viram 22 alertas de falta de contraparte. Nenhuma correção de código funcional foi feita nesta auditoria.

| Data | Documento | Sequência | Locais | Produto saída → entrada | Quantidade saída/entrada | UM saída/entrada |
| --- | --- | --- | --- | --- | --- | --- |
| 20260624 | Q000003XX | 410005 | 05 → 05 | 102-525 → 102-571 | 500.0/500.0 | PC/PC |
| 20260625 | Q000003Y3 | 410129 | 10 → 10 | 730-0888 → 575-0888 | 9.0/9.0 | PC/PC |
| 20260708 | Q00000406 | 411635 | 01 → 01 | 103-072 → 103-071 | 3000.0/3000.0 | PC/PC |
| 20260714 | Q0000040H | 411885 | 10 → 10 | 575-0802 → 575-0923 | 80.0/80.0 | PC/UN |
| 20260715 | Q0000040P | 411913 | 10 → 10 | 730-0773 → 630-0773 | 1.0/1.0 | PC/PC |
| 20260716 | Q00000411 | 412078 | 10 → 10 | 730-0773 → 740-0773 | 50.0/50.0 | PC/PC |
| 20260723 | Q00000438 | 413099 | 01 → 10 | 106-010 → 106-014 | 50.0/50.0 | PC/PC |
| 20260724 | Q0000043G | 413225 | 10 → 10 | 730-0885 → 740-0885 | 80.0/80.0 | PC/PC |
| 20260730 | Q0000044K | 413788 | 10 → 10 | 730-0879 → 740-0879 | 80.0/80.0 | PC/PC |
| 20260730 | Q00000452 | 413891 | 10 → 10 | 730-0886 → 740-0886 | 100.0/100.0 | PC/PC |
| 20260827 | Q000004A1 | 416626 | 10 → 10 | 203-055 → 203-056 | 43.0/43.0 | PC/PC |

### Todas as rotas observadas, incluindo troca de produto

| Origem | Destino | Pares |
| --- | --- | --- |
| 01 | 70 | 687 |
| 01 | 05 | 593 |
| 05 | 06 | 278 |
| 01 | 10 | 247 |
| 10 | 07 | 199 |
| 05 | 10 | 181 |
| 01 | 07 | 143 |
| 01 | 72 | 138 |
| 05 | 07 | 107 |
| 70 | 05 | 62 |
| 03 | 05 | 55 |
| 03 | 70 | 49 |
| 03 | 07 | 39 |
| 06 | 05 | 30 |
| 10 | 06 | 22 |
| 70 | 01 | 17 |
| 05 | 01 | 14 |
| 01 | 03 | 14 |
| 70 | 10 | 11 |
| 10 | 10 | 8 |
| 08 | 05 | 8 |
| 06 | 10 | 7 |
| 07 | 10 | 6 |
| 05 | 03 | 5 |
| 72 | 05 | 5 |
| 10 | 05 | 5 |
| 03 | 72 | 4 |
| 07 | 05 | 3 |
| 08 | 10 | 2 |
| 07 | 06 | 2 |
| 10 | 01 | 2 |
| 03 | 10 | 2 |
| 05 | 05 | 1 |
| 05 | 70 | 1 |
| 12 | 05 | 1 |
| 01 | 01 | 1 |
| 07 | 01 | 1 |
| 03 | 01 | 1 |
| 08 | 01 | 1 |

## Cobertura atual do VettiFlow e próximos ajustes identificados

1. A API já contempla os oito CF/TM internos encontrados, além de ER0/DE1, ausentes neste recorte. Reconhecer o código não significa modelar toda a rotina operacional.
2. Corrigir futuramente a identidade dos pares de transferência para contemplar mudança de produto e unidade, preservando os dois lados e a sequência.
3. Incluir leitura de SD1/SD2 com classificação por TES/CFOP para compras, vendas, devoluções, remessas, garantia, conserto e terceiros. O backend atual não consulta SD1/SD2/SF4.
4. Preservar os destinos reais de produção 05→10, 05→07, 10→07 e 70→05; não forçar o acabado para o local da OP.
5. Separar estoque próprio, movimentos/documentos de terceiros e documentos sem atualização de estoque; o local sozinho não define o processo. Para suportar assistência completa, ainda faltam vínculos com ordens de serviço e diagnósticos.

## Detalhamento completo por local e tipo interno

| Local | CF | TM | Estorno | Linhas | Produtos distintos | OPs distintas | Primeira data | Última data |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 01 | DE0 | 400 |  | 5 | 5 | 0 | 20260629 | 20260820 |
| 01 | DE4 | 499 |  | 37 | 27 | 0 | 20260625 | 20260917 |
| 01 | DE7 | 499 |  | 4 | 4 | 0 | 20260903 | 20260914 |
| 01 | PR0 | 001 |  | 2 | 2 | 2 | 20260720 | 20260727 |
| 01 | RE1 | 999 |  | 8 | 8 | 2 | 20260720 | 20260727 |
| 01 | RE4 | 999 |  | 1823 | 239 | 0 | 20260624 | 20260918 |
| 03 | DE0 | 400 |  | 1 | 1 | 0 | 20260810 | 20260810 |
| 03 | DE4 | 499 |  | 19 | 16 | 0 | 20260626 | 20260911 |
| 03 | PR0 | 001 |  | 66 | 25 | 44 | 20260624 | 20260918 |
| 03 | RE1 | 999 |  | 2081 | 199 | 44 | 20260624 | 20260918 |
| 03 | RE4 | 999 |  | 150 | 48 | 0 | 20260624 | 20260916 |
| 05 | DE0 | 400 |  | 1 | 1 | 0 | 20260630 | 20260630 |
| 05 | DE4 | 499 |  | 763 | 169 | 0 | 20260624 | 20260918 |
| 05 | DE7 | 499 |  | 9 | 8 | 0 | 20260629 | 20260914 |
| 05 | PR0 | 001 |  | 139 | 45 | 134 | 20260624 | 20260918 |
| 05 | RE0 | 501 |  | 4 | 4 | 0 | 20260629 | 20260803 |
| 05 | RE1 | 999 |  | 1773 | 178 | 251 | 20260624 | 20260918 |
| 05 | RE4 | 999 |  | 587 | 88 | 0 | 20260624 | 20260917 |
| 05 | RE7 | 999 |  | 1 | 1 | 0 | 20260914 | 20260914 |
| 06 | DE4 | 499 |  | 302 | 28 | 0 | 20260626 | 20260917 |
| 06 | RE0 | 501 |  | 8 | 8 | 0 | 20260701 | 20260914 |
| 06 | RE4 | 999 |  | 37 | 19 | 0 | 20260626 | 20260914 |
| 07 | DE4 | 499 |  | 488 | 146 | 0 | 20260625 | 20260918 |
| 07 | PR0 | 001 |  | 7 | 4 | 7 | 20260624 | 20260911 |
| 07 | RE4 | 999 |  | 12 | 11 | 0 | 20260625 | 20260914 |
| 08 | RE4 | 999 |  | 11 | 7 | 0 | 20260624 | 20260908 |
| 10 | DE0 | 400 |  | 7 | 7 | 0 | 20260708 | 20260812 |
| 10 | DE4 | 499 |  | 464 | 93 | 0 | 20260624 | 20260918 |
| 10 | DE7 | 499 |  | 5 | 4 | 0 | 20260914 | 20260914 |
| 10 | PR0 | 001 |  | 766 | 107 | 405 | 20260624 | 20260918 |
| 10 | RE1 | 999 |  | 2924 | 108 | 286 | 20260624 | 20260918 |
| 10 | RE4 | 999 |  | 236 | 49 | 0 | 20260625 | 20260917 |
| 10 | RE7 | 999 |  | 4 | 4 | 0 | 20260629 | 20260914 |
| 12 | RE4 | 999 |  | 1 | 1 | 0 | 20260702 | 20260702 |
| 70 | DE4 | 499 |  | 737 | 105 | 0 | 20260625 | 20260914 |
| 70 | PR0 | 001 |  | 115 | 22 | 102 | 20260625 | 20260914 |
| 70 | RE1 | 999 |  | 1249 | 109 | 105 | 20260625 | 20260914 |
| 70 | RE4 | 999 |  | 90 | 21 | 0 | 20260625 | 20260914 |
| 72 | DE4 | 499 |  | 142 | 37 | 0 | 20260714 | 20260914 |
| 72 | PR0 | 001 |  | 4 | 2 | 4 | 20260714 | 20260914 |
| 72 | RE1 | 999 |  | 146 | 38 | 4 | 20260714 | 20260914 |
| 72 | RE4 | 999 |  | 5 | 2 | 0 | 20260702 | 20260916 |

## Detalhamento completo de notas por tipo/TES/CFOP

Descrições abaixo são literais do cadastro TES do próprio dev, não validação tributária. Estoque=S/N reflete o cadastro atual. Incluídos também registros administrativos para tornar explícito o que não deve ser contado automaticamente como movimento físico.

### Entradas (SD1)

| Local | Tipo | CFOP | TES | Descrição cadastrada | Estoque | Itens |
| --- | --- | --- | --- | --- | --- | --- |
| 01 | C | 1353 | 107 | FRETE MP SIMPLES NACIONAL | N | 19 |
| 01 | C | 1353 | 430 | TRANSPORTE RODOVIARIO | N | 32 |
| 01 | C | 1353 | 433 | FRETE MP SIMPLES NACIONAL | N | 9 |
| 01 | C | 2353 | 430 | TRANSPORTE RODOVIARIO | N | 4 |
| 01 | C | 2353 | 434 | FRETE REMESSAS C/ ICMS S/ PIS/COFINS | N | 2 |
| 01 | D | 1916 | 156 | RETORNO REMESSA CONSERTO | S | 1 |
| 01 | N | 1101 | 402 | ENTRADA PRODUCAO | S | 91 |
| 01 | N | 1101 | 403 | COMPRA PRODUCAO | N | 9 |
| 01 | N | 1101 | 404 | ENTRADA PRODUCAO | S | 63 |
| 01 | N | 1101 | 406 | ENTRADA PRODUCAO | S | 22 |
| 01 | N | 1102 | 028 | COMPRA CONSUMO | N | 1 |
| 01 | N | 1124 | 420 | INDUSTRIALIZACAO EFETUADA POR OUTRA EMPRESA | S | 38 |
| 01 | N | 1252 | 460 | COMPRA DE ENERGIA ELETRICA POR ESTAB INDUSTRIAL | N | 3 |
| 01 | N | 1302 | 208 | AQUISICAO DE PRESTACAO DE SERVICOS | N | 2 |
| 01 | N | 1353 | 430 | TRANSPORTE RODOVIARIO | N | 34 |
| 01 | N | 1353 | 434 | FRETE REMESSAS C/ ICMS S/ PIS/COFINS | N | 3 |
| 01 | N | 1401 | 407 | ENTRADA PRODUCAO | S | 3 |
| 01 | N | 1407 | 029 | COMPRA CONSUMO | N | 16 |
| 01 | N | 1551 | 021 | COMPRA ATIVO IMOBILI | N | 2 |
| 01 | N | 1556 | 028 | COMPRA CONSUMO | N | 155 |
| 01 | N | 1556 | 030 | COMPRA CONSUMO | N | 3 |
| 01 | N | 1556 | 031 | COMPRA CONSUMO | N | 4 |
| 01 | N | 1653 | 040 | COMPRA COMBUSTIVEL | N | 13 |
| 01 | N | 1911 | 095 | REMESSA AMOSTRA | N | 1 |
| 01 | N | 1933 | 201 | AQUISICAO DE PRESTACAO DE SERVICOS | N | 144 |
| 01 | N | 1933 | 202 | AQUISICAO DE PRESTACAO DE SERVICOS | N | 3 |
| 01 | N | 1933 | 203 | AQUISICAO DE PRESTACAO DE SERVICOS | N | 5 |
| 01 | N | 1933 | 206 | AQUISICAO DE PRESTACAO DE SERVICOS | N | 39 |
| 01 | N | 2101 | 401 | ENTRADA PRODUCAO | S | 1 |
| 01 | N | 2101 | 402 | ENTRADA PRODUCAO | S | 7 |
| 01 | N | 2101 | 404 | ENTRADA PRODUCAO | S | 3 |
| 01 | N | 2353 | 430 | TRANSPORTE RODOVIARIO | N | 64 |
| 01 | N | 2353 | 434 | FRETE REMESSAS C/ ICMS S/ PIS/COFINS | N | 26 |
| 01 | N | 2551 | 038 | AQUISICAO ATIVO | N | 2 |
| 01 | N | 2556 | 030 | COMPRA CONSUMO | N | 13 |
| 01 | N | 2556 | 031 | COMPRA CONSUMO | N | 4 |
| 01 | N | 2933 | 201 | AQUISICAO DE PRESTACAO DE SERVICOS | N | 79 |
| 01 | N | 2933 | 203 | AQUISICAO DE PRESTACAO DE SERVICOS | N | 11 |
| 01 | N | 3101 | 304 | IMPORTACAO | S | 13 |
| 01 | N | 3101 | 313 | IMPORTACAO VIA COURIER | N | 11 |
| 02 | N | 1556 | 028 | COMPRA CONSUMO | N | 1 |
| 03 | C | 1353 | 107 | FRETE MP SIMPLES NACIONAL | N | 7 |
| 03 | C | 1353 | 430 | TRANSPORTE RODOVIARIO | N | 3 |
| 03 | C | 1353 | 433 | FRETE MP SIMPLES NACIONAL | N | 21 |
| 03 | C | 2353 | 430 | TRANSPORTE RODOVIARIO | N | 3 |
| 03 | N | 1101 | 402 | ENTRADA PRODUCAO | S | 142 |
| 03 | N | 1101 | 404 | ENTRADA PRODUCAO | S | 10 |
| 03 | N | 1401 | 407 | ENTRADA PRODUCAO | S | 4 |
| 03 | N | 2101 | 404 | ENTRADA PRODUCAO | S | 3 |
| 03 | N | 3101 | 304 | IMPORTACAO | S | 17 |
| 03 | N | 3101 | 313 | IMPORTACAO VIA COURIER | N | 2 |
| 03 | N | 3101 | 314 | IMPORTACAO VIA COURIER | S | 9 |
| 04 | C | 1353 | 107 | FRETE MP SIMPLES NACIONAL | N | 1 |
| 04 | N | 1124 | 421 | INDUSTRIALIZACAO EFETUADA POR OUTRA EMPRESA | N | 4 |
| 05 | N | 3101 | 304 | IMPORTACAO | S | 2 |
| 06 | B | 1913 | 098 | RETORNO REMESSA DE MOSTRUARIO | S | 1 |
| 06 | B | 2913 | 098 | RETORNO REMESSA DE MOSTRUARIO | S | 1 |
| 06 | B | 2915 | 079 | ENTRADA DE MERCADORIA OU BEM RECEBIDO PARA CONSERTO OU REPARO | N | 1 |
| 06 | D | 2949 | 109 | RETORNO REMESSA EM GARANTIA | S | 2 |
| 10 | B | 1913 | 098 | RETORNO REMESSA DE MOSTRUARIO | S | 11 |
| 10 | B | 1915 | 079 | ENTRADA DE MERCADORIA OU BEM RECEBIDO PARA CONSERTO OU REPARO | N | 17 |
| 10 | B | 2913 | 098 | RETORNO REMESSA DE MOSTRUARIO | S | 10 |
| 10 | B | 2915 | 079 | ENTRADA DE MERCADORIA OU BEM RECEBIDO PARA CONSERTO OU REPARO | N | 47 |
| 10 | D | 2201 | 102 | DEVOLUCAO VENDA  PROD | S | 2 |
| 10 | D | 2201 | 440 | DEVOLUCAO VENDA  PROD | S | 12 |
| 10 | N | 1556 | 028 | COMPRA CONSUMO | N | 1 |
| 72 | N | 1902 | 090 | RETORNO DE INDUSTRIALIZACAO | S | 5 |

### Saídas (SD2)

| Local | Tipo | CFOP | TES | Descrição cadastrada | Estoque | Itens |
| --- | --- | --- | --- | --- | --- | --- |
| 01 | D | 5201 | 602 | DEVOLUCAO COMPRAS | S | 2 |
| 01 | N | 5915 | 597 | REMESSA CONSERTO | S | 1 |
| 07 | N | 5933 | 800 | PRESTACAO DE SERVICOS | N | 4 |
| 07 | N | 5949 | 540 | REMESSA EM GARANTIA | S | 1 |
| 07 | N | 6910 | 701 | REMESSA EM BONIFICACAO, DOACAO OU BRINDE | N | 2 |
| 07 | N | 6933 | 800 | PRESTACAO DE SERVICOS | N | 2 |
| 07 | N | 6949 | 540 | REMESSA EM GARANTIA | S | 4 |
| 10 | I | 6401 | 689 | COMPLEMENTO ICMS ST | N | 4 |
| 10 | N | 5101 | 502 | VENDA DE PRODUCAO DO ESTABELECIMENTO | S | 5 |
| 10 | N | 5101 | 536 | VENDA DE PRODUCAO DO ESTABELECIMENTO | S | 152 |
| 10 | N | 5101 | 582 | VENDA PRODUCAO | S | 271 |
| 10 | N | 5101 | 800 | PRESTACAO DE SERVICOS | N | 2 |
| 10 | N | 5102 | 589 | VENDA DE MERCADORIA ADQUIRIDA DE TERCEIROS | S | 13 |
| 10 | N | 5102 | 620 | VENDA DE MERCADORIA ADQUIRIDA DE TERCEIROS | S | 3 |
| 10 | N | 5102 | 625 | VENDA DE MERCADORIA ADQUIRIDA DE TERCEIROS | S | 3 |
| 10 | N | 5116 | 587 | REMESSA ENTREGA FUTURA CONS. FINAL | S | 1 |
| 10 | N | 5401 | 705 | VENDA DE PRODUCAO DO ESTABELECIMENTO OPERACAO COM SUBSTITUICAO TRIBUTARIA | S | 1 |
| 10 | N | 5910 | 549 | REMESSA EM BONIFICACAO, DOACAO OU BRINDE | S | 5 |
| 10 | N | 5910 | 550 | REMESSA EM BONIFICACAO, DOACAO OU BRINDE | S | 12 |
| 10 | N | 5912 | 584 | REMESSA DE MOSTRUARIO | S | 16 |
| 10 | N | 5916 | 572 | RETORNO DE MERCADORIA/BEM RECEBIDO PARA REPARO OU CONSERTO | N | 4 |
| 10 | N | 5922 | 609 | FATURAMENTO ANTECIPADO - VENDA PARA ENTREGA FUTURA | N | 1 |
| 10 | N | 5933 | 800 | PRESTACAO DE SERVICOS | N | 27 |
| 10 | N | 6101 | 502 | VENDA DE PRODUCAO DO ESTABELECIMENTO | S | 12 |
| 10 | N | 6101 | 536 | VENDA DE PRODUCAO DO ESTABELECIMENTO | S | 491 |
| 10 | N | 6101 | 582 | VENDA PRODUCAO | S | 3 |
| 10 | N | 6102 | 589 | VENDA DE MERCADORIA ADQUIRIDA DE TERCEIROS | S | 1 |
| 10 | N | 6102 | 625 | VENDA DE MERCADORIA ADQUIRIDA DE TERCEIROS | S | 4 |
| 10 | N | 6107 | 536 | VENDA DE PRODUCAO DO ESTABELECIMENTO | S | 19 |
| 10 | N | 6107 | 569 | VENDA CONSUMIDOR FINAL | S | 167 |
| 10 | N | 6108 | 625 | VENDA DE MERCADORIA ADQUIRIDA DE TERCEIROS | S | 1 |
| 10 | N | 6109 | 580 | VENDA MERCADORIA DESTINADA ZONA FRANCA DE MANAUS | S | 31 |
| 10 | N | 6116 | 610 | REMESSA - ENTREGA FUTURA | S | 3 |
| 10 | N | 6401 | 599 | VENDA DIFAL CONSUMIDOR FINAL | S | 21 |
| 10 | N | 6401 | 705 | VENDA DE PRODUCAO DO ESTABELECIMENTO OPERACAO COM SUBSTITUICAO TRIBUTARIA | S | 6 |
| 10 | N | 6401 | 707 | VENDA DE PRODUCAO DO ESTABELECIMENTO OPERACAO COM SUBSTITUICAO TRIBUTARIA | S | 142 |
| 10 | N | 6401 | 711 | VENDA DE PRODUCAO DO ESTABELECIMENTO OPERACAO COM SUBSTITUICAO TRIBUTARIA | S | 1 |
| 10 | N | 6403 | 512 | VENDA INTER SUBS TRI | S | 2 |
| 10 | N | 6910 | 549 | REMESSA EM BONIFICACAO, DOACAO OU BRINDE | S | 4 |
| 10 | N | 6910 | 550 | REMESSA EM BONIFICACAO, DOACAO OU BRINDE | S | 31 |
| 10 | N | 6910 | 701 | REMESSA EM BONIFICACAO, DOACAO OU BRINDE | N | 3 |
| 10 | N | 6912 | 584 | REMESSA DE MOSTRUARIO | S | 21 |
| 10 | N | 6915 | 597 | REMESSA CONSERTO | S | 4 |
| 10 | N | 6916 | 572 | RETORNO DE MERCADORIA/BEM RECEBIDO PARA REPARO OU CONSERTO | N | 40 |
| 10 | N | 6933 | 800 | PRESTACAO DE SERVICOS | N | 21 |
| 10 | N | 6949 | 540 | REMESSA EM GARANTIA | S | 1 |
| 10 | N | 7101 | 533 | EXPORTACAO | S | 15 |
| 72 | B | 5901 | 658 | REMESSA PARA INDUSTRIALIZACAO | S | 4 |

## Roteamento real de produção

| Local OP | Entrada acabado | Linhas PR0 | OPs distintas |
| --- | --- | --- | --- |
| 01 | 01 | 2 | 2 |
| 03 | 03 | 66 | 44 |
| 05 | 05 | 134 | 129 |
| 05 | 07 | 4 | 4 |
| 05 | 10 | 158 | 122 |
| 10 | 07 | 3 | 3 |
| 10 | 10 | 608 | 283 |
| 70 | 05 | 5 | 5 |
| 70 | 70 | 115 | 102 |
| 72 | 72 | 4 | 4 |

## Empenhos atuais das OPs emitidas na janela

| Local OP | Local empenho | Linhas SD4 | OPs distintas |
| --- | --- | --- | --- |
| 01 | 01 | 13 | 3 |
| 03 | 03 | 1397 | 49 |
| 04 | 04 | 14 | 2 |
| 05 | 05 | 1465 | 253 |
| 06 | 06 | 16 | 2 |
| 07 | 07 | 5 | 1 |
| 10 | 10 | 1333 | 278 |
| 70 | 70 | 850 | 92 |
| 72 | 72 | 146 | 4 |

## Evidência e reprodução

Arquivos locais: [evidencias.json](https://github.com/LeoMorais0930/vettiflow-flutter-app/blob/8329fe3a23a2b12d98d63ab71ad405469b124a0b/docs/auditorias/2026-09-24/evidencias.json), [consultas.json](https://github.com/LeoMorais0930/vettiflow-flutter-app/blob/8329fe3a23a2b12d98d63ab71ad405469b124a0b/docs/auditorias/2026-09-24/consultas.json), [analise.json](https://github.com/LeoMorais0930/vettiflow-flutter-app/blob/8329fe3a23a2b12d98d63ab71ad405469b124a0b/docs/auditorias/2026-09-24/analise.json). Scripts: `scripts/audit_dev_movements_20260924.py` consulta exclusivamente HMLp12 e salva evidências; `scripts/report_dev_movements_20260924.py` gera este relatório a partir delas. Nenhum segredo foi exportado. O histórico mensal e as amostras por tipo estão no JSON. A validação local confere totais por fonte e a cardinalidade dos 2.952 pares.
