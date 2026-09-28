# Roadmap Profundo Protheus: OP, Apontamento, Retorno, Desmontagem e Setores

> Documento histórico preservado para pesquisa e rastreabilidade. O funcionamento atual está no [índice por setor](README.md). Planos de escrita abaixo não autorizam alterações no Protheus.

Data da pesquisa: 2026-09-09  
Base oficial analisada: `VettiP12`, filial 04, somente leitura  
Base de teste analisada: `HMLp12`, filial 04, somente leitura  
Escopo: confirmar, com fontes externas e historico real do Protheus, como o VettiFlow deve tratar criacao de OP, empenho, apontamento, baixa, retorno/estorno, transferencia, desmontagem, perdas/ganhos e setores.

## Resumo executivo

A conclusao principal e firme: o VettiFlow nao deve gravar direto nas tabelas nativas do Protheus. Mesmo quando o historico deixa claro quais registros aparecem em `SC2`, `SD4` e `SD3`, a escrita precisa passar por rotina oficial Protheus, idealmente via `MSExecAuto`/rotina ADVPL exposta por API REST, porque o Protheus aplica validacoes, gatilhos, travas, numeracao, saldo, custo e regras internas que nao aparecem completamente em um `INSERT` SQL direto.^1 ^2 ^3

Na pratica, o historico oficial da Vetti confirma estes blocos:

| Processo | Tabelas/movimentos reais | Conclusao para VettiFlow |
|---|---|---|
| Criar OP | `SC2` + `SD4`; sem `SD3` | Criacao de OP e reserva/empenho, nao movimento fisico |
| Empenhar componente | `SD4.D4_LOCAL`, `D4_QTDEORI`, `D4_QUANT` | Representar como material comprometido no local da OP |
| Apontar producao simples | `SD3` com `PR0/001` e `RE1/999` | Entrada do acabado + consumo dos componentes |
| Entrada do acabado | `PR0/001`, `D3_OP` preenchido | Pode entrar em local diferente do `C2_LOCAL`, especialmente `05 -> 10` |
| Consumo de componente | `RE1/999`, `D3_OP` preenchido | Normalmente acompanha local operacional da OP |
| Estorno de apontamento | `PR0`/`RE1` marcados com estorno + reversoes `ER0`/`DE1` | Nunca apagar movimento; registrar reversao rastreavel |
| Transferencia entre setores | par `RE4/999` + `DE4/499`, `D3_OP` vazio | Separar de apontamento de OP |
| Desmontagem | `RE7/999` do item origem + `DE7/499` dos itens retornados | Fluxo proprio, sem OP, com documento/numseq unico |
| Perda/ganho | campos `D3_PERDA` e `D3_QTGANHO` no `PR0/001` | Modelar quantidade boa, perda e ganho separadamente |

O maior ajuste conceitual para o VettiFlow e separar tres locais que hoje tendem a ser tratados como uma coisa so:

1. `C2_LOCAL`: local operacional da OP.
2. `D4_LOCAL` / `RE1.D3_LOCAL`: local onde o componente fica empenhado/consumido.
3. `PR0.D3_LOCAL`: local onde o produto acabado entra.

Esse terceiro local e decisivo. O caso real `05 -> 10` aparece muitas vezes na producao oficial: OP da producao mecanica (`05`) consome no `05`, mas da entrada do acabado na expedicao (`10`).

## Fontes externas consultadas

As fontes externas foram usadas para confirmar o desenho padrao do Protheus, e o banco oficial foi usado para confirmar como a Vetti de fato opera.

| Fonte | Uso na pesquisa |
|---|---|
| SempreJu - `SC2` | Confirmar chave e campos da OP, incluindo `C2_LOCAL`, `C2_QUJE`, `C2_DATRF` e status.^4 |
| SempreJu - `SD4` | Confirmar que `D4_LOCAL`, `D4_OP`, `D4_QTDEORI` e `D4_QUANT` representam empenhos/reservas da OP.^5 |
| SempreJu - `SD3` | Confirmar que `D3_TM` e `D3_CF` definem tipo de movimento; que `RE/DE` com terceira posicao 4 indica transferencia; e que existem campos de perda, ganho e origem de desmontagem.^6 |
| SempreJu - `SF5` | Confirmar o cadastro de tipos de movimento e a separacao entrada/devolucao/producao x requisicao/saida.^7 |
| SempreJu - `NNR` | Confirmar campos de cadastro dos armazens/locais, como tipo, integracao e MRP.^8 |
| TOTVS - diferencas entre MATA250, MATA680 e MATA681 | Confirmar que `MATA250` e producao simples sem controle de recursos, enquanto `MATA680`/`MATA681` envolvem operacoes, recursos e duracao.^9 |
| TOTVS - encerramento de OP parcialmente apontada | Confirmar que encerramento depende da mesma rotina de apontamento usada e que ha regra especifica para `PR0` no apontamento simples.^10 |
| TOTVS - avaliacao de estoque no apontamento | Confirmar que MATA680/MATA681 podem requisitar componentes conforme operacao, ultima operacao ou parametro F12.^11 |
| RFB Sistemas / RXM Tecnologia / TOTVS ExecAuto REST | Confirmar que a integracao correta para escrita deve executar rotina padrao por ExecAuto/API REST, nao escrever diretamente nas tabelas nativas.^1 ^2 ^3 |

## Limites e premissas

Nada foi inserido, alterado ou excluido nas bases. As consultas foram somente leitura.

Este documento nao afirma que o VettiFlow ja pode gravar no Protheus. O documento define o roadmap para chegar la com seguranca. Antes de escrita real, falta confirmar a rotina ADVPL exata usada na Vetti para cada acao, principalmente apontamento, transferencia, desmontagem e criacao/encerramento de OP.

Tambem existe uma diferenca importante entre dicionario/cadastro e historico real: o `SD3` oficial tem movimentos `999` e `499` em alto volume, mas estes codigos nao apareceram como registros ativos simples no `SF5` consultado. Portanto, `SF5` ajuda a entender a regra conceitual, mas nao deve ser usado sozinho para gerar movimento. A rotina oficial do Protheus deve decidir campos, numeracao, sequencia, saldo e validacoes.

## Locais oficiais e setores

Fonte interna: `NNR010`, filial 04, `VettiP12`.

| Local | Descricao oficial | Setor VettiFlow recomendado | Papel no fluxo |
|---|---|---|---|
| `01` | ALMOXARIFADO | Almoxarifado | Origem principal de componentes e materiais |
| `02` | USA | Especial | Tratar como local especial/bloqueado ate regra operacional |
| `03` | PRODUCAO SMD | Producao SMD | OP, empenho e apontamento SMD |
| `04` | PRODUCAO PTH | Producao PTH | OP e empenho existem; precisa entrar no roadmap |
| `05` | PRODUCAO MEC | Producao mecanica/montagem | OP, consumo e parte da producao; muitas entradas finais vao ao `10` |
| `06` | ASSIST TECNICA | Assistencia tecnica | Recebe transferencia e fluxo de suporte |
| `07` | SUPORTE EXTERNO | Suporte externo | Recebe transferencia; aparece em desmontagem historica |
| `08` | ITENS OBSOLETOS | Especial | Estoque especial/obsoleto |
| `10` | EXPEDICAO | Expedicao | Entrada final de acabado e expedicao |
| `11` | ESTOQUE ADRIAN | Especial | Estoque especial |
| `12` | ITENS ENTREGA FUTURA | Especial | Estoque especial |
| `70` | TERCEIROS - MAURO | Terceiros | OP/transferencia/retorno terceiro |
| `71` | TER.- FENIX JUNDIAI | Terceiros | Terceirizacao |
| `72` | TER. - GWANDS SP | Terceiros | Terceirizacao com historico real |
| `73` | TER. TRAFO | Terceiros | Terceirizacao |

