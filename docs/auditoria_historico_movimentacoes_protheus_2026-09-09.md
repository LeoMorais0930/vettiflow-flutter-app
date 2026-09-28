# Auditoria Oficial de Movimentacoes Protheus x VettiFlow

> Documento histórico preservado para pesquisa e rastreabilidade. O funcionamento atual está no [índice por setor](README.md). Planos de escrita abaixo não autorizam alterações no Protheus.

Data da auditoria: 2026-09-09  
Fonte oficial: `VettiP12`, filial 04, somente leitura  
Fonte de teste: `HMLp12`, filial 04, somente leitura  
Objetivo: confirmar como o Protheus movimenta OPs, empenhos, baixas e transferencias nas rotinas oficiais, comparar com o HML/dev e transformar isso em roadmap para o VettiFlow.

## Resposta direta

Ao criar OP, o Protheus oficial nao gera movimento fisico em `SD3`. Ele cria a OP em `SC2` e cria/atualiza empenhos em `SD4`; o reflexo fisico disso aparece em `SB2.B2_QEMP`.

Nas OPs abertas sem producao desde 2026-01-01 no `VettiP12`, o padrao foi:

- 67 OPs abertas sem producao analisadas.
- 67/67 sem `SD3` ativo.
- `SC2.C2_LOCAL` igual a `SD4.D4_LOCAL` nas linhas de empenho.
- `SD4.D4_QTDEORI` igual a `SD4.D4_QUANT`, ou seja, empenho ainda cheio.

Quando a OP e baixada, ai sim aparece `SD3`:

- Produto acabado: `D3_CF='PR0'`, `D3_TM='001'`, `D3_OP` preenchido.
- Componentes: `D3_CF='RE1'`, `D3_TM='999'`, `D3_OP` preenchido.
- Transferencia entre locais: par `RE4/TM 999` na origem e `DE4/TM 499` no destino, normalmente com `D3_OP` vazio.

O ponto mais importante para o VettiFlow: o local da OP nem sempre e o local onde entra o produto acabado. Em producao oficial, muitas OPs com `C2_LOCAL='05'` consomem componentes no local `05`, mas entram o produto acabado por `PR0` no local `10` expedicao.

## Locais oficiais do Protheus

Tabela fonte: `NNR010`.

| Local | Descricao oficial | Classificacao operacional sugerida |
|---|---|---|
| `01` | ALMOXARIFADO | Almoxarifado / origem principal de material |
| `02` | USA | Estoque especial |
| `03` | PRODUCAO SMD | Producao SMD |
| `04` | PRODUCAO PTH | Producao PTH |
| `05` | PRODUCAO MEC | Producao mecanica / montagem |
| `06` | ASSIST TECNICA | Assistencia tecnica |
| `07` | SUPORTE EXTERNO | Suporte externo |
| `08` | ITENS OBSOLETOS | Estoque bloqueado/especial |
| `10` | EXPEDICAO | Expedicao / estoque de saida |
| `11` | ESTOQUE ADRIAN | Estoque especial |
| `12` | ITENS ENTREGA FUTURA | Estoque especial |
| `70` | TERCEIROS - MAURO | Terceirizacao |
| `71` | TER.- FENIX JUNDIAI | Terceirizacao |
| `72` | TER. - GWANDS SP | Terceirizacao |
| `73` | TER. TRAFO | Terceirizacao |

No `NNR010`, quase todos aparecem com `NNR_TIPO='1'`, `NNR_INTP='3'`, `NNR_MRP='1'`; o local `01` veio sem esses marcadores preenchidos. O Protheus nao entrega ali uma classificacao amigavel como "almoxarife/producao/expedicao"; essa camada precisa ser interpretada pelo nome oficial e pelo historico de uso.

## Mapa atual do VettiFlow

Fonte: `lib/shared/models/warehouse_routing.dart`.

