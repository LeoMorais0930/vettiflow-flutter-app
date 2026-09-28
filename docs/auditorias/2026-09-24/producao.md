# Produção — DEV e sequência local

24/09/2026. DEV HMLp12, empresa 010, filial 04. Consultas SELECT, sem execução ADVPL ou alteração no ERP. Janela recente desde 24/06/2026. SQL e parâmetros em [producao-evidencias.json](https://github.com/LeoMorais0930/vettiflow-flutter-app/blob/8329fe3a23a2b12d98d63ab71ad405469b124a0b/docs/auditorias/2026-09-24/producao-evidencias.json).

## Identidade e movimentos

SYS_USR identifica `TATIANE` como Tatiane e `andressa.camargo` como Andressa Camargo.

Entradas PR0 vinculadas a OPs cujo C2_LOCAL é 05:

| Destino do produto | Tatiane | Andressa | Login expedição |
|---|---:|---:|---:|
| 05 | 85 | 46 | 3 |
| 07 | 4 | 0 | 0 |
| 10 | 104 | 54 | 0 |

São contagens de registros, não peças. O vínculo usa filial e C2_NUM+C2_ITEM+C2_SEQUEN = D3_OP. As datas são dos movimentos, sem exigir OP emitida no mesmo período.

No 05, há também transferências (763 entradas DE4 e 587 saídas RE4), consumo (1.773 RE1), ajustes (um DE0 e quatro RE0) e desmontagem (um RE7 e nove DE7). Os 139 PR0 fisicamente no 05 incluem entradas de OPs de outros locais; não equivalem aos 134 PR0 da primeira linha da tabela acima.

Pares de transferência com origem 05 e destino 06/07/10 foram encontrados em 278/107/181 entradas, respectivamente. A correlação exige filial, data, documento, sequência não vazia e mesma situação de estorno, com RE4 na origem e DE4 no destino. Não exige o mesmo produto, pois há trocas de código no histórico.

SC2 do 05, sem corte de período: **139 abertas e 3.405 encerradas**. Primeira emissão 18/11/2020; última 18/09/2026. OP aberta segue C2_DATRF vazio.

Em setembro, a nova consulta retorna 19 OPs abertas emitidas no mês, 49 registros de produção e 316 consumos. Amostra: OP 01642801001, produto 575-0764, quantidade 972 no local 10, usuário andressa.camargo; componentes vinculados aparecem no 05.

## Fontes internos

Fontes copiados da VM, sob `C:\Users\Leonardo Morais\Desktop\vetti\VettiFlow\protheus_advpl\vettip12`:

- `pcp/atualizacao/RPCPA001.prw`, linhas 203–212: monta OP, produto, quantidade e armazém de entrada; chama **MATA250**. O destino do produto é informado separadamente do local da OP. O fonte valida saldo restante, mas o contrato completo de integração ainda exige estudo de perdas/estorno/concorrência.
- `estoque/atualizacao/RESTA007.prw`, `RESTA008.prw` e `RESTA011.prw`: referências a **MATA261** para transferências. A existência desses fontes não identifica qual tela gerou cada registro do banco.
- `pcp/execblock/RPCPE002.prw` e `RPCPE003.prw`: envio/retorno de materiais para terceiros, ligados ao botão MA650BUT, usando C2_LOC3 e SD4. Também chamam MATA261; esse fluxo não deve ser confundido com suporte ou expedição.

## Regra do VettiFlow e limite da evidência

A escolha das etapas e o ponto final são decisões de Tatiane/Andressa no VettiFlow. Os movimentos Protheus não revelam por si só se uma OP está em gravação, soldagem, teste ou fechamento. A consulta não inventa essas etapas a partir de SC2/SD3.

A orientação de movimentar oficialmente ao enviar quantidades para suporte/expedição é a regra desejada do aplicativo. O histórico mostra duas operações distintas nesses destinos: **apontar um produto no destino** e **transferir estoque existente**. Não é correto executar sempre MATA261 nem apontar produção duas vezes. A futura integração deverá escolher o contrato conforme a situação do lote.

O registro local de defeitos ainda não representa separação física de quantidade, documento de remessa ou retorno do suporte. A escrita, o fracionamento do lote e a conciliação entre OP local e oficial seguem pendentes. Esta entrega fornece consulta oficial e escolha/correção da sequência local.