Conclusao: "almoxarife", "producao", "expedicao" e "terceiros" nao sao categorias prontas de tela no SQL; sao uma camada operacional que o VettiFlow precisa mapear por cima dos locais oficiais do `NNR`.

## Criacao de OP

### Fonte externa

O cadastro de OP em `SC2` tem chave composta por filial, numero, item, sequencia e item de grade. O campo `C2_LOCAL` indica o armazem/local onde o produto produzido sera estocado.^4 A tabela `SD4` guarda empenhos da OP, com `D4_OP`, `D4_COD`, `D4_LOCAL`, quantidade original e saldo do empenho.^5

### Evidencia VettiP12

Nas OPs abertas sem producao desde 2026-01-01:

| Local OP | Local componente `SD4` | OPs abertas sem producao | Linhas `SD4` | Original | Restante |
|---|---|---:|---:|---:|---:|
| `05` | `05` | 28 | 153 | 102.024,22 | 102.024,22 |
| `03` | `03` | 15 | 538 | 1.654.077,71 | 1.654.077,71 |
| `10` | `10` | 10 | 75 | 8.366,85 | 8.366,85 |
| `70` | `70` | 7 | 82 | 29.195,55 | 29.195,55 |
| `06` | `06` | 2 | 16 | 64,04 | 64,04 |
| `04` | `04` | 2 | 14 | 1.636,32 | 1.636,32 |
| `07` | `07` | 2 | 10 | 1.981,59 | 1.981,59 |
| `01` | `01` | 1 | 5 | 20.001,96 | 20.001,96 |

Todas as 67 OPs abertas sem producao analisadas na producao oficial estavam sem movimento ativo em `SD3`.

### Regra para VettiFlow

Criar OP nao e transferencia fisica. O VettiFlow deve mostrar como "OP criada + materiais empenhados", nao como "material saiu do almoxarifado".

O app deve exibir:

| Dado | Origem Protheus | Uso no VettiFlow |
|---|---|---|
| OP | `SC2.C2_NUM + C2_ITEM + C2_SEQUEN + C2_ITEMGRD` | Identificador oficial da ordem |
| Produto | `SC2.C2_PRODUTO` | Produto a produzir |
| Quantidade planejada | `SC2.C2_QUANT` | Meta da OP |
| Local operacional | `SC2.C2_LOCAL` | Setor da OP |
| Componentes empenhados | `SD4` | Checklist/reserva de componentes |
| Quantidade original | `SD4.D4_QTDEORI` | Necessidade inicial |
| Saldo empenhado | `SD4.D4_QUANT` | O que ainda resta consumir |

## Apontamento de producao

### Fonte externa

A TOTVS diferencia tres caminhos principais:

| Rotina | Leitura externa | Implicacao para VettiFlow |
|---|---|---|
| `MATA250` | Producao simples; usada quando a empresa nao controla processos/recursos da producao; pode requisitar produtos empenhados automaticamente conforme parametrizacao.^9 | Parece ser o modelo mais proximo do que o historico `PR0/RE1` demonstra para o VettiFlow atual |
| `MATA681` | Exige roteiro produtivo; aponta operacoes, recursos e duracao; tambem requisita MOD quando aplicavel.^9 | Necessario se a Vetti controlar operacao/recurso/hora por etapa |
| `MATA680` | Usa operacoes alocadas/carga maquina e sugere recurso, datas e horas; requisita componentes/MOD de modo semelhante ao MATA681.^9 | Necessario se a Vetti usar carga maquina/roteiro operacional |

A TOTVS tambem documenta que, no MATA680/MATA681, a avaliacao de estoque dos componentes pode ocorrer por componente vinculado a operacao, na ultima operacao do roteiro ou a cada apontamento conforme parametro de tela.^11

### Evidencia VettiP12

O padrao real mais comum da Vetti em `SD3` desde 2026-01-01:

| Movimento | CF | TM | OP preenchida | Leitura |
|---|---|---|---|---|
| Entrada do acabado | `PR0` | `001` | Sim | Producao apontada |
| Consumo de componente | `RE1` | `999` | Sim | Requisicao/baixa dos componentes da OP |

Volume observado desde 2026-01-01:

| CF/TM | Linhas | Observacao |
|---|---:|---|
| `RE1/999` | 21.459 | Consumo de componente com `D3_OP` preenchido |
| `PR0/001` | 2.855 | Entrada de produto acabado com `D3_OP` preenchido |

### Local de consumo x local de entrada

No consumo de componentes, o local normalmente acompanha o local operacional da OP:

| Local OP | Local consumo `RE1` | Grupos |
|---|---|---:|
| `10` | `10` | 792 |
| `05` | `05` | 639 |
| `70` | `70` | 305 |
| `03` | `03` | 118 |
| `01` | `01` | 16 |
| `72` | `72` | 11 |
| `07` | `07` | 6 |

Ja a entrada do acabado pode mudar de local:

| Local OP | Local `PR0` | Grupos | Leitura |
|---|---|---:|---|
| `10` | `10` | 788 | Entrada direta na expedicao/local 10 |
| `05` | `05` | 354 | Entrada na propria producao MEC |
| `70` | `70` | 302 | Entrada no terceiro |
| `05` | `10` | 292 | Producao MEC consumindo no `05` e acabado entrando na expedicao `10` |
| `03` | `03` | 118 | Entrada direta SMD |
| `70` | `05` | 6 | Terceiro retornando/entrando em producao MEC |

Produtos com entrada do acabado em local diferente desde 2026-01-01:

| Produto | Local OP | Local entrada acabado | OPs | Quantidade produzida |
|---|---|---|---:|---:|
| `575-0767` | `05` | `10` | 51 | 26.817 |
| `575-0863` | `05` | `10` | 32 | 3.209 |
| `575-0764` | `05` | `10` | 23 | 35.743 |
| `575-0863E` | `05` | `10` | 23 | 6.334 |
| `575-0779` | `05` | `10` | 22 | 33.564 |
| `575-0862` | `05` | `10` | 15 | 10.655 |
| `203-025` | `05` | `10` | 13 | 9.297 |
| `575-0911` | `05` | `10` | 9 | 1.041 |

### Regra para VettiFlow

O VettiFlow deve tratar apontamento como evento composto:

1. Entrada do produto acabado (`PR0/001`).
2. Baixa dos componentes (`RE1/999`).
3. Atualizacao do saldo empenhado (`SD4`).
4. Atualizacao de saldo fisico (`SB2`), feita pelo Protheus.
5. Atualizacao de produzido/encerramento na OP (`SC2.C2_QUJE`, `SC2.C2_DATRF`), feita pela rotina oficial.

No app, o usuario nao deve escolher apenas "local da OP". A tela de apontamento precisa ter, mesmo que calculados automaticamente:

| Campo VettiFlow | Origem/regra |
|---|---|
| Local de consumo | default `C2_LOCAL` / `D4_LOCAL` |
| Local de entrada do acabado | regra por produto/familia/processo, podendo ser `10` |
| Quantidade boa | quantidade efetivamente produzida |
| Quantidade perda | `D3_PERDA`, quando houver |
| Quantidade ganho | `D3_QTGANHO`, quando houver |
| Encerrar OP | permitido conforme rotina original e status do apontamento |

## Encerramento de OP parcial