| Local | VettiFlow hoje | Status contra Protheus |
|---|---|---|
| `01` | Almoxarifado, Vera | Bate |
| `03` | SMD, Paula | Bate |
| `05` | Producao, Tatiane/Andressa | Bate parcialmente: representa MEC, mas o produto acabado pode entrar no `10` |
| `06` | Suporte, Bruno | Bate como suporte/assistencia |
| `07` | Suporte, Bruno | Bate como suporte externo |
| `10` | Expedicao, Rafaela/Bruna/Tamara | Bate |

Locais oficiais ainda nao modelados no VettiFlow:

- `04` PRODUCAO PTH
- `70`, `71`, `72`, `73` terceiros
- `02`, `08`, `11`, `12` estoques especiais

Isso e uma diferenca real de roadmap, nao apenas detalhe visual.

## Como a OP nasce no Protheus oficial

Fluxo observado nas OPs abertas sem producao:

1. `SC2` recebe a OP.
2. `C2_LOCAL` define o local operacional da OP.
3. `SD4` recebe os componentes empenhados.
4. `D4_LOCAL` fica igual ao local da OP nas amostras abertas recentes.
5. `SB2.B2_QEMP` reflete o total empenhado.
6. `SD3` nao recebe movimento fisico enquanto nao ha baixa/producao.

Amostra `VettiP12` desde 2026-01-01:

| Local OP | Local componente `SD4` | OPs abertas sem producao | Linhas SD4 | Original | Restante |
|---|---|---:|---:|---:|---:|
| `05` | `05` | 28 | 153 | 102.024,22 | 102.024,22 |
| `03` | `03` | 15 | 538 | 1.654.077,71 | 1.654.077,71 |
| `10` | `10` | 10 | 75 | 8.366,85 | 8.366,85 |
| `70` | `70` | 7 | 82 | 29.195,55 | 29.195,55 |
| `06` | `06` | 2 | 16 | 64,04 | 64,04 |
| `04` | `04` | 2 | 14 | 1.636,32 | 1.636,32 |
| `07` | `07` | 2 | 10 | 1.981,59 | 1.981,59 |
| `01` | `01` | 1 | 5 | 20.001,96 | 20.001,96 |

Interpretacao: criar OP nao e transferencia fisica de estoque. E uma reserva/empenho no local da OP.

## Como a baixa oficial movimenta estoque

### Produto acabado

Padrao oficial:

- `SD3.D3_CF='PR0'`
- `SD3.D3_TM='001'`
- `SD3.D3_OP` preenchido
- `SD3.D3_NUMSEQ` compartilhado entre a entrada `PR0` e os consumos `RE1` da mesma transacao

Distribuicao `VettiP12` desde 2026-01-01:

| CF | TM | Local movimento | Linhas | Quantidade | OP preenchida |
|---|---|---|---:|---:|---:|
| `PR0` | `001` | `10` | 1.872 | 319.553 | 1.872 |
| `PR0` | `001` | `05` | 404 | 342.445 | 404 |
| `PR0` | `001` | `70` | 350 | 309.800 | 350 |
| `PR0` | `001` | `03` | 187 | 214.454 | 187 |
| `PR0` | `001` | `01` | 16 | 17.266 | 16 |
| `PR0` | `001` | `07` | 15 | 895 | 15 |
| `PR0` | `001` | `72` | 11 | 5.000 | 11 |

Comparacao `C2_LOCAL` x local da entrada `PR0`:

| Local OP | Local PR0 | Grupos | Leitura |
|---|---|---:|---|
| `10` | `10` | 788 | Bate direto |
| `05` | `05` | 354 | Bate direto |
| `70` | `70` | 302 | Bate direto |
| `05` | `10` | 292 | Producao MEC consumindo no `05` e entrando acabado na expedicao `10` |
| `03` | `03` | 118 | Bate direto |
| `70` | `05` | 6 | Terceiro com entrada final no `05` |
| `05` | `07` | 5 | Excecao/suporte |
| `10` | `07` | 4 | Excecao/suporte |

