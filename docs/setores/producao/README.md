# Produção

O fluxo padrão é gravação → soldagem → teste → fechamento → expedição. A gestão pode ajustar as etapas planejadas de uma OP.

## Regra de negócio confirmada por Leonardo em 24/09/2026

Tatiane e Andressa abrem as OPs da produção, escolhem em qual etapa cada OP começa, quais etapas percorre e onde termina. O fluxo acima é apenas uma opção padrão, não uma sequência obrigatória.

As etapas internas são controladas pelo VettiFlow. Conforme a orientação do usuário, os movimentos oficiais devem ocorrer ao direcionar uma quantidade para suporte ou para expedição. Essa é a regra desejada para a integração; a escrita continua bloqueada. O histórico mostra tanto apontamentos com entrada direta no destino quanto transferências de produto já existente, portanto esses envios exigem contratos diferentes.

## Como usar agora

1. No painel de Tatiane ou Andressa, abra **Nova OP**. Para OPs da produção (05), **Etapas** permite marcar, retirar e reordenar os postos. A primeira etapa recebe a OP e a última define onde a sequência termina. Sem uma seleção específica, permanece o fluxo padrão.
2. No detalhe da OP local, **Sequência da OP** continua permitindo ajustar as etapas seguintes.
3. Os operadores iniciam, pausam e concluem os postos da demo. A próxima etapa segue a sequência escolhida. Voltar respeita a etapa anterior dessa sequência. Concluir o último posto finaliza o fluxo local, sem inserir expedição automaticamente ou lançar saída física.
4. Use **Produção · Protheus** no painel para abrir `/producao` e consultar os registros oficiais do DEV.

### Consulta oficial

Segue o padrão de almoxarifado/SMD. As abas são **OPs, Apontamentos, Consumo, Movimentações e Estoque**. O padrão mostra OPs abertas do 05, filial 04, em todo o período. Busca, situação, mês/ano e intervalo personalizado refinam a consulta, com páginas de 20, 50 ou 100 registros.

O mês usa emissão nas OPs e data do movimento no histórico. Estoque é sempre saldo atual de SB2 no 05. O mês permanece ao trocar de aba; ao alterar um filtro, volta à primeira página.

O histórico inclui SD3 do **armazém 05** e movimentos vinculados às **OPs do 05 em qualquer destino**. Assim, uma entrada PR0 no 10 ou 07 não desaparece da produção. Cada movimento identifica seu armazém efetivo. A referência é filial + número/item/sequência da OP, sem inferir o vínculo pelo produto. Notas fiscais continuam limitadas ao local 05; não há vínculo automático das notas de outros locais com a OP.

Abrir a OP permite consultar seus empenhos e movimentos. Esses registros oficiais não são importados automaticamente como filas ou etapas da demo.

| Posto | Guia | Rota |
|---|---|---|
| Gravação de firmware | [Funcionamento](firmware/README.md) | /firmware |
| Soldagem | [Funcionamento](soldagem/README.md) | /soldagem |
| Teste | [Funcionamento](teste/README.md) | /teste |
| Fechamento | [Funcionamento](fechamento/README.md) | /fechamento |

## Estado local e estado oficial

As filas de operação vêm de `ProductionFlowStore`. Iniciar, pausar e concluir alteram esse fluxo local.
Uma conclusão de etapa não é uma baixa oficial de componentes nem encerra automaticamente a SC2.

No DEV, o local **05** representa produção MEC. Existem registros de produção cuja OP é do 05 e cujo acabado entra no **10**. Por isso, local da OP, local dos componentes e destino do acabado precisam ser tratados separadamente.

A consulta administrativa oferece os armazéns operacionais originais: 01, 03, 05, 06, 07 e 10.
O local 04 PTH permanece identificado no mapeamento histórico, mas não é oferecido como opção nessa nova consulta administrativa.

## Continuação necessária

- Conciliar filas locais com OPs, saldos e empenhos oficiais.
- Conciliar entregas, recebimentos e retornos locais com os documentos oficiais. Defeitos continuam sendo ocorrências, sem conversão automática para peças remetidas.
- Aplicar as regras de parcial, perdas, ganhos e estorno antes de qualquer futura integração de escrita.
- Preservar quantidades fracionadas também nos modelos antigos dos outros setores.
- Resolver persistência compartilhada entre computadores; atualmente não há banco de eventos central conectado.