A TOTVS orienta que o encerramento de OP parcialmente apontada deve ocorrer pela mesma rotina usada no apontamento. Para apontamento simples (`MATA250`), a referencia operacional e o ultimo movimento `PR0`; para MATA680/MATA681, a referencia e o ultimo apontamento da ultima operacao.^10

Tambem existe uma trava relevante: nao deve encerrar OP com requisicoes sem apontamentos, nem com requisicoes posteriores a ultima producao.^10

Regra para VettiFlow:

| Situacao | Tratamento |
|---|---|
| OP sem `PR0` | Nao oferecer encerramento final |
| OP com requisicao posterior ao ultimo `PR0` | Bloquear ou exigir rotina oficial retornar erro |
| OP com producao parcial | Oferecer acao de encerramento somente via Protheus/ExecAuto |
| OP com roteiro/operacoes | Encerrar pela rotina operacional correta, nao pelo fluxo simples |

## Retorno e estorno de itens

### Estorno de apontamento

O historico real mostra que estorno de apontamento nao deve ser modelado como exclusao. O Protheus preserva rastreabilidade.

Caso real em `VettiP12`:

| Campo | Valor observado |
|---|---|
| OP | `01471801001` |
| Documento | `014718010` |
| Sequencia | `398619` |
| Data | 2026-03-09 |
| Produto acabado original | `PR0/001`, quantidade 200 |
| Reversao do acabado | `ER0/999`, quantidade 200 |
| Componentes consumidos | `RE1/999`, quantidade total 7.801,66 |
| Retorno de componentes | `DE1/499`, quantidade total 7.801,66 |
| Marcacao | movimentos originais com `D3_ESTORNO='S'` |

Resumo oficial desde 2026-01-01:

| Movimento | Linhas com estorno | Quantidade |
|---|---:|---:|
| `DE1/499` | 28 | 7.801,66 |
| `RE1/999` | 28 | 7.801,66 |
| `ER0/999` | 1 | 200 |
| `PR0/001` | 1 | 200 |

Regra para VettiFlow:

| Acao | Como representar |
|---|---|
| Estornar apontamento | Criar evento "estorno solicitado/realizado" vinculado ao documento original |
| Reverter acabado | Exibir `ER0` como saida/reversao do produto acabado |
| Retornar componentes | Exibir `DE1` como devolucao dos componentes para estoque |
| Restaurar empenho | Ler `SD4` apos rotina oficial; nao recalcular sozinho |
| Auditoria | Guardar doc, OP, numseq, usuario, data e motivo |

### Retorno/devolucao manual

Tambem existem movimentos `DE0/400` e `RE0/501` com `D3_OP` vazio. Eles devem ser tratados como ajuste/devolucao/requisicao manual de estoque, nao como estorno de OP.

Regra:

| Movimento | Tratamento no app |
|---|---|
| `DE1/499` com OP | retorno de componente por estorno de OP |
| `DE0/400` sem OP | devolucao/ajuste manual |
| `RE0/501` sem OP | requisicao/ajuste manual |
| `ER0/999` com OP | reversao de producao apontada |

## Transferencias entre setores

### Fonte externa

O dicionario `SD3` indica que o campo `D3_CF` define tipo `RE/DE` e que, quando a terceira posicao do `CF` e `4`, o movimento corresponde a transferencia entre armazens.^6

### Evidencia VettiP12

Padrao real:

| Lado | Movimento | OP |
|---|---|---|
| Origem | `RE4/999` | Vazio na transferencia pura |
| Destino | `DE4/499` | Vazio na transferencia pura |

Top pares desde 2026-01-01:

| Origem | Destino | Pares | Leitura operacional |
|---|---|---:|---|
| `01` | `70` | 2.292 | Almoxarifado para terceiro |
| `01` | `05` | 1.594 | Almoxarifado para producao MEC |
| `05` | `06` | 760 | Producao para assistencia tecnica |
| `01` | `10` | 757 | Almoxarifado para expedicao |
| `05` | `10` | 624 | Producao para expedicao |
| `01` | `72` | 305 | Almoxarifado para terceiro |
| `10` | `07` | 295 | Expedicao para suporte externo |
| `01` | `07` | 283 | Almoxarifado para suporte externo |
| `05` | `07` | 237 | Producao para suporte externo |
| `70` | `05` | 197 | Retorno de terceiro para producao |
| `03` | `70` | 195 | SMD para terceiro |
| `03` | `05` | 123 | SMD para MEC |

Regra para VettiFlow:

Transferencia precisa ser um fluxo proprio, com origem/destino, produto, quantidade, documento e status. Ela nao deve usar OP quando `D3_OP` vem vazio no Protheus oficial.

## Desmontagem

### Fonte externa

Referencias publicas indicam `MATA242` como rotina de desmontagem de produtos e apontam que ela trabalha com movimentacoes internas em `SD3` junto de tabelas de estoque.^12 A consulta publica sobre ponto de entrada `MT242CPO` tambem confirma que existe tela/grid de desmontagem no Protheus.^13

As fontes externas publicas sobre desmontagem sao menos completas do que as fontes oficiais de apontamento. Por isso, para desmontagem, o historico real da VettiP12 tem peso maior.

### Evidencia VettiP12

Padrao real:

| Parte | Movimento | Campo-chave |
|---|---|---|
| Produto origem desmontado | `RE7/999` | `D3_FATHER='F'` |
| Itens retornados/gerados | `DE7/499` | Mesmo documento e `D3_NUMSEQ` |
| OP | vazio | Fluxo sem `D3_OP` |

Documentos reais desde 2024:

| Documento | Data | Saidas origem | Entradas componentes |
|---|---|---:|---:|
| `Q000004AV` | 2026-09-03 | 1 | 3 |
| `Q000003YV` | 2026-06-29 | 1 | 8 |
| `Q000003TP` | 2026-05-18 | 1 | 5 |
| `DESMONT23` | 2025-05-23 | 1 | 17 |
| `DESMONT22` | 2025-05-23 | 1 | 5 |
| `DESMONT20` | 2025-04-30 | 1 | 3 |
| `DESMONT19` | 2025-04-08 | 1 | 7 |

Exemplo real:

| Documento | Linha | Produto | Local | CF/TM | Quantidade | Observacao |
|---|---|---|---|---|---:|---|
| `Q000004AV` | origem | `203-058` | `10` | `RE7/999` | 500 | `D3_FATHER='F'` |
| `Q000004AV` | retorno | `103-087` | `01` | `DE7/499` | 500 | componente gerado |
| `Q000004AV` | retorno | `200-179` | `01` | `DE7/499` | 500 | componente gerado |
| `Q000004AV` | retorno | `MOD08010901002` | `01` | `DE7/499` | 0,56 | componente/MOD gerado |

Outro exemplo:

| Documento | Linha | Produto | Local | CF/TM | Quantidade |
|---|---|---|---|---|---:|
| `Q000003YV` | origem | `575-0888` | `10` | `RE7/999` | 227 |
| `Q000003YV` | retorno | `100-010` | `05` | `DE7/499` | 227 |
| `Q000003YV` | retorno | `106-010` | `05` | `DE7/499` | 454 |
| `Q000003YV` | retorno | `203-010` | `05` | `DE7/499` | 227 |
| `Q000003YV` | retorno | `464-000` | `05` | `DE7/499` | 454 |

Regra para VettiFlow:

