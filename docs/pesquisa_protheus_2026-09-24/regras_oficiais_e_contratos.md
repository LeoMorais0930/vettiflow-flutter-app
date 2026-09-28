# Regras oficiais e dados de integração do Protheus para o VettiFlow

Pesquisa realizada em 24/09/2026. Escopo: processos observados na auditoria dos últimos três meses, tutorial de desmontagem fornecido pelo usuário, documentação oficial TOTVS e consultas adicionais SELECT ao HMLp12, empresa 010, filial 04. Não foi executada rotina de negócio, envio, homologação de escrita ou alteração de configuração.

## Conclusão

O rateio da desmontagem é padrão oficial do Protheus. O campo D3_RATEIO distribui o custo da origem entre os destinos e a soma deve fechar em 100%. A documentação oficial também oferece execução automática da MATA242. É possível pesquisar as regras e os contratos técnicos sem consultar repetidamente o gestor; decisões de custo e processo específicas da empresa continuam distintas das regras do produto. [TOTVS — regra de rateio](https://centraldeatendimento.totvs.com/hc/pt-br/articles/23608602938519-Cross-Segmento-Backoffice-Linha-Protheus-SIGAEST-MATA242-Campo-D3-RATEIO-qual-c%C3%A1lculo-efetuar-para-produtos-com-estrutura), [TOTVS — integração MATA242](https://tdn.totvs.com/pages/releaseview.action?pageId=393362555).

Este documento é um mapa de integração pesquisado, não um conjunto de payloads já homologados. As listas abaixo indicam dados de negócio e campos documentados; a obrigatoriedade completa depende do dicionário ativo, versão, parâmetros, produto, módulo e customizações da instalação. Um exemplo de ExecAuto publicado pela TOTVS não comprova que exista hoje um endpoint REST correspondente no servidor da Vetti.

## Conferência do tutorial do gestor

Fonte local: `C:/Users/Leonardo Morais/Desktop/Guia_Desmontagem_Vetti 1.docx`, versão 1.0, datada internamente de 29/06/2026. Texto e tabelas foram extraídos, e as oito imagens foram inspecionadas; são elementos de identidade visual, sem capturas de campos operacionais. O documento foi tratado como referência de procedimento, não como instrução para executar operações.

| Afirmação do tutorial | Resultado da conferência | Consequência para o VettiFlow |
|---|---|---|
| Desmontagem é MATA242 | Confirmada pela TOTVS | Usar essa família de operação para desmontagem |
| Origem, armazém, quantidade, documento e destinos | Compatível com procedimento e ExecAuto oficiais | Reunir cabeçalho e itens; incluir rastreabilidade quando aplicável |
| Componentes podem vir do primeiro nível da estrutura | Confirmado; estrutura não é obrigatória | Estrutura pode sugerir itens, sem impedir destinos informados manualmente |
| Percentuais devem somar 100% | Confirmado | Validar soma decimal exata antes de qualquer envio futuro |
| Percentuais são informados manualmente na tela padrão | Confirmado | Uma integração pode fornecê-los, mas precisa definir como calculá-los |
| RE7 significa recebimento | Incorreto | RE7 é a requisição/saída da origem; DE7 é devolução/entrada dos destinos |
| Ajustar o último item resolve diferença de rateio | Apenas para resíduo de arredondamento | Não esconder diferença econômica relevante como ajuste de centavos |
| O exemplo gera dois componentes | Erro editorial: a tabela apresenta três | O cálculo do exemplo, 60% + 30% + 10%, está correto |

Fontes para o procedimento, preenchimento manual e mínimo exemplificado de 0,01%: [TOTVS — processo MATA242](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360061648474-Cross-Segmento-Backoffice-Linha-Protheus-SIGAEST-MATA242-Processo-de-Desmontagem-de-Produtos). Para estrutura opcional e sentido de requisição/devolução: [TOTVS — procedimento com e sem estrutura](https://tdn.totvs.com/pages/viewpage.action?pageId=235592716). A consulta direta desta última página retornou 403; o conteúdo foi consultado pelo resultado indexado oficial, compatível com a página atual da Central de Atendimento.

Os identificadores de help MA242PR/A242RATEIO citados no tutorial não foram validados textualmente nesta pesquisa; não serão usados como contrato fixo de erro. A mensagem retornada pela rotina e a versão instalada devem orientar o tratamento.

## Rateio de custo e limite da fórmula

O tutorial calcula:

`percentual_i = 100 × (custo_médio_i × quantidade_destino_i) / (custo_médio_origem × quantidade_origem)`

Como identidade matemática, a soma desses percentuais só resulta em 100 quando a soma dos custos de referência dos destinos iguala o custo total da origem. O exemplo do tutorial satisfaz essa condição. A TOTVS apresenta um exemplo baseado em custos médios que também fecha 100%; ele não demonstra uma política universal para diferenças entre custo do acabado, dos componentes e da transformação. [TOTVS — exemplo de cálculo](https://centraldeatendimento.totvs.com/hc/pt-br/articles/23608602938519-Cross-Segmento-Backoffice-Linha-Protheus-SIGAEST-MATA242-Campo-D3-RATEIO-qual-c%C3%A1lculo-efetuar-para-produtos-com-estrutura).

Exemplo matemático de limite, não dado da Vetti: origem de R$ 500 e componentes de referência somando R$ 400 produzem 80%. Os 20 pontos restantes não são arredondamento. Da mesma forma, custos de referência somando R$ 600 produzem 120%. Não se deve completar ou retirar essa diferença silenciosamente de um item.

Para uma política proporcional aos valores dos destinos, uma alternativa matemática seria usar `peso_i = custo_referência_i × quantidade_i` e `percentual_i = 100 × peso_i / soma_dos_pesos`. Isso é uma **proposta de política**, não obrigação da TOTVS nem decisão aprovada para a Vetti. Ela redistribui o custo da origem e pode mudar o custo de entrada dos componentes. Se os pesos forem zero, inválidos ou indisponíveis, não há cálculo automático justificável por essa regra.

Depois de definidos os percentuais, a relação esperada é `custo_destino_i = custo_total_origem × percentual_i / 100`. A valorização final pertence ao Protheus e ao processo de custos; não é seguro reproduzi-la apenas com o saldo atual SB2. O próprio procedimento oficial ressalva a dependência do recálculo do custo médio. [TOTVS — custo da desmontagem](https://tdn.totvs.com/pages/viewpage.action?pageId=235592716).

### Confirmação no banco dev

Consulta completa dos RE7/DE7 não excluídos de 24/06 a 24/09/2026, filial 04. Valores abaixo são D3_CUSTO1 registrados no banco consultado, não uma reconstrução do custo médio vigente na data original. Somente as linhas DE7 entram na soma percentual; a origem RE7 também contém 100 e não deve ser somada novamente.

| Documento | Destinos DE7 | Soma dos rateios dos destinos | Custo da origem | Soma dos custos dos destinos |
|---|---:|---:|---:|---:|
| Q000003YV | 8 | 100,00% | 6.630,830675 | 6.630,830675 |
| Q000004AV | 3 | 100,00% | 349,407450 | 349,407450 |
| Q000004C1 | 2 | 100,00% | 4.003,654252 | 4.003,654252 |
| Q000004C2 | 2 | 100,00% | 4.793,473311 | 4.793,473311 |
| Q000004C3 | 3 | 100,00% | 4.082,484689 | 4.082,484689 |

Q000004C3 usa 33,33%, 33,33% e 33,34%: exemplo real do ajuste de uma centésima de ponto percentual. Q000003YV inclui dois destinos com código MOD; Q000004AV inclui um. Isso confirma participação desses códigos no histórico, mas não autoriza tratar mão de obra como componente físico recuperável em qualquer desmontagem. O critério operacional deve distinguir itens físicos de itens de custo.

A disponibilidade atual de Q000004AV atualiza a limitação registrada na documentação antiga, que não o encontrara no recorte então acessível. Dados atuais: [evidência e SQL executado](https://github.com/LeoMorais0930/vettiflow-flutter-app/blob/8329fe3a23a2b12d98d63ab71ad405469b124a0b/docs/pesquisa_protheus_2026-09-24/evidencia_dev_rateio_config.json).

## Como entregar cada processo ao Protheus

O desenho recomendado é transmitir uma intenção de negócio ao serviço Protheus, que executa a rotina apropriada. Os movimentos SD3, saldos e empenhos são efeitos a conferir após a rotina, e não um lote de INSERTs a ser fabricado pelo VettiFlow. A identificação dos setores 01/03/04/05/06/07/10 é da Vetti; a documentação pública define operações, não uma rotina universal chamada “SMD” ou “Suporte”.

### Criar ou modificar OP

Rotina documentada: **MATA650**. Preparar produto, quantidade, identificação da ordem, datas de emissão/início/entrega e os dados adicionais de local/revisão/tipo exigidos pela instalação. O exemplo oficial usa C2_PRODUTO, C2_NUM, C2_QUANT, C2_EMISSAO, C2_DATPRI e C2_DATPRF. Explosão da estrutura e geração de empenhos/intermediários dependem da configuração. A documentação alerta que mudar C2_QUANT via ExecAuto não implica atualizar automaticamente empenhos e ordens intermediárias. Com AUTEXPLODE=N e MV_EXPLOPU=S, há requisito de C2_BATUSR. [TOTVS — MATA650](https://tdn.totvs.com/x/Q9vTJw).

Aplicação VettiFlow: produção, SMD e demais locais que realmente operam OP. Conferir o resultado em SC2/SD4 e preservar a chave completa, inclusive item de grade quando usado. Na leitura do dev, D3_OP tem 14 posições; não fixar onze caracteres porque as amostras mais comuns têm esse tamanho.

### Ajustar reserva de material

Rotinas: **MATA380/MATA381**. Informar OP, componente, local, quantidade original e saldo a empenhar, além de lote/endereço/série quando aplicável. É ajuste de compromisso de material, separado da movimentação física. A TOTVS distingue o total previsto D4_QTDEORI do saldo D4_QUANT descontado do já requisitado. Alteração de lote via ExecAuto tem orientação específica para MATA381. [TOTVS — ajuste de empenhos](https://tdn.totvs.com/display/PROT/MATA380%2B-%2BAjuste%2Bde%2BEmpenhos), [TOTVS — quantidades original e restante](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360028853812-Manufatura-Linha-Protheus-SIGAPCP-Altera%C3%A7%C3%A3o-da-quantidade-empenhada).

Aplicação VettiFlow: separar “material reservado”, “material transferido” e “material consumido”. Não baixar novamente componentes que a rotina de produção já requisitar automaticamente.

### Apontar produção simples

Rotina: **MATA250**, se esse for o modelo efetivamente utilizado. Preparar OP, TM de produção autorizado, quantidade boa, local de entrada, data, parcial/total e dados de perda/ganho/rastreabilidade aplicáveis. Campos documentados incluem D3_OP, D3_TM, D3_QUANT, D3_PERDA e D3_PARCTOT. A rotina possui opções de inclusão, estorno e encerramento; parâmetros como ATUEMP, ABREOP e PENDENTE alteram o comportamento e não devem ser escolhidos implicitamente. [TOTVS — ExecAuto MATA250](https://tdn.totvs.com/pages/viewpage.action?pageId=337347932).

No modelo simples, a entrada em estoque ocorre por apontamento. Concluir firmware, solda, teste e fechamento no aplicativo não deve produzir o mesmo acabado quatro vezes. A correspondência dessas etapas com o evento oficial precisa ser definida. [TOTVS — momento da entrada de produção](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360041124314-Manufatura-Linha-Protheus-SIGAPCP-Quando-ocorre-a-entrada-em-estoque-do-produto-produzido).

Aplicação VettiFlow: preservar separadamente local da OP, local dos componentes e entrada do acabado; os caminhos 05→10 e entradas no suporte já foram observados. O histórico PR0/RE1 isolado não identifica com certeza qual rotina produziu os registros.

### Apontar operação, recurso e duração

Rotinas alternativas: **MATA680/MATA681**. MATA681 trabalha com roteiro, operações, recursos e duração; MATA680 aproveita operações alocadas pela carga máquina. São diferentes de produção simples. [TOTVS — diferenças entre os modelos](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360028693311-Manufatura-Linha-Protheus-SIGAPCP-Diferen%C3%A7as-nas-rotinas-de-apontamento-do-MATA250-MATA680-e-MATA681).

O exemplo oficial de MATA681 inclui H6_OP, H6_PRODUTO, H6_OPERAC, H6_RECURSO, datas/horários, H6_LOCAL, H6_QTDPROD e H6_PT; estorno precisa identificar o apontamento original. [TOTVS — ExecAuto MATA681](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360022717031-Cross-Segmento-TOTVS-Backoffice-Linha-Protheus-ADVPL-Exemplo-execauto-MATA681-para-inclus%C3%A3o-e-estorno).

Não foi localizado SH6010 na listagem de tabelas/views acessíveis do dev, apenas SH6010_TTAT_LOG. Isso limita a confirmação e não prova que MATA680/681 nunca sejam usadas. A TOTVS informa que ambos os modelos podem gerar SD3, enquanto apontamentos de operações ficam em SH6. [TOTVS — SD3 versus SH6](https://centraldeatendimento.totvs.com/hc/pt-br/articles/4414744933911-Manufatura-Linha-Protheus-SIGAPCP-Diferen%C3%A7as-entre-as-tabelas-SD3-e-a-SH6).

### Perda, ganho, encerramento e estorno de produção

Perda de produção não é automaticamente ajuste genérico de estoque. Preparar quantidade e classificação/motivo de perda, refugo e destinos quando aplicáveis à rotina escolhida. Há configuração MV_DIGIPER, e a TOTVS registra que a consistência entre a classificação detalhada e o total da perda não é validada em todos os casos pelo padrão. [TOTVS — validação das perdas](https://centraldeatendimento.totvs.com/hc/pt-br/articles/4403947564567-Manufatura-Linha-Protheus-SIGAPCP-Valida%C3%A7%C3%A3o-da-quantidade-apontada-como-perda-pelas-rotinas-de-produ%C3%A7%C3%A3o).

Ganho e produção acima da ordem dependem de MV_GANHOPR/MV_PERCPRM; não presumir que toda quantidade excedente seja aceita. [TOTVS — ganho e produção a maior](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360026020913-Manufatura-Linha-Protheus-SIGAPCP-Quais-s%C3%A3o-os-par%C3%A2metros-referente-ao-ganho-de-produ%C3%A7%C3%A3o-e-produ%C3%A7%C3%A3o-a-maior).

Encerramento de OP parcial deve seguir a rotina do apontamento original. Há bloqueios para requisições sem produção e requisições posteriores ao último apontamento. [TOTVS — encerramento parcial](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360024734631-Manufatura-Linha-Protheus-SIGAPCP-Encerrar-ordem-de-produ%C3%A7%C3%A3o-apontada-parcialmente).

Para estornar, o serviço deve resolver uma referência inequívoca do evento original, não apenas o número da OP. A documentação de MATA250 exige posicionamento/identificação do registro; múltiplos apontamentos exigem selecionar qual será revertido. ER0/DE1 são efeitos a reconciliar, não instruções para apagar PR0/RE1. [TOTVS — identificação do estorno](https://tdn.totvs.com/pages/viewpage.action?pageId=337347932).

### Transferir entre locais ou códigos de produto

Rotina com integração documentada: **MATA261**. Preparar documento/data e pares contendo produto, unidade, armazém e endereço de origem e destino, quantidade e dados de lote/série/segunda unidade quando usados. O exemplo oficial possui campos de produto próprios para os dois lados. Como os nomes se repetem no array ADVPL, convertê-lo em um único objeto de chave D3_COD perde informação; o contrato do VettiFlow deve ter objetos origem e destino separados. [TOTVS — ExecAuto MATA261](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360022885712-Cross-Segmento-Backoffice-Linha-Protheus-ADVPL-Exemplo-execauto-MATA261).

Aplicação VettiFlow: os 11 pares com alteração de código encontrados no dev não devem ser descartados por divergirem no produto. Preserve D3_NUMSEQ e ambos os lados. Troca de código, conversão de unidade e desmontagem não são intercambiáveis automaticamente; os exemplos de integração não demonstram a rotina específica usada em cada movimento histórico da Vetti.

### Ajustar estoque ou requisitar/devolver material

Rotinas: **MATA240/MATA241**. No exemplo oficial de MATA241, o cabeçalho contém D3_DOC, D3_TM, D3_CC e D3_EMISSAO; itens contêm produto, unidade, quantidade, local e rastreabilidade. MATA241 reúne itens sob contexto comum e possui regras próprias de estorno. [TOTVS — movimentos internos modelo 2](https://tdn.totvs.com/display/PROT/Movimentos%2BInternos%2BModelo%2B2%2B-%2BMATA241%2B-%2BEstoque%2B-%2BP12).

No cadastro observado, TM400 é entrada para ajuste e TM501 é saída para ajuste. Esses códigos são da configuração Vetti, não números universais a transportar para qualquer instalação. Vincular a OP quando for requisição/devolução de produção e não usar ajuste genérico para simular transferência, desmontagem ou nota fiscal. Motivos, conta e centro de custo precisam seguir o processo configurado.

### Desmontar produto

Rotina: **MATA242**, execução automática com cabeçalho e itens. O cabeçalho documentado contém cProduto, cLocOrig, nQtdOrig e cDocumento, além de localização, lote, validade, série e segunda unidade. Os destinos usam D3_COD, D3_LOCAL, D3_QUANT, D3_QTSEGUM e D3_RATEIO. A ordem dos campos do cabeçalho e o módulo EST são relevantes na documentação oficial. [TOTVS — contrato ExecAuto MATA242](https://tdn.totvs.com/pages/releaseview.action?pageId=393362555).

Proposta de contrato de negócio do VettiFlow, ainda não implementado: empresa/filial/data; identificação idempotente da solicitação; origem com produto/local/quantidade e controles; lista de destinos com produto/local/quantidade e percentual; identificação da política de rateio; referências dos custos usados na prévia. A data deve ser tratada no contexto correto da rotina; não inventar um campo de cabeçalho que o ExecAuto não documenta.

Validações propostas com base no dev: trabalhar com decimal; considerar duas casas em D3_RATEIO; exigir percentual positivo por destino e soma 100,00; resolver apenas resíduo de precisão conforme política explícita; exibir divergência de custo separadamente. Não aplicar automaticamente a fórmula proporcional aos custos quando o denominador for zero ou quando a política não estiver definida. Depois da rotina, reconciliar RE7/DE7, percentuais, quantidades, locais e custo; o cálculo final continua no Protheus.

### Receber compra, devolução ou retorno por documento

Rotina documentada: **MATA103**. A integração recebe cabeçalho e itens; no cabeçalho há identificação/tipo/série do documento, datas, contraparte/loja e demais dados comerciais. Itens precisam de produto, quantidade, local e classificação TES, valores e referências exigidas para o processo. A execução automática tem opções e arrays auxiliares próprios, inclusive perguntes e rateios. [TOTVS — ExecAuto de documento de entrada](https://tdn.totvs.com/pages/viewpage.action?pageId=235592777).

Aplicação VettiFlow: compras, importações, devoluções e recebimento de bens para conserto não devem ser enviados como simples DE0. Para representar processos fiscais, usar a classificação já validada no ERP; não deduzir TES universal a partir do nome “suporte” ou do local 06/07. Integração de recebimento deve distinguir confirmação operacional do evento fiscal que já possa ter sido lançado.

### Expedir, vender e emitir remessa/retorno

Separação física, pedido e documento de saída são eventos distintos. Para saída a partir de pedido, a TOTVS documenta **MaPvlNfs**, no contexto de preparação MATA461, com itens do pedido liberados e série. A função **não verifica por si só bloqueios de estoque/crédito SC9**; a integração precisa fazê-lo. Para geração a partir de documento de origem existe MANFS2NFS, outro contrato. [TOTVS — geração a partir de pedido](https://tdn.totvs.com/pages/viewpage.action?pageId=578374528), [TOTVS — opções de preparação de saída](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360000583388-Cross-Segmentos-TOTVS-Backoffice-Linha-Protheus-SIGAFAT-Como-utilizo-ExecAuto-para-prepara%C3%A7%C3%A3o-da-nota-de-sa%C3%ADda).

Aplicação VettiFlow: reunir referências oficiais do pedido/item/liberação, quantidade autorizada, série, destinatário e classificação já configurada; não fabricar um SD2 como baixa de estoque. Definir se o app apenas solicita/libera a expedição ou participa do faturamento. A existência dessa documentação não comprova um serviço instalado nem que gerar o documento interno conclua todas as etapas de autorização fiscal.

### Suporte, garantia, conserto e industrialização em terceiros

Esses processos combinam movimentos e documentos; não há evidência de que uma única rotina de suporte cubra todos os casos. Material próprio em terceiros e material de terceiros na Vetti precisam de identificação de contraparte, documento/item de remessa original, quantidade retornada e TES compatível. A TOTVS diferencia controle de poder de terceiros e movimentação de estoque; são dimensões configuráveis. [TOTVS — controle de poder de terceiros](https://tdn.totvs.com/display/PROT/Controle%2Bde%2BPoder%2Bde%2BTerceiros), [TOTVS — beneficiamento](https://tdn.totvs.com/pages/viewpage.action?pageId=240980472).

MV_CONTERC/F4_CONTERC tratam o controle adicional de armazém de terceiros; esse recurso não se confunde com todo o controle de poder de terceiros. [TOTVS — armazém de terceiros](https://tdn.totvs.com/pages/viewpage.action?pageId=271395422). No dev, MV_CONTERC=F e MV_ALMTERC vazio para filial 04: não concluir disso que inexista remessa, assistência ou estoque de terceiros. Os locais 70/72 observados tampouco provam que essa automatização esteja ativada.

Não foi identificada e homologada uma rotina de ordem de serviço de assistência para a Vetti. Garantia, diagnóstico, cobrança de serviço e decisão de recuperação são lacunas operacionais; entradas/saídas e transferências já têm famílias documentadas para pesquisa e integração.

## Configuração obtida sem perguntar ao gestor

Foram consultadas SX3010 e SX6010 no dev, além de SD3. As tabelas existem, mas o vínculo com o dicionário e ambiente carregados pelo AppServer não foi verificado; estes são valores encontrados em banco, não prova de configuração efetiva em execução.

| Item | Valor encontrado | Utilidade |
|---|---|---|
| D3_RATEIO | Tamanho 6, duas casas; validação `M->D3_RATEIO > 0` | Define precisão observada e restrição positiva |
| D3_QUANT | Tamanho 14, duas casas | Evita assumir quantidades inteiras para todos os itens |
| D3_DOC / D3_COD / D3_OP | 9 / 30 / 14 posições | Contratos não devem copiar tamanhos de exemplos genéricos |
| MV_ESTNEG, filial 04 | N | Restrição de saldo negativo encontrada; regras adicionais ainda podem existir |
| MV_EXPLOPU, filial 04 | S | Relevante para explosão de OP conforme contrato MATA650 |
| MV_CUSFIL / MV_CUSMED, filial 04 | A / M | Valores preservados como evidência; não foi reconstruído o cálculo de custo |
| MV_AGCUSTO, registro compartilhado | .F. | Parâmetro de custos encontrado |
| MV_CONTERC / MV_ALMTERC, filial 04 | F / vazio | Configuração do controle adicional de armazém de terceiros |

Os SELECTs e demais valores estão em [evidencia_dev_rateio_config.json](https://github.com/LeoMorais0930/vettiflow-flutter-app/blob/8329fe3a23a2b12d98d63ab71ad405469b124a0b/docs/pesquisa_protheus_2026-09-24/evidencia_dev_rateio_config.json). Não foram lidos nem exportados parâmetros de credenciais. A evidência do trimestre continua em [auditoria de movimentos](../auditorias/2026-09-24/relatorio.md).

## O que já está resolvido e o que depende da instalação

| Camada | Situação | Como resolver o restante |
|---|---|---|
| Regra padrão da desmontagem | Confirmada: MATA242, rateio e contrato automático | Documentação TOTVS e reconciliação com casos reais |
| Famílias de OP, empenho, produção, transferência, ajuste e documentos | Caminhos oficiais identificados | Conferir versão e contrato de cada rotina no ambiente |
| Critério de rateio da Vetti | Ainda não definido para divergências de custo, MOD e sucata | Recuperar política existente; decisão única do responsável de custos se não documentada |
| Rotina produtiva efetivamente adotada e relação com as etapas do app | Ainda não comprovada por SD3 | Inspecionar configuração, menu/logs e customizações do AppServer |
| Contratos finais executáveis | Não homologados; nenhum envio realizado | Projeto específico de integração oficial, com parâmetros, autenticação, autorização, idempotência e reconciliação |

Prioridade proposta: consolidar catálogo de operações e validar a leitura de rateio/troca de produto primeiro; depois fechar contratos com a configuração efetiva. O gestor só precisa decidir questões de negócio que não estejam documentadas ou dedutíveis dos registros. Não é necessário pedir que ele explique regras padrão já publicadas pela TOTVS.

## Limites da pesquisa

As fontes externas utilizadas para conclusões são da TOTVS. Algumas páginas TDN foram acessíveis apenas pelo conteúdo indexado, e diversos exemplos são antigos apesar de continuarem publicados. Não foram verificados release, patch, RPO, pontos de entrada instalados, permissões do usuário de integração ou serviços REST disponíveis. O tutorial auxilia a identificar a rotina de desmontagem, mas não comprova ausência de customização. Consequentemente, este levantamento fundamenta os contratos e reduz perguntas operacionais, sem afirmar prontidão para escrita no Protheus.