Código comum: [ProductionFlowStore](../../../lib/data/repositories/production_flow_store.dart).

Consulta: [ProductionReadPage](../../../lib/ui/production/production_read_page.dart). Evidências: [auditoria da produção](../../auditorias/2026-09-24/producao.md). Verificação: [testes desta entrega](../../testing/producao-consulta-sequencia.tdd.md).


## Relatório de movimentações

Disponível em `/producao/relatorios`, pelo botão de relatório da tela ou pela aba Relatórios do painel. Escopo: 05 e movimentos internos vinculados às OPs do 05, exibindo o armazém efetivo. Usa a mesma base do almoxarifado: mês/período, tipo, produto, OP, usuário e códigos; prévia, resumo, evolução e PDF com detalhe opcional. Totais abrangem o recorte completo; detalhe limitado a 1.000 registros e 60 páginas, com aviso para refinar ou gerar resumo. Somente leitura do DEV.

[Regras e verificação da ampliação](../../testing/relatorios-setores.md).

## Produtividade e operação

Em `/producao/relatorios`, escolha **Fonte dos dados** e **O que analisar**. Operadores, tempos e pausas usam diretamente o `ProductionFlowStore` existente. Não dependem de recepção no Protheus nem geram escrita nele.

| VettiFlow · operação | Regra |
|---|---|
| Tempos por etapa | Etapas concluídas, agrupadas por etapa e produto; total e média usam `ProductionStageTiming.elapsed` |
| Trabalho por operador | Sessões encerradas por operador, OP e etapa; tempo ativo usa `workedDuration`, com pausas descontadas |
| Pausas | Motivo, operador, OP, etapa e duração das pausas encerradas |
| Qualidade no teste | OPs com teste concluído, tamanho do lote e ocorrências de defeito por tipo |

O mês considera a conclusão da etapa/sessão/teste ou a retomada da pausa. As durações são integrais dos eventos concluídos no recorte, inclusive se começaram antes; não são rateadas entre meses. Eventos ainda abertos ficam fora destas análises. A sequência de cada OP é preservada: não é obrigatório percorrer gravação, soldagem, teste e fechamento.

O campo de quantidade das sessões já é preenchido nas pausas. Aparece como **Qtde declarada**, não como produção final atribuída à pessoa. Não calculamos uma taxa de eficiência individual a partir de dados parciais. Defeitos são ocorrências por tipo, pois os registros não garantem identificação de peças únicas. Dados locais permanecem identificados como deste dispositivo até haver persistência compartilhada.

Na fonte **Protheus · movimentos**, há quantidade apontada, por OP, evolução, destino do apontamento, consumo/devoluções, estornos e todos os movimentos. As primeiras quatro opções usam PR0 sem marca de estorno e mantêm quantidades por produto/unidade. O consolidado não deduz peças por hora a partir do número de lançamentos. Tempos e operadores continuam na fonte VettiFlow.

Todos os modelos geram PDF do resultado consultado. As linhas locais são limitadas a 100, com contagem total e aviso; os indicadores usam todo o recorte. O PDF mantém o teto de 60 páginas. [Verificação leve](../../testing/produtividade-producao.md).


## Operação e preparos de envio — 25/09/2026

Em **Produção → Operação no VettiFlow** (`/producao/operacao`):

- **Em produção** reúne gravação, soldagem, teste e fechamento. **Programadas** mostra OPs que ainda passarão por esses postos; SMD só aparece quando pertence à rota escolhida. **Fim da produção** reúne OPs encerradas ou na expedição, sem presumir despacho.
- Cada OP mostra lote/unidade, sequência, próxima etapa, operadores, tempo ativo e materiais solicitados/entregues. Os materiais mantêm origem e destino registrados; entrega do almoxarifado não é recebimento presumido da produção.
- **Abrir etapa** seleciona a OP nas telas existentes, mantendo início, pausa, assinatura e conclusão. Operadores acessam seu posto; gestão da produção/administração pode abrir os postos. Consulta e relatórios exigem perfil de gestor ou liberação em **Colaboradores → Acesso ao setor**, definida por Tatiane para a equipe de produção e expedição.
- Busca por OP/produto, etapa, mês/intervalo/todo o período e páginas de 20 itens. Filas usam criação da OP; envios usam a data da última movimentação. Tempos refletem a última atualização da tela; o botão Atualizar tempos renova a leitura.