| Requisito | Detalhe |
|---|---|
| Fluxo separado de OP | Desmontagem nao deve cair no kanban normal de OP |
| Origem unica | Um produto origem sai como `RE7/999` |
| Destinos multiplos | Componentes entram como `DE7/499` |
| Documento unico | Todas as linhas devem compartilhar doc/numseq oficial |
| Sem escrita SQL | Rotina oficial deve gerar documentos e saldos |
| Previa obrigatoria | VettiFlow deve mostrar simulacao antes de enviar |

## Perda, ganho e apontamento parcial

### Fonte externa

O dicionario `SD3` contem campos especificos para perda (`D3_PERDA`), ganho (`D3_QTGANHO`) e quantidade maior (`D3_QTMAIOR`).^6 Isso confirma que perda/ganho nao devem ser tratados como observacao livre.

### Evidencia VettiP12

Desde 2024-01-01:

| Movimento | Local | Linhas | Quantidade boa | Perda | Ganho | Maior |
|---|---|---:|---:|---:|---:|---:|
| `PR0/001` | `05` | 135 | 178.810 | 764 | 8 | 0 |
| `PR0/001` | `70` | 1 | 995 | 5 | 0 | 0 |
| `PR0/001` | `10` | 1 | 296 | 4 | 0 | 0 |

Amostras reais:

| Documento | Data | OP | Produto | Local | Boa | Perda | Ganho |
|---|---|---|---|---|---:|---:|---:|
| `016295010` | 2026-09-02 | `01629501001` | `203-006` | `05` | 1.986 | 14 | 0 |
| `016266010` | 2026-08-31 | `01626601001` | `203-042` | `05` | 415 | 5 | 0 |
| `016103010` | 2026-08-28 | `01610301001` | `203-006` | `05` | 3.954 | 46 | 0 |
| `Q000002K2` | 2025-07-04 | `01247101001` | `575-0911` | `05` | 86 | 0 | 6 |
| `005787010` | 2024-02-01 | `00578701001` | `203-003` | `05` | 202 | 0 | 2 |

Regra para VettiFlow:

| Campo app | Campo Protheus | Observacao |
|---|---|---|
| Quantidade boa | `D3_QUANT` | Quantidade que entrou como acabado |
| Perda | `D3_PERDA` | Perda no apontamento; nao e item separado |
| Ganho | `D3_QTGANHO` | Ganho no apontamento |
| Excedente/maior | `D3_QTMAIOR` | Reservar no modelo mesmo que nao tenha volume recente |
| Parcial/final | `SC2.C2_QUJE`, `C2_DATRF` | Ler apos rotina oficial |

## Comparacao VettiP12 x HMLp12

O `HMLp12` esta bom para teste porque replica os principais padroes, mas esta atrasado em relacao ao oficial.

| Item | VettiP12 oficial | HMLp12 teste | Decisao |
|---|---|---|---|
| Ultima OP observada | 2026-09-09 | 2026-08-24 | Usar producao para analise, HML para teste |
| Locais `NNR010` | Mesmo mapa | Mesmo mapa | OK |
| OP aberta sem producao | `SC2` + `SD4`, sem `SD3` | quase igual | OK |
| Apontamento | `PR0/001` + `RE1/999` | mesmo padrao | OK |
| Transferencia | `RE4/999` + `DE4/499` | mesmo padrao | OK |
| Desmontagem | `RE7/999` + `DE7/499` | mesmo padrao | OK |
| Estorno | `ER0/999` + `DE1/499` | mesmo padrao | OK |
| Perda/ganho | `D3_PERDA`, `D3_QTGANHO` | existe, mas com menos registros recentes | Testar no HML com fixture controlada |

## Arquitetura recomendada

### Principio de escrita

O backend do VettiFlow deve continuar read-only ate existir uma camada Protheus oficial.

Quando for liberar escrita, a ordem correta e:

1. VettiFlow monta uma intencao de movimento.
2. Backend valida permissao, local, produto, OP e quantidade.
3. Backend faz dry-run e mostra ao usuario o que sera enviado.
4. Backend chama rotina ADVPL/REST no Protheus.
5. Protheus executa rotina oficial/ExecAuto.
6. Backend le o resultado em `SC2`, `SD4`, `SD3`, `SB2`.
7. VettiFlow mostra o documento oficial criado.

### Por que ExecAuto/API REST

Fontes externas de integracao Protheus reforcam que `MSExecAuto` executa a rotina padrao sem tela, respeitando validacoes e regras do modulo, e que escrita direta em tabela pode pular gatilhos, custos, fiscais, locks e consistencias.^1 ^2 A propria TOTVS demonstra chamada REST para rotina compilada que por sua vez executa uma rotina automatica.^3

Regra de ouro: o SQL Server e fonte de leitura e reconciliacao; a escrita de negocio deve ser feita pelo Protheus.

## Roadmap detalhado

### Fase 0 - Congelar seguranca

Objetivo: garantir que ninguem grave direto por acidente.

| Item | Acao |
|---|---|
| Backend MSSQL | Manter somente SELECT |
| Permissao SQL | Usuario tecnico preferencialmente sem `INSERT`, `UPDATE`, `DELETE` |
| Codigo | Bloquear qualquer rota de mutacao Protheus nativa |
| Logs | Registrar consultas e ambiente sem gravar credenciais |
| Documentacao | Manter `VettiP12` como oficial e `HMLp12` como teste |

### Fase 1 - Modelo canonico de leitura

Objetivo: o VettiFlow ler o Protheus do jeito que o Protheus pensa.

| Entidade VettiFlow | Fonte Protheus | Campos minimos |
|---|---|---|
| Produto | `SB1` | codigo, descricao, UM, tipo, grupo, bloqueio |
| Saldo | `SB2` | produto, local, saldo atual, empenhado |
| Local/setor | `NNR` | local, descricao, tipo, MRP |
| Estrutura | `SG1` | pai, componente, quantidade, sequencia |
| OP | `SC2` | chave, produto, quantidade, local, produzido, encerramento |
| Empenho | `SD4` | OP, componente, local, original, saldo |
| Movimento | `SD3` | doc, numseq, OP, produto, local, CF, TM, quantidade, estorno, perda/ganho |

### Fase 2 - Simulador de movimento

Objetivo: antes de escrever, prever o que deveria acontecer e comparar com historico real.

| Fluxo | Simulacao esperada |
|---|---|
| Criar OP | `SC2` + `SD4`, sem `SD3` |
| Apontar OP | `PR0/001` + `RE1/999`, com doc/numseq comum |
| Apontar com perda | `PR0/001` com `D3_PERDA` |
| Apontar com ganho | `PR0/001` com `D3_QTGANHO` |
| Estornar apontamento | marcacao de estorno + `ER0/999` + `DE1/499` |
| Transferir | par `RE4/999` + `DE4/499` |
| Desmontar | `RE7/999` origem + `DE7/499` retornos |

### Fase 3 - Rotinas oficiais Protheus

Objetivo: descobrir e encapsular as rotinas certas.

| Acao VettiFlow | Rotina candidata | Confirmacao obrigatoria |
|---|---|---|
| Criar OP | rotina de OP/cadastro PCP usada pela Vetti | Confirmar fonte ADVPL/menu/log |
| Apontamento simples | `MATA250` | Confirmar se a Vetti usa simples para os casos `PR0/RE1` |
| Apontamento por operacao | `MATA680`/`MATA681` | Confirmar se ha roteiro, recurso, MOD, carga maquina |
| Transferencia simples | `MATA260` ou fluxo equivalente | Confirmar rotina usada no menu oficial |
| Transferencia multipla | `MATA261` ou fluxo equivalente | Confirmar para movimentos em lote |
| Desmontagem | `MATA242` | Confirmar campos obrigatorios e retorno |
| Movimento interno | `MATA080` ou equivalente de estoque | Confirmar uso real para ajustes/manuais |

