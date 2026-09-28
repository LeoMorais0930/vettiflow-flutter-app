# Sprints Protheus x VettiFlow

> Documento histórico preservado para pesquisa e rastreabilidade. O funcionamento atual está no [índice por setor](README.md). Planos de escrita abaixo não autorizam alterações no Protheus.

Objetivo: evoluir o VettiFlow de controle local de producao para leitor operacional fiel do Protheus, baseado no historico real de movimentos do `VettiP12` e no ambiente de teste `HMLp12`.

## Sprint 1 - Base oficial de locais e leitura segura

Status: concluida.

1. Concluido: criar endpoint `GET /api/v1/locais`.
2. Concluido: ler locais oficiais da `NNR010`.
3. Concluido: expor no app se a API esta conectada ao `HMLp12` ou `VettiP12`.
4. Concluido: incluir no modelo os locais faltantes: `04`, `70`, `71`, `72`, `73`, `02`, `08`, `11`, `12`.
5. Concluido: ajustar a UI/fila para deixar claro quando o backend esta em modo read-only.

## Sprint 2 - Movimentos oficiais por OP

Status: concluida.

1. Concluido: criar endpoint `GET /api/v1/ops/{op}/movimentos`.
2. Concluido: mostrar no detalhe da OP movimentos `PR0`, `RE1`, `ER0`, `DE1`.
3. Concluido: mostrar perda, ganho, estorno, documento e `D3_NUMSEQ`.
4. Concluido: derivar status oficial por `SC2` + `SD4` + `SD3`.
5. Concluido: comparar estado local do VettiFlow com historico oficial do Protheus.

Evidencia real read-only: OP `01621401001` retornou `PR0/001` no local `10`, consumos `RE1/999` no local `05`, status `apontada_parcial`, documento `016214010`, sequencia `416149`, e divergencia oficial `Produto acabado entrou em 10, diferente do local da OP 05`.

## Sprint 3 - Roteamento real de locais

Status: concluida.

1. Concluido: separar local da OP, local de consumo e local de entrada do acabado.
2. Concluido: implementar regra historica `05 -> 10`.
3. Concluido: criar sugestao de local final por produto/familia.
4. Concluido: bloquear conclusao quando o destino do acabado for incerto.
5. Concluido: registrar divergencias entre regra sugerida e historico real.

Regra inicial aplicada no app: produtos historicos como `575-0863` em OP local `05` sugerem entrada do acabado no local `10`, mantendo consumo dos componentes no armazem real do componente. Locais especiais sem regra operacional (`02`, `08`, `11`, `12`) bloqueiam a conclusao local ate comparacao com historico oficial.

Observacao permanente: o VettiFlow apenas calcula, exibe e bloqueia localmente. Nenhuma rotina, configuracao ou tabela do Protheus e alterada.

## Sprint 4 - Transferencias entre setores

Status: concluida.

1. Concluido: criar modulo read-only de transferencias.
2. Concluido: ler movimentos `RE4/999` e `DE4/499`.
3. Concluido: modelar origem, destino, produto, quantidade, documento e status.
4. Concluido: cobrir fluxos fortes observados: `01 -> 10`, `05 -> 10`, `70 -> 01`, `70 -> 05`; `01 -> 05` e `01 -> 70` ficam no radar para ampliar amostra.
5. Concluido: separar transferencia de baixa de OP, mantendo `RE4/DE4` fora do fluxo `PR0/RE1`.

Evidencia real read-only: consulta `GET /api/v1/transferencias` sobre filial `04` retornou transferencias pareadas `Q0000049I` `550-0845` `70 -> 05`, `Q00000499` `300-072` `70 -> 01`, `016226062` `460-015` `01 -> 10`, `016226061` `103-071` `05 -> 10` e `016226061` `103-073` `05 -> 10`, sem divergencias no par `RE4/DE4`.

## Sprint 5 - Desmontagem

Status: concluida.

1. Concluido: criar modulo de desmontagem separado do kanban de OP.
2. Concluido: ler movimentos `RE7/999` e `DE7/499`.
3. Concluido: mostrar produto origem, componentes retornados, locais e documento.
4. Concluido: validar fixtures reais disponiveis: `Q000003YV` e `DESMONT23`; `Q000004AV` nao possui linhas na `SD3` acessivel no recorte atual.
5. Concluido: preparar contrato read-only para mutacao futura via rotina oficial Protheus, sem escrita direta.

Escopo real desta sprint: mapa/read-only dos movimentos de desmontagem. Esta sprint nao afirma que a rotina oficial de desmontagem esta 100% modelada, porque ainda podem existir calculos de rateio, regras de custo, documentos auxiliares, movimentos adicionais ou parametros da rotina Protheus que nao aparecem apenas no par `RE7/DE7`.

Evidencia real read-only: consulta de desmontagem na filial `04` encontrou `Q000003YV` com origem `575-0888` no local `10` e 8 componentes retornados, e `DESMONT23` com origem `500-0907` no local `07` e 17 componentes retornados. A amostra recente tambem mostrou `DESMONT20`, `DESMONT22` e a divergencia `DES200325` como `sem_origem`, mantendo alerta quando existe `DE7` sem par `RE7`.

Pendencia conhecida para pesquisa futura: investigar manual/rotina oficial de desmontagem e rateio para entender se o calculo depende de custo medio, estrutura, saldo, valor dos componentes, quantidade, perda/sucata ou parametros especificos do Protheus. Enquanto isso, o VettiFlow usa desmontagem apenas como reconciliacao visual de historico, nao como calculadora oficial.

## Sprint 6 - Estorno, retorno e ajustes