Caso real:

- OP `01621401001`
- `C2_LOCAL='05'`
- Produto `575-0863`
- Produzido 150
- Entradas `PR0` no local `10`
- Consumos `RE1` no local `05`

Esse e o comportamento que o VettiFlow precisa reproduzir: OP de producao pode consumir em um local e dar entrada do acabado em outro.

### Componentes

Padrao oficial:

- `SD3.D3_CF='RE1'`
- `SD3.D3_TM='999'`
- `SD3.D3_OP` preenchido
- Local de consumo normalmente acompanha o local da OP/empenho.

Distribuicao `VettiP12` desde 2026-01-01:

| Local OP | Local consumo RE1 | Grupos | Quantidade |
|---|---|---:|---:|
| `10` | `10` | 792 | 706.782,26 |
| `05` | `05` | 639 | 2.576.578,82 |
| `70` | `70` | 305 | 1.859.190,07 |
| `03` | `03` | 118 | 8.541.484,14 |
| `01` | `01` | 16 | 72.230,36 |
| `72` | `72` | 11 | 288.531,50 |
| `07` | `07` | 6 | 795,11 |

Interpretacao: o consumo de componentes fica no local operacional da OP; a entrada do produto acabado pode ir para outro local, especialmente `05 -> 10`.

## Transferencias oficiais

Padrao oficial de transferencia simples:

- Saida da origem: `RE4`, `TM 999`
- Entrada no destino: `DE4`, `TM 499`
- Mesmo documento
- Mesmo produto
- Mesma quantidade
- `D3_OP` vazio para transferencia pura

Top pares `VettiP12` desde 2026-01-01:

| Origem | Destino | Pares | Leitura operacional |
|---|---|---:|---|
| `01` | `70` | 2.292 | Almoxarifado para terceiro |
| `01` | `05` | 1.594 | Almoxarifado para producao MEC |
| `05` | `06` | 760 | Producao para assistencia |
| `01` | `10` | 757 | Almoxarifado para expedicao |
| `05` | `10` | 624 | Producao para expedicao |
| `01` | `72` | 305 | Almoxarifado para terceiro |
| `10` | `07` | 295 | Expedicao para suporte externo |
| `01` | `07` | 283 | Almoxarifado para suporte externo |
| `05` | `07` | 237 | Producao para suporte externo |
| `70` | `05` | 197 | Retorno terceiro para producao |
| `03` | `70` | 195 | SMD para terceiro |
| `03` | `05` | 123 | SMD para MEC |

Isso mostra que o VettiFlow precisa distinguir dois fluxos:

- baixa de OP, com `D3_OP` preenchido
- transferencia entre setores, com `D3_OP` vazio

## Diferenca VettiP12 x HMLp12

O HMLp12 replica bem a estrutura e a maioria dos padroes, mas esta atrasado em relacao ao oficial:

| Item | VettiP12 oficial | HMLp12 teste |
|---|---|---|
| Ultima OP observada | 2026-09-09 | 2026-08-24 |
| `NNR010` locais | Mesmo mapa | Mesmo mapa |
| Criacao de OP sem producao | 67/67 sem `SD3` | quase igual; 1 excecao com `SD3` |
| `PR0` | `CF PR0`, `TM 001` | mesmo padrao |
| `RE1` | `CF RE1`, `TM 999` | mesmo padrao |
| Transferencia | `RE4/999` + `DE4/499` | mesmo padrao |
| Local `05 -> 10` no acabado | confirmado | confirmado |

Conclusao: HMLp12 serve para testar o fluxo, mas o roadmap deve considerar o VettiP12 como fonte oficial. Quando houver divergencia, a producao manda.

## Diferencas contra o VettiFlow atual