### Fase 4 - Escrita controlada no HML

Objetivo: testar sem risco operacional.

| Caso de teste | Resultado esperado |
|---|---|
| OP local `05`, entrada `05` | `SC2/SD4`; depois `PR0` e `RE1` no `05` |
| OP local `05`, entrada `10` | consumo `RE1` no `05`, entrada `PR0` no `10` |
| OP SMD `03` | consumo e entrada no `03` |
| OP terceiro `70` | consumo/entrada no `70` ou retorno para `05` conforme regra |
| Apontamento com perda | `PR0/001` com `D3_PERDA` preenchido |
| Apontamento com ganho | `PR0/001` com `D3_QTGANHO` preenchido |
| Estorno | `ER0` + `DE1`, sem apagar historico |
| Transferencia `01 -> 05` | `RE4/999` origem + `DE4/499` destino |
| Transferencia `05 -> 10` | par de transferencia sem OP |
| Desmontagem | `RE7/999` origem + `DE7/499` retornos |

### Fase 5 - UI e produto

Objetivo: fazer o app guiar a operacao correta.

| Area do app | Ajuste |
|---|---|
| Dashboard OP | Mostrar local operacional, local de consumo e local de entrada do acabado |
| SMD | Tratar `03` como fluxo proprio |
| PTH | Adicionar `04` ao mapa ou deixar explicitamente fora do MVP |
| MEC/montagem | Suportar `05 -> 10` |
| Expedicao | Receber acabado por `PR0` e transferencias `DE4` |
| Almoxarifado | Transferir para producao/terceiros/suporte |
| Terceiros | Modelar `70-73`, principalmente `70` e `72` |
| Assistencia/suporte | Separar `06` e `07` |
| Desmontagem | Nova tela/processo; nao misturar com OP |
| Auditoria | Mostrar documento oficial e movimentos gerados |

## Regras de negocio propostas

### Regra 1 - Criacao de OP

Se uma OP e criada, o VettiFlow deve esperar `SC2` e `SD4`, mas nao `SD3`.

Validacao:

| Condicao | Resultado |
|---|---|
| Existe `SC2` | OP existe |
| Existe `SD4` | Componentes empenhados |
| Existe `SD3` antes de producao | Excecao a investigar |
| `D4_QTDEORI = D4_QUANT` | Nada consumido ainda |

### Regra 2 - Apontamento simples

Se a OP e apontada, o VettiFlow deve procurar movimentos por `D3_OP`.

Validacao:

| Condicao | Resultado |
|---|---|
| `PR0/001` existe | Produto acabado entrou |
| `RE1/999` existe | Componentes foram consumidos |
| Mesmo `D3_NUMSEQ` | Mesmo evento/transacao |
| `D3_ESTORNO` vazio | Movimento ativo |
| `D3_ESTORNO='S'` | Movimento estornado |

### Regra 3 - Local do acabado

O local do acabado nao deve ser derivado cegamente de `C2_LOCAL`.

Ordem recomendada para decidir:

1. Regra explicita por produto/familia.
2. Historico recente do mesmo produto.
3. Regra por setor: por exemplo, MEC `05` pode entrar em expedicao `10`.
4. Escolha manual com confirmacao.
5. Bloqueio se nenhuma regra for segura.

### Regra 4 - Estorno

Estorno e reversao, nao exclusao.

O VettiFlow deve manter:

| Dado | Por que importa |
|---|---|
| Documento original | rastrear apontamento |
| Documento/numseq reversao | rastrear estorno |
| Usuario/motivo | auditoria |
| Quantidade boa/perda/ganho | conciliacao |
| Componentes retornados | estoque correto |

### Regra 5 - Desmontagem

Desmontagem e fluxo proprio de estoque.

| Entrada da tela | Saida esperada |
|---|---|
| Produto origem | `RE7/999` com `D3_FATHER='F'` |
| Local origem | `D3_LOCAL` da linha `RE7` |
| Componentes retornados | linhas `DE7/499` |
| Locais destino | podem variar por componente |
| Documento | unico para todo o evento |

### Regra 6 - Transferencia

Transferencia entre setores e par de movimentos.

| Origem | Destino |
|---|---|
| `RE4/999` | `DE4/499` |

O app deve impedir que transferencia seja confundida com baixa de OP.

## Gaps criticos antes de escrita

| Gap | Risco | Como resolver |
|---|---|---|
| Rotina exata de criacao de OP | OP pode nascer sem empenho correto | Confirmar menu/ADVPL/log oficial |
| Rotina exata de apontamento usada pela Vetti | Pode ignorar roteiro, MOD ou recurso | Confirmar se e MATA250, MATA680 ou MATA681 |
| Regra `05 -> 10` | Entrada do acabado no local errado | Criar tabela/regra de roteamento por produto |
| Codigos `999`/`499` fora do SF5 ativo simples | Escrita direta pode falhar ou gerar saldo incorreto | Deixar Protheus gerar via rotina |
| Lote/serie/endereco | Saldo pode ficar inconsistente se produto exigir controle | Auditar campos de lote/enderecamento antes da escrita |
| Permissao por usuario | Operador pode executar rotina indevida | Usar usuario Protheus/contexto correto no wrapper |
| Estorno parcial | Pode devolver componente errado | Sempre chamar rotina oficial e reconciliar retorno |
| Desmontagem com MOD/componentes especiais | Pode gerar itens inesperados | Testar casos reais `Q000004AV`, `Q000003YV`, `DESMONT23` no HML |

## Decisoes de produto

| Decisao | Recomendacao |
|---|---|
| VettiFlow cria OP agora? | Primeiro leitura + dry-run; escrita so por API Protheus |
| VettiFlow aponta producao agora? | Implementar simulador e comparar; depois HML por ExecAuto |
| Mostrar PTH `04`? | Sim, pelo menos no mapa/listagem |
| Mostrar terceiros `70-73`? | Sim, principalmente `70` e `72` |
| Desmontagem entra no MVP? | Sim como modulo separado se for rotina frequente; senao backlog com leitura |
| Estorno entra no MVP? | Sim para consulta/auditoria; escrita so depois |
| Operador escolhe local final? | Deve vir sugerido por regra, mas permitir confirmacao quando houver excecao |

## Consultas de auditoria recomendadas

Estas consultas sao conceitos de auditoria. Nao incluem credenciais.

| Pergunta | Fonte |
|---|---|
| OP aberta sem producao | `SC2` left join `SD3`, join `SD4` |
| Empenho restante | `SD4.D4_QTDEORI`, `SD4.D4_QUANT` |
| Produto acabado produzido | `SD3` filtrando `PR0/001` |
| Componentes consumidos | `SD3` filtrando `RE1/999` |
| Transferencias | pares `RE4/999` e `DE4/499` por doc/produto/quantidade |
| Estornos | `D3_ESTORNO='S'`, `ER0`, `DE1` |
| Desmontagens | `RE7`, `DE7`, `D3_FATHER`, doc e numseq |
| Perda/ganho | `D3_PERDA`, `D3_QTGANHO`, `D3_QTMAIOR` |
| Local final diferente | `SC2.C2_LOCAL` x `PR0.D3_LOCAL` |

## Roadmap final recomendado