### Preparar envio

Produção e administração podem preparar uma quantidade para **suporte 06**, **suporte 07** ou **expedição 10**. O destino é escolhido explicitamente; não é deduzido do defeito, produto ou total de ocorrências. Para preparar, a OP deve identificar local 05 e unidade e já estar em um posto interno, na expedição ou ter encerrado uma sequência de produção. É possível planejar antes da conclusão: o preparo não declara qualidade aprovada nem autoriza uma transferência física.

O limite de planejamento é o lote menos preparos ativos, quantidades armazenadas e despachadas pela conferência local anterior. Isso não é saldo do Protheus. O mesmo produto/OP mantém sua unidade e aceita quantidades fracionadas no preparo; o modelo antigo do tamanho do lote continua inteiro.

O registro conserva OP/produto, destino, quantidade, motivo, etapa de origem, data e operador. Repetir a mesma identificação não duplica o preparo. **Cancelar restante do preparo** exige motivo, mantém o registro original e libera somente a quantidade ainda não entregue para novo planejamento. É cancelamento de planejamento, não retorno de mercadoria entregue. A OP com histórico de preparos não pode ser excluída pelo cancelamento antigo.

**Envios e retornos** reúne o histórico por OP/destino. A produção registra cada entrega; o destino confirma seu próprio recebimento. Somente a entrega reduz a quantidade exibida em **Na produção**; o preparo só reserva a quantidade para planejamento. Não se inicia uma etapa com toda a quantidade fora da produção.

O suporte recebe em `/suporte/operacao`; a expedição recebe em `/expedicao/operacao`, inclusive envios vindos do suporte. As rotas antigas `/suporte/preparos` e `/expedicao/preparos` permanecem como atalhos. A conferência antiga de expedição bloqueia a finalização do lote inteiro enquanto houver quantidade comprometida no novo fluxo.

Entregar diretamente à expedição exige o fim da sequência interna. O envio ao suporte pode ocorrer durante a produção, por quantidade. Cada ação valida o saldo da sua origem, o setor responsável e a identificação do evento. Diagnóstico é texto, sem somar peças. Os registros guardam data, responsável e motivo, sem PIN.

**Receber devolução** aceita somente o que suporte/expedição já enviaram de volta. Se a OP estiver trabalhando, recebe na etapa atual. Se já tiver saído, escolhe uma etapa interna da programação para reabrir. Tempos anteriores são arquivados e continuam no relatório; sessões anteriores não são apagadas. Um retorno que repetiria SMD já concluído exige ajustar a programação do retrabalho. A quantidade recebida pode compor um novo preparo.

Em `/producao/materiais`, confirme recebimentos do almoxarifado, registre uso e devolva o restante; a origem confirma a chegada da devolução. **Solicitar material** no cartão consulta o código exato no cadastro do DEV e cria apenas um pedido local. Não há reserva ou baixa automática.

Preparar, entregar, receber, reparar, despachar ou devolver salva no cache do navegador; não chama o banco da OP nem publica movimento. A proteção contra ações simultâneas vale para a instância local. Ainda não existe transação compartilhada entre abas/computadores ou persistência central desses eventos. Nenhuma OP oficial do DEV é convertida automaticamente em OP local.

### Tempos e conclusão do teste

O PIN de conclusão do teste agora identifica a sessão a encerrar. Se outro operador permanece na etapa, ela continua aberta e os defeitos já registrados são mantidos. O último operador libera a próxima etapa escolhida. Concluir uma sessão pausada fecha sua pausa e desconta esse período também do tempo da etapa. A quantidade declarada nas pausas permanece separada do lote e dos preparos.

Entrega, recebimento, diagnóstico, reparo, despacho e retorno parcial já funcionam no fluxo local. Falta conciliá-los com os movimentos oficiais e implementar perdas/ganhos/estornos oficiais. Esses eventos não entram nos PDFs de movimentos do Protheus. Operadores/tempos continuam nos relatórios locais, incluindo as visitas de retrabalho.

Código: `production_work_page.dart`, `production_dispatch_draft.dart` e `ProductionFlowStore`. Verificação pontual: `test/sector_routes_test.dart`, `test/production_operation_test.dart`, mais os testes existentes de sequência, SMD e produtividade. Não foi executada suíte pesada nem gravação no DEV.