| Tema | VettiFlow atual | Protheus oficial | Acao |
|---|---|---|---|
| Criacao de OP | local da OP e componentes selecionados | reserva `SD4` no local da OP; sem `SD3` | manter leitura/dry-run |
| Produto acabado | `D3_TM` antigo como `PR0` | `D3_TM='001'` | corrigir regra antes de escrever |
| Consumo | `D3_TM` antigo como `RE1` | `D3_TM='999'` | corrigir regra antes de escrever |
| Entrada de acabado | app tende a usar local da OP | oficial permite `05 -> 10`, `70 -> 05`, etc. | criar regra de local de entrada |
| Transferencia | mesmo produto origem/destino | `RE4/999` + `DE4/499`, `D3_OP` vazio | separar de baixa de OP |
| Setores | cobre `01`, `03`, `05`, `06`, `07`, `10` | tambem existem `04`, `70-73`, especiais | ampliar mapa |
| Terceiros | nao ha fluxo dedicado | local `70` e `72` sao relevantes | adicionar trilha terceiros |
| PTH | nao ha tela/area dedicada | local `04` existe e tem OP/empenho | decidir se entra no fluxo |

## Roadmap recomendado

1. Criar mapa canonico de locais Protheus
   - Basear em `NNR010`.
   - Manter classificacao VettiFlow separada: almoxarifado, SMD, PTH, MEC, expedicao, assistencia, suporte, terceiros, especiais.

2. Separar local da OP, local de consumo e local de entrada
   - `C2_LOCAL`: local operacional da OP.
   - `D4_LOCAL` / `RE1.D3_LOCAL`: local onde componente fica empenhado/consumido.
   - `PR0.D3_LOCAL`: local onde entra o acabado.
   - Regra essencial: suportar `05 -> 10`.

3. Criar servico backend de dry-run Protheus
   - Gerar payload esperado para `SC2`, `SD4`, `SD3` e `SB2`.
   - Nunca gravar direto no Flutter.
   - Comparar payload gerado contra amostras reais do `VettiP12`.

4. Validar regras de rotina oficial antes de liberar escrita
   - Confirmar de onde o Protheus tira `D3_NUMSEQ`.
   - Confirmar se `999` e `499` vem de rotina interna, parametro, gatilho ou regra ADVPL, ja que nao aparecem como `SF5` ativo.
   - Confirmar regra exata que decide quando `C2_LOCAL='05'` entra `PR0` em `10`.

5. Testar primeiro no HMLp12
   - Repetir casos: `05 -> 05`, `05 -> 10`, `03 -> 03`, `70 -> 70`, transferencia `01 -> 05`, transferencia `05 -> 10`.
   - Rodar em dry-run e comparar com historico.
   - So depois considerar escrita controlada.

## Pendencias para destravar escrita

1. Acesso ou exportacao das rotinas ADVPL/appserver que geram baixa de OP e transferencia.
2. Confirmacao com usuario Protheus sobre regra de destino do acabado (`PR0.D3_LOCAL`).
3. Decisao de produto: VettiFlow vai modelar `04` PTH e `70-73` terceiros agora ou deixar em backlog.
4. Definir se suporte `06/07` continua bloqueado como origem de material ou se precisa excecao por rotina.
5. Criar fixtures anonimizadas de OP real para testes automatizados.

## Conclusao

A leitura atual do VettiFlow esta alinhada com o Protheus. O fluxo oficial confirmado e:

- Criar OP: `SC2` + empenho `SD4`, sem `SD3`.
- Produzir/baixar: `PR0/001` para entrada do acabado e `RE1/999` para consumo.
- Transferir: `RE4/999` na origem e `DE4/499` no destino.
- Setores oficiais estao em `NNR010`, mas precisam de uma classificacao propria no VettiFlow.

O maior ajuste de roadmap e separar "local da OP" de "local onde entra o acabado". O caso `05 -> 10` e real em producao e precisa virar regra antes de qualquer escrita.