1. Finalizar leitura oficial: ampliar API read-only para `SC2`, `SD4`, `SD3`, `NNR`, `SB2`, `SG1` com filtros seguros.
2. Criar camada de reconciliacao: cada OP do VettiFlow precisa mostrar "planejado, empenhado, produzido, consumido, estornado, transferido".
3. Implementar roteamento de locais: separar OP, consumo e entrada do acabado; incluir regra `05 -> 10`.
4. Adicionar setores faltantes: `04`, `70-73`, especiais com flag de uso.
5. Criar simulador: gerar previsao de movimentos e comparar contra exemplos reais de `VettiP12`.
6. Criar fixtures HML: OP normal, OP com perda, OP com ganho, OP `05 -> 10`, estorno, transferencia, desmontagem.
7. Especificar API Protheus: endpoints internos que chamam ADVPL/ExecAuto.
8. Testar escrita so no HML: validar saldo antes/depois por `SB2`, OP por `SC2`, empenho por `SD4`, movimentos por `SD3`.
9. Liberar producao por fase: primeiro transferencia, depois apontamento simples, depois estorno, depois desmontagem.
10. Criar auditoria diaria: divergencias entre intencao VettiFlow e documento oficial Protheus.

## Veredito

O caminho correto nao e "parar de usar Postgres e gravar direto no SQL Server". O caminho correto e:

1. Parar de depender de Postgres para leitura operacional.
2. Ler `VettiP12`/`HMLp12` diretamente em modo read-only.
3. Documentar o comportamento real por `SC2`, `SD4`, `SD3`, `SB2` e `NNR`.
4. Implementar no VettiFlow uma representacao fiel: OP, empenho, apontamento, estorno, transferencia e desmontagem separados.
5. Quando chegar em escrita, chamar Protheus por rotina oficial/ExecAuto, nunca `INSERT` direto em tabela nativa.

O VettiFlow ja pode evoluir com seguranca na leitura e no roadmap. A escrita deve esperar a camada Protheus oficial, porque os movimentos reais envolvem regras que o SQL historico revela, mas nao executa.

## Mapa do VettiFlow atual

Esta secao mapeia o VettiFlow como ele esta hoje no codigo, para comparar o produto atual com o roadmap Protheus completo.

### Diagnostico curto

O VettiFlow atual e um bom MVP de acompanhamento de producao, mas ainda nao e um cockpit completo de Protheus.

Ele cobre bem:

1. Abertura visual de OP.
2. Consulta de produtos/componentes/saldos no Protheus.
3. Fluxo interno de etapas de producao.
4. Assinatura por operador/PIN.
5. Pausa, retomada, tempos, defeitos e relatorios.
6. Fila conceitual para envio ao Protheus.

Ele ainda nao cobre de forma completa:

1. Leitura historica oficial de OPs existentes no Protheus como fonte primaria do fluxo.
2. Escrita real no Protheus.
3. Apontamento real `PR0/RE1`.
4. Estorno real `ER0/DE1`.
5. Transferencia real `RE4/DE4`.
6. Desmontagem real `RE7/DE7`.
7. Locais oficiais faltantes: `04`, `70`, `71`, `72`, `73`, `02`, `08`, `11`, `12`.
8. Regras de local final do acabado, principalmente `05 -> 10`.

### Arquitetura atual

| Camada | Arquivo principal | O que faz hoje | Limitacao contra Protheus |
|---|---|---|---|
| App/root | `lib/app/vetti_flow_app.dart` | Monta providers, tema, API client, stores e rotas | Usa `EmptyProductionFlowDatabase` e `EmptyWarehouseRequestDatabase`; persistencia real removida junto com Postgres |
| Rotas | `lib/app/app_routes.dart` | Expoe login, dashboard, setores, fila Protheus e TV | Rotas existem, mas nem todas representam rotinas Protheus nativas |
| Estado de OP | `lib/data/repositories/production_flow_store.dart` | Fonte central das OPs do app; cria, inicia, pausa, conclui, cancela, armazena e despacha | Estado e do VettiFlow, nao espelho completo de `SC2`/`SD4`/`SD3` |
| Modelo de OP | `lib/data/models/production_flow.dart` | Define etapas, status, pausas, sessoes, defeitos, quantidades e rotas planejadas | Nao tem documento Protheus, `D3_NUMSEQ`, `D3_CF`, `D3_TM`, perda/ganho oficial, estorno ou desmontagem |
| Adapter dashboard | `lib/data/repositories/flow_op_repository.dart` | Converte `ProductionOrderFlow` em `OrdemProducao` para telas | Traduz fluxo local; nao reconcilia historico oficial do Protheus |
| API Protheus leitura | `api/app/main.py` + `api/app/mssql.py` | Consulta health, produtos, componentes, saldos, OPs abertas e empenhos | Nao le ainda SD3 consolidado por OP, movimentos, estornos, transferencias e desmontagens |
| Fila Protheus | `PendingMutationStore`, `MutationSyncService`, `ProtheusSyncClient` | Guarda e tenta enviar mutacoes para `/api/v1/mutations` e `/api/v1/finalizar` | Backend atual bloqueia mutacoes em modo read-only |
| Mutacoes | `lib/data/models/pending_mutation.dart` | Ja modela abertura OP, empenho, transferencia e baixa de producao | Modelos existem, mas nao ha aplicador real Protheus/ExecAuto |
| Requisicoes de armazem | `WarehouseRequestStore` | Cria confirmacoes internas quando componente esta em outro local | E workflow interno; nao gera `RE4/DE4` oficial |
| Operadores | `lib/shared/models/operator.dart` | Login, PIN, area e etapa por operador | Autenticacao hardcoded; precisa migrar para backend/config/Protheus antes de producao forte |
| Roteamento local | `lib/shared/models/warehouse_routing.dart` | Mapeia `01`, `03`, `05`, `06`, `07`, `10` para telas/responsaveis | Falta `04`, `70-73` e especiais; `10` esta como area production, nao expedicao independente |

### Telas e cobertura funcional

| Tela/rota | Cobertura atual | O que falta para Protheus completo |
|---|---|---|
| `/login` | Login local por operador, senha/PIN e redirecionamento por etapa | Autenticacao real, permissoes por perfil, trilha de auditoria e remocao de credenciais hardcoded |
| `/dashboard` | Kanban/listas/cards, filtros, detalhe da OP, avancar/regredir, cancelar, criar OP, editar rota e ver relatorios | Carregar OPs oficiais do Protheus, reconciliar status real, bloquear acoes conforme rotina oficial |
| `/almoxarifado` | Fila de OPs no estagio almoxarifado; iniciar, pausar e entregar itens; criar OP local de teste | Transformar entrega em reserva/transferencia oficial quando aplicavel; tratar `01 -> 05`, `01 -> 03`, `01 -> 70`, `01 -> 10` |
| `/smd` | Reusa `FirmwarePage` parametrizada para SMD; iniciar, pausar, concluir apontamento SMD | Diferenciar apontamento SMD real, OP filha/intermediaria, roteiro ou liberacao para proxima etapa |
| `/firmware` | Etapa de gravacao; start/pause/complete; assinatura e defeitos opcionais | Definir se e etapa interna VettiFlow ou operacao Protheus `MATA680/MATA681` |
| `/soldagem` | Etapa visual propria de soldagem; start/pause/complete | Mapear se soldagem e operacao de roteiro, centro de trabalho ou apenas marco interno |
| `/teste` | Teste funcional, checklist e defeitos `T1..T8`; conclui para fechamento/expedicao conforme rota | Integrar defeitos com qualidade/suporte Protheus, retorno de componentes e retrabalho |
| `/fechamento` | Etapa de fechamento; start/pause/complete; pode registrar quantidade fechada | Relacionar fechamento com quantidade boa, perda e entrada final `PR0` |
| `/expedicao` | Conferencia final; despacha ou armazena parte da OP; permite expedir armazenadas depois | Virar entrada oficial em local `10`, armazenamento, expedicao e possivel nota/pedido quando existir regra |
| `/suporte` | Lista defeitos vindos do teste e permite conferencia/pedido visual | Integrar `06/07`, retorno, requisicao de peca, retrabalho, desmontagem ou transferencia real |
| `/fila-protheus` | Exibe fila, status, envio para API e acao de aplicar ERP | Hoje a API recusa escrita; precisa mostrar explicitamente "read-only" e depois chamar ExecAuto |
| `/tv` | Painel de acompanhamento em tempo real do fluxo interno | OK para gestao visual, mas precisa consumir status reconciliado com Protheus |

