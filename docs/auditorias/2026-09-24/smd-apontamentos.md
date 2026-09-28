# SMD: atividade da Paula e rotina de apontamento

Consulta em 24/09/2026. Banco DEV `HMLp12`, empresa 010, filial 04. Apenas SELECT; nenhuma execução ou compilação ADVPL, alteração de parâmetros ou movimentação no ERP.

## Resultado

`SYS_USR.USR_CODIGO=paulad` identifica Paula Daniela Soares Moraes. A leitura de identidade utilizou somente login e nome. Em SD3, os registros desse login sustentam uma operação de apontamento de produção acompanhada de consumo dos componentes.

| Recorte | Produção PR0 | Consumo RE1 | Transferência RE4/DE4 |
|---|---:|---:|---:|
| Desde 24/06/2026, local 03 | 59 | 1.970 | 0 |
| Todo o histórico disponível desse login, local 03 | 347 | 10.519 | 0 |
| Todo o histórico disponível desse login, local 10 | 0 | 87 | 0 |

O recorte recente corresponde a 37 OPs distintas. O histórico encontrado desse login começa em 21/01/2025 e vai até 17/09/2026. As contagens representam registros, não peças nem cliques manuais. As baixas RE1 não provam que Paula digitou cada componente individualmente.

Outros usuários também movimentam o SMD: em três meses, o local 03 tem 66 PR0, 2.081 RE1, 150 RE4, 19 DE4 e um DE0. Há apontamentos de Tatiane e Vera. Por isso, a tela consulta o setor inteiro, sem ocultar registros que não sejam da Paula.

Em SC2, local 03: 19 OPs abertas, das quais três com produção parcial; 538 encerradas. Encerramento segue C2_DATRF, não apenas a diferença entre planejado e produzido.

Em setembro/2026, a consulta de todo o SMD retorna nove apontamentos de produção e 268 registros de consumo, até 18/09. Não são totais exclusivos da Paula.

## Fonte interno da Vetti

Raiz fornecida pelo usuário: `C:\Users\Leonardo Morais\Desktop\vetti\VettiFlow\protheus_advpl\vettip12`.

`pcp/atualizacao/RPCPA001.prw` contém a tela **Apontamento de Produção**:

- `VldOP`, aproximadamente linhas 502–507: aceita OP não encerrada, mostra saldo e assume o armazém da SC2.
- `ApontarPro`, aproximadamente linhas 165–212: calcula C2_QUANT menos C2_QUJE, valida OP, armazém e quantidade; rejeita quantidade maior que o saldo.
- Monta D3_OP, D3_COD, D3_QUANT, D3_LOCAL e D3_TM=001; chama `MSExecAuto` com **MATA250** na linha 212.
- O mesmo fonte contém apontamento de perdas com **MATA685**, linhas 399 e 450. A existência dessa opção não comprova seu uso pela Paula.

`pcp/ponto de entrada/A650LEMP.prw`, linha 27, define o armazém do empenho a partir de C2_LOCAL.

Em SX6, filial 04, foram encontrados `MV_REQAUT=A` e `MV_PRODAUT=T`. Os parâmetros, o fonte e a sequência PR0/RE1 observada são compatíveis com consumo dos componentes no apontamento. Não foi consultada documentação pública nesta verificação; trata-se da evidência da instalação da Vetti.

## Limites da confirmação

- SD3 prova os movimentos encontrados para o login; não prova todas as atividades, permissões ou atribuições da pessoa.
- Não foi confirmado o menu exato atribuído à Paula nem que cada lançamento passou especificamente por RPCPA001. MATA250 está comprovada nesse fonte, não em um log de execução individual.
- SBC010 e SH6010 não foram encontradas nesse DEV; não foi validado histórico de perdas/apontamentos por essas tabelas.
- RE1 em outro armazém existe no histórico. O detalhe da OP consulta seus movimentos e empenhos; o histórico geral do SMD filtra local 03.
- Nada nesta pesquisa autoriza escrita. O VettiFlow continua somente consultando o Protheus.

Dados agregados e amostras: [smd-evidencias.json](https://github.com/LeoMorais0930/vettiflow-flutter-app/blob/8329fe3a23a2b12d98d63ab71ad405469b124a0b/docs/auditorias/2026-09-24/smd-evidencias.json).

## Rechecagem completa do login solicitada pelo usuário

Nova consulta no mesmo dia, **sem filtro de filial, armazém, período ou exclusão** em SD3010. O resultado continuou restrito a PR0/TM001 e RE1/TM999, todos na filial 04, sem registros excluídos desse login. SD3900, a outra tabela de movimentos internos encontrada no DEV, não retornou registros de paulad.

Dos 347 PR0, 346 não têm marca de estorno e um está estornado. Dos 10.606 RE1 (03 + 10), 28 estão estornados. Todos os 10.606 consumos correspondem a um PR0 do mesmo login, filial, OP, documento e data. Esse vínculo reforça a leitura de consumo associado ao apontamento, sem comprovar individualmente qual ação de tela gerou cada linha.

O apontamento estornado é da OP **01471801001**, produto **500-0945**, **200 peças**, emissão **09/03/2026**, armazém 03. A marca de estorno não identifica quem estornou. SD3010_TTAT_LOG tem aproximadamente 812 linhas, mas não retornou entradas pelo login/ID da Paula nem alteração D3_ESTORNO dos 29 registros vinculados. Portanto, o autor e a data da execução do estorno não puderam ser confirmados; 09/03 é a emissão original.

Existe também outro cadastro com login `paula`, de outra pessoa. A verificação acima usa especificamente **paulad — Paula Daniela Soares Moraes**. Confirma o uso registrado nos movimentos internos disponíveis do DEV; não certifica permissões nem ausência de outras atividades em módulos sem essa identificação.
