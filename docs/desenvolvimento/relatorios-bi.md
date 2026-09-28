# Relatórios por setor e gestão

Pesquisa e proposta de implementação — 24/09/2026.

**Estado: modelo de movimentações disponível para almoxarifado, SMD, produção, suporte, expedição e gestão.** As rotas `/{setor}/relatorios` reutilizam filtros, prévia, resumo do recorte completo, evolução, ranking por produto/unidade/armazém e PDF com detalhamento opcional. Os modelos específicos de estoque, OPs, inventário e logística continuam como proposta. Consulte a [verificação da base](https://github.com/LeoMorais0930/vettiflow-flutter-app/blob/8329fe3a23a2b12d98d63ab71ad405469b124a0b/docs/testing/relatorios-almoxarifado.tdd.md) e a [ampliação por setor](https://github.com/LeoMorais0930/vettiflow-flutter-app/blob/8329fe3a23a2b12d98d63ab71ad405469b124a0b/docs/testing/relatorios-setores.md).

Nesta primeira versão, os filtros salvos, a comparação entre períodos, o cache de relatórios e a autorização individual no servidor ainda não foram implementados. A API limita os armazéns conforme o setor e mantém a filial configurada, com a mesma proteção HTTP de leitura já usada no ambiente local. O consolidado da gestão usa locais físicos distintos; a visão da produção inclui SD3 vinculado às OPs do 05. O acesso à tela consolidada segue a conta de gestão geral no Flutter; isso não substitui autorização individual no servidor.

**Produção ampliada:** a fonte VettiFlow oferece tempos por etapa, sessões de operadores, pausas e qualidade usando a lógica local já existente; a fonte Protheus oferece quantidade apontada, OPs com apontamento, evolução e destino. Filtros e PDFs identificam a origem. [Regras de produtividade](../setores/producao/README.md#produtividade-e-operação).

## Experiência proposta

Cada setor terá um botão **Relatórios**, mantendo o padrão visual do VettiFlow. Ele abrirá a mesma estrutura, com modelos e filtros próprios do setor. O painel de gestão terá acesso aos setores permitidos e à visão consolidada.

Fluxo: **escolher o relatório → ajustar filtros → analisar a prévia → gerar PDF**.

A análise interativa fica no aplicativo: filtros, indicadores, gráficos e abertura dos registros que explicam um total. O PDF registra o resultado escolhido, com tabelas paginadas, filtros e data da consulta. Alterar o recorte significa voltar ao aplicativo e gerar uma nova versão.

O usuário poderá escolher resumo, gráficos e detalhamento, além de salvar combinações de filtros. Preferências locais devem ser identificadas como deste dispositivo enquanto não houver persistência compartilhada. Um filtro não aplicável ao modelo desaparece; não fica selecionado sem efeito.

Exemplo de uso: **SMD → Apontamentos → setembro/2026 → usuário paulad → agrupar por produto e OP → comparar com o mês anterior → gerar PDF**. Isso consulta o usuário gravado no movimento; não transforma consumo automático em trabalho manual atribuído à Paula.

## Modelos de cada setor

| Entrada | Modelos e conteúdo | Recorte |
|---|---|---|
| Almoxarifado | Movimentações; transferências; OPs; estoque atual; contagens de inventário | 01 |
| SMD | Apontamentos por OP/produto; consumo e devolução de componentes; OPs; movimentos; estoque atual | 03; vínculo de OP consultável no detalhe |
| Produção | Apontamentos e consumo das OPs; destinos do acabado; movimentos; OPs; estoque atual | Histórico físico do 05 e SD3 vinculado a OPs do 05; mostrar o local efetivo |
| Suporte | Movimentos e transferências; notas de remessa/retorno; OPs; estoque atual; inventário | 06 e/ou 07 |
| Expedição | Entradas e saídas; notas por natureza; pedidos identificados nos itens; transporte e preenchimento de rastreio; OPs; estoque atual | 10 |
| Gestão | Comparativos por setor, mês, produto e tipo de movimento; visão consolidada do ERP; relatório operacional local em seção própria | 01, 03, 05, 06, 07 e 10, conforme acesso |

Suporte não terá um indicador de “reparos concluídos” deduzido de transferências. Expedição não terá “entregas concluídas” deduzidas de notas ou transportadoras. Os documentos atuais não comprovam esses eventos.

O fluxo local acrescenta etapas, tempos, pausas, defeitos e conferência somente onde esses eventos existem. Deve aparecer como **VettiFlow · dados locais deste dispositivo** até haver uma base compartilhada. O PDF pode conter blocos locais e oficiais lado a lado, com identificação; não deve somá-los como uma produção única.

## Filtros

Na abertura, aproveitar o mês/período e o contexto da tela. Não herdar silenciosamente um filtro específico da aba anterior que torne o relatório incompleto. Mostrar os filtros aplicados antes de gerar.

| Grupo | Opções propostas | Disponibilidade |
|---|---|---|
| Período | Mês/ano, intervalo, todo o período | Histórico; OPs e inventário com suas datas próprias |
| Produto | Código, descrição, seleção de produtos, tipo, unidade | Cadastros descritivos atuais identificados como tais |
| Operação | Natureza, entrada/saída, CF, TM, situação de estorno | CF/TM/usuário são do SD3; TES/CFOP são fiscais |
| Vínculo | OP completa, documento, série, lote; origem/destino quando pareados | Somente campos presentes na fonte |
| Responsável | Login gravado no lançamento | SD3; notas não possuem esse campo no contrato atual |
| Fiscal | TES, CFOP, parceiro/loja, efeito em estoque conforme cadastro atual | SD1/SD2; sem tratar todo documento como venda |
| Expedição | Pedido/item, transportadora, rastreio informado/não informado | Exige ampliar a consulta de relatório; hoje transporte está no detalhe de uma nota |
| OP | Emitidas no período, encerradas no período, abertas agora; produto e situação | Modos separados; o endpoint atual filtra apenas emissão |
| Saldo atual | Com saldo, zerado, negativo; produto e armazém | SB2; sem filtro de mês |
| Gestão | Setores autorizados, agrupamento e comparação entre períodos | Escopo aplicado no servidor |
| Fluxo local | Etapa, operador, OP, produto, defeito e pausa | Dados locais, com data do evento correspondente |

Seleções múltiplas usam **OU** dentro do mesmo campo e **E** entre campos. “Não informado” deve ser uma opção explícita, distinta de “Todos”. Listas de opções precisam de busca e limites; não carregar todos os produtos/notas de uma vez.

Filtros avançados terão nomes simples, com os códigos do Protheus junto da descrição. Agrupamento por usuário representa a conta do sistema: `expedicao`, por exemplo, é uma conta compartilhada, não uma pessoa identificada.

## Regras dos números

1. **Registro, peça, OP, nota e pedido são medidas diferentes.** SD1/SD2 retornam itens; contar linhas não equivale a contar notas. A contagem de notas exige identidade fiscal completa, incluindo origem, empresa/filial, documento, série, parceiro/loja e tipo, validada para cada tabela. Uma nota com vários pedidos não pode atribuir todos os itens ao primeiro pedido do cabeçalho.
2. **Quantidades mantêm decimais e agrupam por produto e unidade.** Não somar placas, metros e componentes em um indicador genérico de “peças”. Custos, preços e faturamento também são medidas diferentes; o campo `cost` atual não é receita. Valores financeiros ficam fora da primeira versão até validar moeda, significado e acesso.
3. **Apontamento e consumo ficam separados.** Primeira versão: quantidades PR0 efetivas, ER0, RE1 e DE1 em medidas próprias, por produto/unidade; registros marcados como estornados em coluna separada. Um saldo líquido só entra depois de validar os pares e sinais, sem subtrair duas vezes um registro já estornado.
4. **Transferências mantêm os dois lados.** Uma saída e uma entrada não são duas transferências empresariais. Contar “transferências pareadas” apenas quando a relação for inequívoca, contando cada par uma vez. Casos sem par ou ambíguos aparecem separados. Há troca de código de produto e transferências dentro do mesmo armazém.
5. **Produção e expedição podem mostrar o mesmo registro.** Um PR0 no 10 vinculado à OP do 05 aparece nos dois contextos atuais. No consolidado, deduplicar por ambiente/empresa, tabela, filial e RECNO. A visão por local físico é aditiva; a visão por responsabilidade da OP tem sobreposição e deve declarar isso. O total geral não é a soma cega dos cartões dos setores.
6. **Nota fiscal não comprova saída de estoque.** Separar itens com TES atual S, N e desconhecida. O cadastro atual da TES não comprova sua configuração histórica. Não chamar todos os SD2 de vendas nem todos os SD1 de devoluções.
7. **SB2 é saldo atual.** O relatório mensal pode incluir um bloco opcional “Estoque consultado em...”, separado do movimento do mês. Saldo de fechamento histórico exigirá fonte e regra próprias; não reconstruir a partir de uma parte dos movimentos nem comparar saldo atual com a contagem antiga do SB7 como se fosse divergência na época.
8. **OP aberta agora não é OP aberta no fim daquele mês.** Planejado e produzido acumulado de SC2 são valores atuais. “Produção do mês” usa apontamentos do período; “OPs emitidas no mês” usa emissão; “encerradas no mês” exige filtro de encerramento. A carteira atual deve declarar sua data de consulta.
9. **Volumes são da nota inteira.** No recorte por produto/local, informar que o volume é do cabeçalho e contá-lo uma vez por nota, sem rateio inventado. Código de rastreio ausente não prova atraso ou falta de envio.
10. **Ausência de dados não é zero.** Consulta que falhou, fonte indisponível, vínculo ambíguo e quantidade desconhecida têm estados próprios. Dados removidos logicamente seguem excluídos das consultas operacionais; relatório de auditoria de exclusões seria outro escopo.

## Períodos e comparações

- SD3: data do movimento (`D3_EMISSAO`). SD1: digitação (`D1_DTDIGIT`), conforme a consulta atual. SD2: emissão (`D2_EMISSAO`). SB7: data da contagem. Cada seção identifica a data utilizada.
- Eventos locais usam sua própria data: conclusão da etapa, registro do defeito, pausa ou sessão. Filtrar só a criação da OP e depois somar todo o seu histórico não gera um relatório mensal correto.
- Mostrar separadamente o **último registro do recorte**, o **último registro nas tabelas do DEV consultadas** e a **hora da consulta**. O último registro global não prova atualização completa de todos os setores ou de todo o banco.
- Mês em andamento: comparar o período decorrido com o mesmo intervalo do mês anterior, ou meses completos quando explicitamente escolhido. As datas comparadas ficam visíveis; não extrapolar dias sem registro. O DEV pode estar desatualizado em relação à operação real.
- Variação percentual só tem valor quando a base anterior é válida e diferente de zero. Caso contrário, mostrar “Sem base para comparação”, junto dos valores absolutos. Comparação não se aplica a “Todo o período” sem um segundo intervalo explícito.

## O que torna o relatório útil

Resumo curto com indicadores definidos, evolução por dia/mês, distribuição por natureza e agrupamentos por produto/OP. Ao abrir um indicador no app, o usuário vê os registros que o compõem.

Observações automáticas serão calculadas por regras verificáveis: saldo atual negativo, movimento estornado, transferência sem par inequívoco, nota sem código de rastreio ou diferença entre dois períodos comparáveis. Cada observação mostra números e acesso aos registros. Não precisa de IA generativa para essa primeira versão; não afirmar causas, atrasos ou responsabilidade de uma pessoa a partir de ausência de dados.

PDF: identificação do setor/ambiente/período, filtros aplicados, resumo, gráficos selecionados, agrupamentos e anexo detalhado opcional. Rodapé com página, identificador do relatório, consulta e cobertura. Sem imprimir tokens, mensagens internas de conexão ou SQL. Tabelas longas repetem o cabeçalho; nomes e códigos extensos não podem ficar cortados.

## Implementação recomendada

**Uma base comum de relatórios, com modelos por setor.** Aproveitar o tema, o seletor de período e a navegação existentes. Evitar copiar seis geradores independentes ou usar captura de tela como PDF.

| Camada | Responsabilidade proposta |
|---|---|
| FastAPI | Validar filtros e escopo, consultar somente leitura, deduplicar, calcular totais/agrupamentos e devolver os dados do relatório |
| Modelo de relatório | Contrato versionado, filtros normalizados, fonte, unidade, cobertura, janela da consulta, métricas, séries, agrupamentos, detalhe e limitações |
| Flutter | Formulário comum, filtros próprios do modelo, prévia e abertura dos registros |
| PDF em Dart | Documento paginado a partir do mesmo resultado usado pela prévia |
| Impressão/visualização | Pacote `printing`, com suporte documentado a web, Windows e demais plataformas do app |

Os pacotes [`pdf`](https://pub.dev/packages/pdf) e [`printing`](https://pub.dev/packages/printing) são candidatos adequados: documento com texto, gráficos, fontes e múltiplas páginas; prévia, impressão e compartilhamento no Flutter. Validar as versões com o SDK do projeto na implementação. Empacotar logo/fontes e os recursos necessários à prévia web para não depender de uma consulta externa a cada relatório.

A distinção entre análise na tela e documento completo segue o conceito de [relatórios paginados documentado pela Microsoft](https://learn.microsoft.com/en-us/power-bi/paginated-reports/paginated-reports-report-builder-power-bi). Isso é referência de funcionamento, não uma dependência de Power BI para o VettiFlow.

O contrato deve ser independente do renderizador. Se no futuro houver relatórios grandes agendados, um gerador no servidor poderá consumir o mesmo modelo. Agendamento, envio de email, execução de ADVPL e escrita no Protheus não fazem parte desta proposta.

### Volume e consistência

- Agregados consultam todo o recorte no servidor, antes da paginação. Não gerar totais a partir das 50 linhas visíveis e não percorrer as páginas da UI para montar um relatório completo.
- Resumo de “Todo o período” continua disponível, sujeito ao tempo de consulta; detalhe tem orçamento explícito. Proposta inicial para validar em testes: até **1.000 linhas e 60 páginas** por PDF detalhado. Se exceder, oferecer resumo completo ou refinar o recorte; nunca exportar só as primeiras linhas sob o título “completo”. O usuário sabe antes o que estará no arquivo.
- Agrupamentos com muitos produtos usam ranking identificado e restante contabilizado no resumo; a tabela completa exige paginação própria. Um gráfico dos dez maiores não representa todos os produtos e deve dizer isso.
- Consulta por botão “Aplicar”, cancelamento de requisição obsoleta, timeout e cache por filtros normalizados/escopo. O cancelamento no cliente, sozinho, não garante cancelamento do SQL; o servidor precisa controlar a concorrência e o trabalho em execução. Os limites iniciais serão medidos no DEV sem mudar índices/configurações do Protheus.
- A prévia e o PDF consomem o mesmo resultado materializado da consulta, com identificador e horário. Se forem atualizados os dados, criar uma nova versão e atualizar a prévia. Cache e downloads não podem compartilhar dados entre escopos de acesso.
- Registrar início/fim da leitura. Várias consultas SQL não garantem automaticamente um retrato transacional único; isso depende do isolamento disponível e deve ser verificado sem alterar o banco. Não prometer um fechamento contábil imutável apenas por imprimir uma data no rodapé.

### Acesso

A interface já diferencia operadores, gestores de área e administração, mas a API atual usa token compartilhado. Para disponibilização real por conta/setor, a API precisa identificar o usuário e autorizar o recorte. Esconder o seletor na tela ou aceitar um nome de usuário enviado pelo navegador não substitui esse controle. A gestão geral acessa apenas o conjunto concedido; o gestor de um setor não ganha automaticamente todos os armazéns.

É possível validar o gerador no ambiente local de leitura. A distribuição com separação efetiva de dados entre contas depende dessa autorização no servidor.

## O que o código atual permite reaproveitar

- [Consulta comum](../../lib/ui/warehouse/warehouse_read_page.dart), [filtro de período](../../lib/ui/shared/widgets/read_period_filter.dart) e [repositório](../../lib/data/repositories/warehouse_read_repository.dart).
- [Leitura SQL](../../api/app/warehouse.py): campos e classificações já mapeados, filtros, agregação de contagens antes da paginação. Os filtros multidimensionais e agrupamentos desta proposta ainda exigem implementação.
- [Relatórios locais da gestão](../../lib/ui/dashboard/views/reports_view.dart): etapas, pausas, sessões, produtos e defeitos. Hoje são calculados sobre OPs do store local, sem filtro mensal; as listas visuais de pausas e operadores têm cortes. Exportar os widgets atuais não produziria um relatório completo.
- Antes de reutilizar os cálculos locais: respeitar a sequência planejada e sua etapa final; usar a data de cada evento; revisar a quantidade realmente inspecionada e a possível sobreposição dos tipos de defeito. Hoje o denominador usa a quantidade da OP e a produção aprovada depende de ter passado pelo fechamento. Não chamar esses resultados automaticamente de produtividade, rendimento ou taxa de peças defeituosas.
- [Arquitetura atual](arquitetura.md), [administração](../setores/administracao/README.md), [produção](../setores/producao/README.md) e [auditoria da expedição](../auditorias/2026-09-24/expedicao.md) documentam os limites de persistência, sobreposição e transporte usados neste desenho.

## Ordem de entrega

1. **Base e primeiro modelo — entregue:** relatório mensal de movimentos do almoxarifado, filtros aplicados, resumo completo, prévia e PDF, com contrato de métricas e testes. Mantidas as consultas existentes. Quantidades agrupadas por produto/unidade/natureza/sentido/estorno; ranking de até 100 grupos; evolução consultada de até 120 períodos e gráfico dos 24 mais recentes; detalhe completo até 1.000 linhas e PDF até 60 páginas. Os cortes de rankings são identificados, e não alteram os totais do recorte.
2. **Demais setores:** reutilizar essa base para apontamentos/consumo do SMD e produção, suporte, notas/transporte da expedição, OPs e estoque atual. Cada modelo recebe somente filtros e indicadores válidos para suas fontes.
3. **Gestão:** consolidado oficial sem duplicidade, comparação por mês e setor; relatório local identificado e com cálculos revisados. Consolidar eventos locais entre computadores somente depois da persistência compartilhada.
4. **Evolução:** filtros salvos por conta, exportações extensas em segundo plano, arquivo de versões e eventual conciliação entre eventos locais e documentos oficiais.

## Critérios de aceite

- Prévia e PDF apresentam os mesmos filtros, totais e fonte; totais conferem com consultas de referência no DEV.
- Mais de 100 registros não limitam os indicadores à primeira página. Exceder o orçamento do detalhe nunca provoca corte silencioso.
- Testar quantidade fracionada, unidades diferentes, zero/ausente, estorno, pareamento ambíguo, troca de produto e transferência no mesmo local.
- PR0 de OP 05 em local 10 entra uma vez no consolidado. Uma nota com vários itens/pedidos/locais não multiplica cabeçalhos ou volumes.
- Verificar mês sem dados, fevereiro, virada de ano, mês parcial, todo o período e fonte indisponível. OP antiga aberta não desaparece de um modelo “abertas agora”.
- Usuário de setor não consulta/exporta outro escopo; gestor de área e gestor geral têm escopos distintos no servidor.
- Verificar visualmente PDF curto e multipágina com acentos, códigos extensos, cabeçalhos repetidos e gráficos; testar prévia/download nas plataformas efetivamente usadas.
- Não alterar dados, fontes ADVPL, índices ou parâmetros do Protheus para habilitar o relatório.