### Fluxo interno atual

O fluxo padrao do app esta em `ProductionStage.productionFlow`:

| Ordem | Etapa VettiFlow | Local/Protheus aproximado | Comentario |
|---:|---|---|---|
| 1 | Almoxarifado | `01` | Preparacao/entrega interna, nao movimento `SD3` oficial hoje |
| 2 | SMD | `03` | Existe como etapa propria, mas sem rotina Protheus propria |
| 3 | Gravacao | dentro do fluxo `05` | Etapa interna de producao |
| 4 | Soldagem | dentro do fluxo `05` | Etapa interna de producao |
| 5 | Teste | dentro do fluxo `05` | Etapa interna com defeitos |
| 6 | Fechamento | dentro do fluxo `05` | Ponto natural para quantidade boa/perda |
| 7 | Expedicao | `10` | Hoje finaliza/despacha; no Protheus pode ser local de entrada do acabado |

Esse fluxo e linear por padrao, mas o app ja tem `plannedStages`, ou seja, existe base para pular/reordenar etapas. Isso e importante para acomodar produtos que nao passam por todos os postos.

### Dados que o app ja sabe ler do Protheus

| Dado | Endpoint atual | Origem SQL | Status |
|---|---|---|---|
| Health/conexao | `GET /api/v1/health` | `DB_NAME()` | Pronto |
| Busca de produtos | `GET /api/v1/produtos` | `SB1` | Pronto |
| Produto por codigo | `GET /api/v1/produtos/{codigo}` | `SB1` | Pronto |
| Estrutura/componentes | `GET /api/v1/produtos/{codigo}` | `SG1` + `SB1` | Pronto basico |
| Saldos por local | `GET /api/v1/produtos/{codigo}/saldos` | `SB2` | Pronto basico |
| OPs abertas | `GET /api/v1/ops/abertas` | `SC2` | Pronto basico |
| Empenhos da OP | `GET /api/v1/ops/{op}/empenhos` | `SD4` | Pronto basico |

Leitura que ainda falta:

| Dado faltante | Origem SQL | Por que precisa |
|---|---|---|
| Movimentos por OP | `SD3` por `D3_OP` | Saber `PR0`, `RE1`, estorno, perda e ganho |
| Transferencias por doc/produto | `SD3` `RE4/DE4` | Mostrar fluxo real entre setores |
| Desmontagens | `SD3` `RE7/DE7`, `D3_FATHER` | Criar modulo separado de desmontagem |
| Status oficial da OP | `SC2` + `SD3` + `SD4` | Evitar status so local |
| Local final do acabado | `SD3.PR0.D3_LOCAL` | Resolver `05 -> 10` |
| Consumo real de componente | `SD3.RE1` + `SD4` | Conciliar empenhado x consumido |
| Perda/ganho | `SD3.D3_PERDA`, `D3_QTGANHO`, `D3_QTMAIOR` | Apontamento correto |
| Locais oficiais completos | `NNR` | Incluir PTH, terceiros e especiais |
| Produtos com roteiro/operacao | tabelas PCP/roteiro a confirmar | Diferenciar `MATA250` de `MATA680/MATA681` |

### Mutacoes ja desenhadas, mas nao implementadas no Protheus

O app ja tem quatro tipos conceituais de mutacao:

| Mutacao | Existe no modelo? | Backend aceita hoje? | Movimento Protheus esperado |
|---|---|---|---|
| `aberturaOp` | Sim | Nao, read-only | Criar `SC2` + `SD4` por rotina oficial |
| `empenho` | Sim | Nao, read-only | Alterar empenho da OP por rotina oficial |
| `transferencia` | Sim | Nao, read-only | Gerar `RE4/999` + `DE4/499` |
| `baixaProducao` | Sim | Nao, read-only | Gerar `PR0/001` + `RE1/999` |

Mutacoes que ainda nem existem no modelo:

| Mutacao faltante | Movimento esperado |
|---|---|
| Estorno de apontamento | `ER0/999` + `DE1/499` e marcacao de estorno |
| Desmontagem | `RE7/999` + `DE7/499` |
| Retorno/devolucao manual | `DE0/400` ou rotina equivalente |
| Requisicao manual | `RE0/501` ou rotina equivalente |
| Ajuste de perda/ganho | campos oficiais no apontamento, nao texto livre |
| Fechamento/encerramento oficial de OP parcial | rotina do mesmo apontamento usado |

### Onde o VettiFlow esta limitado a producao

A limitacao nao e so visual. Ela aparece no modelo:

| Tema | Evidencia no app | Efeito |
|---|---|---|
| Area principal | `WorkArea.production` domina firmware, soldagem, teste, fechamento, expedicao | Fluxo foi desenhado em volta da producao interna |
| Locais mapeados | Apenas `01`, `03`, `05`, `06`, `07`, `10` | PTH e terceiros oficiais ficam invisiveis |
| OP como entidade central | Quase toda tela depende de `ProductionOrderFlow` | Transferencia/desmontagem sem OP ficam sem lugar natural |
| Suporte | Nasce de defeitos do teste | Nao cobre assistencia tecnica completa do local `06` nem suporte externo `07` com estoque real |
| Almoxarifado | Atua como etapa da OP | Nao cobre todas as transferencias reais de estoque |
| Expedicao | Finaliza/despacha OP local | Ainda nao representa `PR0` no local `10` como movimento Protheus oficial |
| Relatorios | Calculam em cima do store local | Nao conciliam com `SD3`, `SC2`, `SD4`, `SB2` oficiais |

### O que falta implementar, por prioridade

#### P0 - Manter base segura e leitura confiavel

| Item | Implementacao |
|---|---|
| API read-only explicita | Manter bloqueio atual para mutation enquanto nao houver ExecAuto |
| Indicador de ambiente | Mostrar no app se esta em `HMLp12` ou `VettiP12` |
| Aviso de fila read-only | Ajustar tela da fila para nao sugerir que "Aplicar ERP" funciona enquanto backend recusa |
| Remover credenciais hardcoded do produto final | Trocar operadores/senhas/PINs por configuracao segura/backend |

#### P1 - Espelhar Protheus antes de escrever

| Item | Implementacao |
|---|---|
| Leitura de OP oficial | Tela/servico para `SC2` + `SD4` + status derivado |
| Leitura de movimento oficial | Endpoint para `SD3` por OP/doc/produto/local |
| Reconciliacao OP | Comparar OP local VettiFlow x OP oficial Protheus |
| Locais oficiais | Carregar `NNR` e mapear todos os locais |
| Local final do acabado | Criar regra `C2_LOCAL` x `PR0.D3_LOCAL`, incluindo `05 -> 10` |

#### P2 - Cobrir fluxos reais fora da linha de producao

