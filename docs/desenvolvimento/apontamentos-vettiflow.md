# Execução da etapa vinculada à OP

## Uso

Abra uma OP no dashboard e expanda **Execução da etapa**. Selecione a etapa real para iniciar; o armazém cadastrado no ERP não determina a etapa inicial. É possível pausar com motivo, retomar e concluir a etapa inteira. Depois de concluída, pode ser iniciada uma etapa posterior. Nesta versão não há retorno de etapa, reabertura nem apontamento de quantidade parcial.

O encerramento de etapa é um registro do VettiFlow; não altera a classificação oficial da OP, não baixa materiais e não executa PR0/RE1 ou ADVPL. Uma OP encerrada no Protheus aceita apenas consulta do histórico. A API consulta a SC2 pela chave completa antes de cada novo evento. Indisponibilidade do ERP impede uma gravação nova.

## Consulta no painel

No Kanban, alterne entre **Setor Protheus** (armazém cadastrado) e **Execução VettiFlow** (etapa registrada). A visão de execução permite filtrar em execução, pausadas, etapa concluída e sem registro; respeita também os filtros gerais de período e setor. Os cards mostram o setor ERP separadamente, etapa, situação, usuário do último registro e motivo da pausa. A tabela inclui a coluna Execução VettiFlow.

Salvar uma execução nos detalhes atualiza o painel. **Atualizar painel** busca registros de outros usuários; não há atualização contínua nesta versão. Concluir uma etapa não altera os indicadores oficiais da OP. OPs encerradas no ERP ficam em uma coluna própria, mesmo que o último registro interno fosse uma pausa.

A API fornece um resumo dos estados persistidos em `GET /api/v1/flow/states`, protegido pela autenticação existente e limitado a grupo, banco e filial configurados. O cliente associa cada estado pela chave completa, produto e emissão. Um vínculo cuja identidade mudou não é aplicado à OP atual. Falha ao consultar os estados mantém o painel anterior e mostra erro, em vez de exibir todas as OPs como sem registro.

## Persistência e identidade

`api/data/flow.sqlite3` guarda estado e eventos, fora do HMLp12. O caminho pode ser configurado por VF_FLOW_DB e deve ser incluído no backup do VettiFlow. Suporta uma instância local da API. Identidade: grupo, banco ERP, filial, número, item, sequência e grade. Produto e emissão são conferidos para detectar troca de identidade depois de restauração do ERP.

O executor vem da sessão JWT no servidor. O cliente não pode enviar ou substituir o usuário. Cada evento registra etapa, ação, motivo/observação, usuário, versão e instante UTC. A tela apresenta os últimos 200 eventos em horário local. Fechar o navegador ou reiniciar a API não apaga os eventos.

## Permissões

VF_FLOW_ADMIN_USERS contém logins Protheus explicitamente autorizados a executar qualquer etapa e gerenciar permissões. Leonardo Morais já havia sido autorizado como administrador VettiFlow e foi habilitado no ambiente local. A API não permite promover administradores nem alterar seus acessos pela tela.

Em **Colaboradores → Permissões de execução**, um administrador consulta o login Protheus, seleciona as etapas e salva. Nenhuma etapa selecionada significa somente consulta. Essas concessões são persistidas em `flow_access` no SQLite do servidor, por grupo/banco/filial; `flow_access_audit` registra autor, data UTC, estado anterior e novo. Sobrevivem ao reinício da API e à substituição de HMLp12. Os testes utilizam banco temporário; a implantação não concede acessos adicionais a usuários reais.

VF_FLOW_STAGE_USERS (JSON login em minúsculas -> lista de etapas) continua como configuração inicial. Uma concessão salva substitui essa configuração, inclusive lista vazia para revogação. Cada gravação de etapa consulta novamente a permissão dentro da mesma transação do evento, impedindo que uma revogação durante a consulta ao ERP seja ignorada. `expectedVersion` impede sobrescrever alteração concorrente; após falha ou resposta incerta, a tela exige consultar novamente, sem reenvio automático da escrita.

Rotas: GET `/api/v1/flow/access/me` para o próprio acesso; GET `/access/users`, GET e PUT `/access/users/{username}` sob o prefixo `/api/v1/flow`, exclusivos de administradores. Todas exigem a autenticação existente. O histórico da API retorna até 100 alterações, e a tela mostra as 10 últimas.

Este controle autoriza a **execução de etapas**. O perfil de navegação e vínculo do login ao cadastro do app ainda seguem o cadastro existente; cadastrar etapas para um login desconhecido não cria automaticamente esse perfil. A atribuição local de telas permanece separada e não autoriza gravação na API.

Etapas: warehouse, smd, firmware, soldering, testing, closing, expedition. Não há concessão de permissões no ERP.

## Concorrência e confirmação

POST /api/v1/flow/events exige chave da OP, requestId UUID, expectedVersion, etapa e ação. SQLite serializa as gravações em transação; versão divergente retorna 409. Reenvio do mesmo identificador e conteúdo não duplica eventos. Identificador reutilizado com outro conteúdo retorna 409. A tela mantém o identificador quando a resposta é incerta e permite consultar o estado ou reenviar. GET /api/v1/flow/order devolve estado, permissões e histórico.

Testes usam arquivos temporários e OPs simuladas; não foram criados apontamentos de teste nas OPs reais. A conferência da chave no SQL é somente leitura. As rotinas de escrita ERP continuam bloqueadas.