Status: concluida.

1. Concluido: criar leitura de estornos `ER0/999` e retornos `DE1/499`.
2. Concluido: separar estorno de OP de devolucao manual `DE0/400`.
3. Concluido: separar requisicao manual `RE0/501`.
4. Concluido: mostrar auditoria por documento, OP, usuario, data, motivo, local, produto, quantidade e sequencia.
5. Concluido: manter qualquer escrita bloqueada; a sprint cria apenas endpoint `GET` e consulta `SELECT`.

Escopo real desta sprint: mapa/read-only de movimentos especiais de estoque. Esta sprint nao afirma que toda regra oficial de estorno, retorno ou ajuste esta fechada, porque podem existir parametros, aprovacoes, motivo codificado, rotina origem, tabelas auxiliares ou regras de contabilizacao/custo fora da `SD3`.

Evidencia real read-only: consulta na filial `04` retornou `ER0/999` de estorno de OP no documento `016234010`, retornos `DE1/499` da mesma OP `01623401001`, devolucoes manuais `DE0/400` como `Q0000048X`, `Q00000477` e `Q00000467`, e requisicoes manuais `RE0/501` como `Q0000045Y`, `Q00000455`, `Q00000449` e `Q0000042U`.

Pendencia conhecida para pesquisa futura: traduzir codigos de motivo como `056` e `051`, confirmar se `D3_USUARIO` e o usuario final oficial em todos os cenarios, e mapear se ha workflow/aprovacao/tabela auxiliar para justificar cada estorno, devolucao manual ou requisicao manual.

## Sprint 7 - Apontamento oficial

Status: concluida.

1. Concluido parcialmente: mapear rotinas candidatas (`MATA250`, `MATA680`, `MATA681`) sem afirmar qual e a rotina oficial da Vetti.
2. Concluido parcialmente: criar contrato de payload/previa com quantidade boa; perda, ganho e campos obrigatorios ficam como pendencia de pesquisa.
3. Concluido: simular `PR0/001` e `RE1/999` antes de qualquer envio.
4. Concluido: remover escopo de escrita/teste em HML desta fase; o VettiFlow segue sem mover nada no Protheus.
5. Concluido parcialmente: reconciliar leitura de `SC2`, `SD4`, `SD3` e `SB2` para pre-checagem; reconciliacao pos-apontamento fica para projeto futuro de escrita oficial.

Escopo real desta sprint: previa read-only de apontamento. Esta sprint nao fecha a rotina oficial, nao envia payload, nao testa `MSExecAuto` e nao grava apontamento no HML. Ela mostra o que o VettiFlow espera que aconteca: entrada `PR0/001` do acabado, baixas `RE1/999` dos componentes, quantidade restante, saldos por componente e alertas.

Evidencia real read-only: OP `01621401001` retornou previsao de apontar `50` unidades restantes, entrada prevista `PR0/001` do produto `575-0863` no local `10`, baixas previstas `RE1/999` no local `05`, documento de referencia `016214010`, e alertas de saldo insuficiente para componentes MOD com saldo negativo na `SB2`.

Pendencia conhecida para pesquisa futura: confirmar qual rotina oficial a Vetti usa, quais campos de perda/ganho/encerramento sao obrigatorios, como a rotina trata apontamento parcial e se ha customizacao Protheus que altera o comportamento padrao.

## Sprint 8 - Governanca de escrita futura

Status: concluida.

1. Concluido: criar endpoint `GET /api/v1/write-readiness` para declarar explicitamente que o VettiFlow esta em modo somente leitura.
2. Concluido: mostrar no app a tela `Governanca Protheus`, com `readOnly=true`, `writeEnabled=false` e status `bloqueada_por_politica`.
3. Concluido: listar operacoes bloqueadas: abertura de OP, apontamento de OP, transferencia, desmontagem, `sql_direto` e configuracao Protheus.
4. Concluido: transformar wrapper `MSExecAuto`/API oficial em requisito futuro de projeto separado, sem qualquer implementacao de escrita nesta base.
5. Concluido: manter rotinas candidatas (`MATA250`, `MATA680`, `MATA681`) como mapa de pesquisa, sem afirmar payload oficial.

Escopo real desta sprint: governanca e bloqueio visivel de escrita. Esta sprint nao cria wrapper ADVPL, nao chama rotina oficial, nao envia abertura, apontamento, transferencia ou desmontagem, e nao faz teste de escrita em HML. O VettiFlow apenas informa o estado de seguranca e centraliza as pendencias para uma eventual frente futura.

Evidencia real read-only: `write_readiness()` valida a conexao atual por `health()` e retorna `database=HMLp12`, `readOnly=true`, `writeEnabled=false`, `status=bloqueada_por_politica`, operacoes bloqueadas e requisitos futuros. A unica consulta ao Protheus nessa validacao e `SELECT DB_NAME(), @@SERVERNAME`.

Pendencia conhecida para pesquisa futura: caso exista um projeto separado de escrita, ele deve validar rotina oficial, permissoes, numeracao, locks, rateios, custos, perda/ganho, payload obrigatorio, reconciliacao `SC2`/`SD3`/`SD4`/`SB2` e rollback operacional antes de qualquer homologacao. Escrita direta por SQL continua proibida permanentemente.

## Regra permanente

SQL Server Protheus e fonte de leitura e reconciliacao. O VettiFlow nao move um dedo dentro do Protheus: nao muda configuracao, nao insere, nao atualiza e nao exclui. Qualquer escrita de negocio futura so pode existir como projeto separado, via rotina oficial Protheus validada em HML, nunca por `INSERT` direto nas tabelas nativas.
