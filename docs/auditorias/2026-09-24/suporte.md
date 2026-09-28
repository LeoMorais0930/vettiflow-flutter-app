# Suporte — evidências do DEV e ADVPL

Consulta em 24/09/2026, somente SELECT, base HMLp12, empresa 010 e filial 04
(salvo consultas de identidade e tabelas compartilhadas explicitadas no JSON).
Período recente: 24/06/2026 a 24/09/2026, inclusive. SQL, parâmetros e resultados:
[suporte-evidencias.json](https://github.com/LeoMorais0930/vettiflow-flutter-app/blob/8329fe3a23a2b12d98d63ab71ad405469b124a0b/docs/auditorias/2026-09-24/suporte-evidencias.json).

## Locais e movimentos

NNR identifica 06 como `ASSIST TECNICA` e 07 como `SUPORTE EXTERNO`.

| Armazém | Nos últimos três meses |
|---|---|
| 06 | 302 DE4, 37 RE4 e 8 RE0; 5 itens de notas de entrada |
| 07 | 488 DE4, 12 RE4 e 7 PR0; 13 itens de notas de saída |

São **854 registros SD3 e 18 itens fiscais**, não quantidade de peças ou de
consertos. Nenhum RE1 nos dois locais nesse recorte. No histórico completo,
há PR0, RE1, RE0/DE0, RE4/DE4, RE6/DE6 e RE7/DE7. Portanto, restringir o suporte
a defeitos ou somente transferências esconderia operações existentes.

Transferências recentes, por pares RE4/DE4, sem estorno:

| Origem | Destino | Pares |
|---|---|---:|
| 01 | 07 | 143 |
| 03 | 07 | 39 |
| 05 | 06 | 278 |
| 05 | 07 | 107 |
| 06 | 05 | 30 |
| 06 | 10 | 7 |
| 07 | 01 | 1 |
| 07 | 05 | 3 |
| 07 | 06 | 2 |
| 07 | 10 | 6 |
| 10 | 06 | 22 |
| 10 | 07 | 199 |

Essas direções comprovam movimentações de entrada e saída. Não estabelecem
sozinhas uma relação de devolução entre duas transferências de datas diferentes.

SC2: 06 tem 2 OPs abertas e 8 encerradas; 07 tem 2 abertas e 38 encerradas.
SB2: 06 tem 2.092 registros de produtos, dos quais 33 com saldo não zero;
07 tem 2.094, dos quais 169 com saldo não zero. Saldo atual não é estoque histórico.

## Notas fiscais

No recorte, 06 recebe: TES 079 (conserto/reparo, estoque N), 098 (retorno de
mostruário, S) e 109 (retorno em garantia, S). 07 possui saídas com TES 540
(garantia, S), 701 (bonificação/doação/brinde, N) e 800 (serviços, N).
Esses são os valores atuais de SF4. Não basta a existência da nota para
afirmar baixa/entrada de estoque. SD1 usa data de digitação; SD2 usa emissão.

No histórico completo há 250 itens SD1 e 30 SD2 no 06, e 54 SD1 e 698 SD2 no 07.
Eles são consultáveis na aba Notas sem recorte de três meses.

## Usuários

SYS_USR possui login `bruno`, nome Bruno. Não há SD3 não excluído atribuído a
esse login no conjunto consultado da empresa 010 (sem corte de período,
armazém ou filial nessa busca). Isso não prova ausência de trabalho no suporte
nem limitações de permissão: outros logins registram os movimentos, e a consulta
não atribui automaticamente autor a documentos fiscais.

No período recente aparecem, entre outros, `matheus`, `vinicius`, `TATIANE`,
`gabriel.fontes`, `andressa.camargo`, `expedicao` e `vera`, conforme o JSON.

## Fontes autênticos copiados da VM

Raiz: `C:/Users/Leonardo Morais/Desktop/vetti/VettiFlow/protheus_advpl/vettip12`.
Nenhum fonte foi alterado, compilado ou executado.

| Fonte | O que o código demonstra | Limite da evidência |
|---|---|---|
| `estoque/atualizacao/RESTA007.prw`, `RESTA008.prw`, `RESTA011.prw` | Rotinas personalizadas chamam MATA261 para transferência | Não identificam automaticamente qual rotina gerou cada SD3 |
| `pcp/atualizacao/RPCPA001.prw` | Apontamento via MATA250, quantidade/OP/local; tratamento separado de perdas | A presença do fonte não prova que Bruno usa a rotina |
| `estoque/atualizacao/RESTA010.prw` | Artur, 31/03/2025; tela “Zerar Armazém 07”, TM 501, MATA241; observação `LIMPEZA MENSAL DO SALDO ARM 07` | Não foram encontrados SD3 ativos de 06/07 com `LIMPEZA MENSAL`; os RE0 existentes não comprovam execução deste fonte |
| `gestao de servico/RTECA001.PRW` | Criação de base instalada a partir de documento de entrada, checando F1_TIPO e F1_INTTEC; usa SD1, AA3 e TECA040, depois marca integração em SF1 | Não é uma ficha de reparo nem uma rotina que deva ser executada pelo VettiFlow agora |

As tabelas de serviço consultadas têm 171 bases AA3, 116 registros AB1,
2 AB6, 31 AB7 e 22 AB9, todos em filial compartilhada vazia. As maiores datas
de emissão em AB1/AB6/AB7 são 05/07/2022. Não há evidência de atendimento recente
nessas três fontes; AA3/AB9 foram apenas contadas, sem afirmar data de atividade.

## Entrega e pendências

A tela entrega consulta real de movimentações, notas, saldo, OPs e inventário
do 06/07, mantendo os defeitos locais identificados à parte. Não inicia nem
finaliza reparos, não zera saldo e não grava transferências/notas/requisições.
O vínculo operacional defeito → remessa → reparo → retorno continua pendente
de implementação e validação documental.