| Fluxo | Implementacao necessaria |
|---|---|
| Transferencia | Entidade/tela propria para origem, destino, doc e status; depois rotina oficial |
| Terceiros | Incluir locais `70-73`, filas, envio e retorno |
| PTH | Incluir local `04` como setor/tela ou variante de producao |
| Assistencia/suporte | Separar `06` assistencia tecnica e `07` suporte externo |
| Estoques especiais | Regras para `02`, `08`, `11`, `12` |

#### P3 - Apontamento oficial

| Item | Implementacao |
|---|---|
| Baixa de producao | Converter conclusao de etapa final em intencao `baixaProducao` |
| Quantidade boa | Campo explicito na conclusao |
| Perda | Campo explicito, mapeado para `D3_PERDA` |
| Ganho | Campo explicito, mapeado para `D3_QTGANHO` |
| Componentes consumidos | Usar `SD4`/estrutura e reconciliar com `RE1` |
| Rotina | Confirmar e chamar `MATA250`, `MATA680` ou `MATA681` via ADVPL/ExecAuto |

#### P4 - Retorno, estorno e desmontagem

| Item | Implementacao |
|---|---|
| Estorno | Nova mutacao e tela de auditoria para `ER0/DE1` |
| Retorno manual | Separar devolucao/requisicao manual de estorno de OP |
| Desmontagem | Novo modulo sem OP, com origem `RE7` e retornos `DE7` |
| Auditoria | Guardar doc/numseq oficial retornado pela rotina |

#### P5 - Persistencia e auditoria VettiFlow

| Item | Implementacao |
|---|---|
| Banco proprio leve | Decidir se precisa SQLite/API propria para historico VettiFlow, sem voltar ao Postgres |
| Eventos locais | Registrar acoes do app como auditoria, nao como verdade de estoque |
| Reprocessamento | Fila idempotente com retry e reconciliacao |
| Relatorios reais | Unir tempos do VettiFlow com movimentos oficiais do Protheus |

### Backlog em formato de implementacao

| Entrega | Arquivos impactados | Resultado esperado |
|---|---|---|
| Endpoint `GET /api/v1/locais` | `api/app/mssql.py`, `api/app/main.py`, schemas/testes | App le `NNR` e para de depender de mapa fixo |
| Endpoint `GET /api/v1/ops/{op}/movimentos` | API + modelo Dart | Tela mostra `PR0`, `RE1`, `ER0`, `DE1`, perda/ganho |
| Endpoint de transferencias | API + nova tela/modelo | Fluxo `RE4/DE4` visivel sem OP |
| Endpoint de desmontagens | API + nova tela/modelo | Fluxo `RE7/DE7` visivel sem OP |
| Reconciliacao OP | `ProductionFlowStore`, `FlowOpRepository`, dashboard | Status local nao contradiz Protheus |
| Roteamento dinamico de local | `warehouse_routing.dart`, dialog de OP, fechamento/expedicao | Suporte real a `05 -> 10`, terceiros e PTH |
| Ajuste de fila read-only | `fila_protheus_page.dart`, `ProtheusSyncClient` | Usuario entende que escrita esta bloqueada |
| Wrapper Protheus | novo servico ADVPL/API | Escrita via rotina oficial, nao SQL |
| Desmontagem UI | nova rota/tela | Processo separado do kanban de OP |
| Estorno UI | dashboard/detalhe OP + API | Estorno rastreavel por documento |

### Decisao pratica

O proximo passo mais seguro e transformar o VettiFlow de "controle local de producao" em "leitor operacional do Protheus com reconciliacao".

Ordem recomendada:

1. Implementar leitura de `NNR` para locais oficiais.
2. Implementar leitura de `SD3` por OP.
3. Mostrar no detalhe da OP os movimentos oficiais: `PR0`, `RE1`, `ER0`, `DE1`, perda e ganho.
4. Adicionar uma tela/aba de transferencias `RE4/DE4`.
5. Adicionar uma tela/aba de desmontagem `RE7/DE7`.
6. So depois religar escrita por ExecAuto no HML.

## Sources

1. RFB Sistemas. "[Rotina automatica no Protheus: como automatizar processos com ExecAuto e API REST](https://rfbsistemas.com.br/protheus/execauto-protheus-automatizar-com-api-rest/)." Consultado em 2026-09-09.
2. RXM Tecnologia. "[ExecAuto na pratica: rodando rotinas Protheus sem abrir tela](https://rxmtecnologia.com.br/blog/execauto-na-pratica-rodando-rotinas-protheus-sem-abrir-tela)." Consultado em 2026-09-09.
3. TOTVS Central de Atendimento. "[Cross Segmentos - Backoffice Protheus - SIGAFAT - ExecAuto com API REST](https://centraldeatendimento.totvs.com/hc/pt-br/articles/31722376056215-Cross-Segmentos-Backoffice-Protheus-SIGAFAT-ExecAuto-com-API-REST)." Consultado em 2026-09-09.
4. SempreJu. "[Tabela: SC2 - Ordens de Producao](https://sempreju.com.br/tabelas_protheus/tabelas/tabela_sc2.html)." Consultado em 2026-09-09.
5. SempreJu. "[Tabela: SD4 - Requisicoes Empenhadas](https://sempreju.com.br/tabelas_protheus/tabelas/tabela_sd4.html)." Consultado em 2026-09-09.
6. SempreJu. "[Tabela: SD3 - Movimentacoes Internas](https://sempreju.com.br/tabelas_protheus/tabelas/tabela_sd3.html)." Consultado em 2026-09-09.
7. SempreJu. "[Tabela: SF5 - Tipos de Movimentacao](https://sempreju.com.br/tabelas_protheus/tabelas/tabela_sf5.html)." Consultado em 2026-09-09.
8. SempreJu. "[Tabela: NNR - Locais de Estoque](https://sempreju.com.br/tabelas_protheus/tabelas/tabela_nnr.html)." Consultado em 2026-09-09.
9. TOTVS Central de Atendimento. "[Manufatura - Linha Protheus - SIGAPCP - Diferencas nas rotinas de apontamento do MATA250, MATA680 e MATA681](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360028693311-Manufatura-Linha-Protheus-SIGAPCP-Diferen%C3%A7as-nas-rotinas-de-apontamento-do-MATA250-MATA680-e-MATA681)." 14 maio 2024. Consultado em 2026-09-09.
10. TOTVS Central de Atendimento. "[Manufatura - Linha Protheus - SIGAPCP - Encerrar ordem de producao apontada parcialmente](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360024734631-Manufatura-Linha-Protheus-SIGAPCP-Encerrar-ordem-de-produ%C3%A7%C3%A3o-apontada-parcialmente)." 24 novembro 2025. Consultado em 2026-09-09.
11. TOTVS Central de Atendimento. "[Manufatura - Linha Protheus - SIGAPCP - Quando o Sistema avaliara o estoque dos componentes no apontamento](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360027347792-Manufatura-Linha-Protheus-SIGAPCP-Quando-o-Sistema-avaliar%C3%A1-o-estoque-dos-componentes-no-apontamento)." 19 outubro 2021. Consultado em 2026-09-09.
12. Protheus/TOTVS public index evidence. Busca publica por rotina `MATA242` associada a desmontagem e tabelas `SB1`, `SB2`, `SB9`, `SD3`, `SI1`, `SI2`, `SI5`, `SI6`, `SI7`, `SD7`; usada apenas como suporte, com confirmacao principal no historico `VettiP12`.
13. ProtheusAdvpl. "[Ponto de Entrada MT242CPO - Adiciona Campos no Grid da tela de desmontagem de produtos](https://protheusadvpl.com.br/)." Consultado em 2026-09-09.
