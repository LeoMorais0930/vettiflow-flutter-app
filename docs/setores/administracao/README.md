# Administração

## Painel

Rota: `/dashboard`. Reúne OPs do fluxo local, equipe, relatórios e solicitações locais.
Criar, avançar, voltar ou cancelar uma OP nesse painel não significa criar, movimentar ou cancelar a SC2 do Protheus.
Produtos e suas informações podem ser consultados pela API; as filas de operação continuam locais.

As ações disponíveis seguem os perfis já cadastrados e as regras de área do app. **Armazenadas** inclui os saldos dos novos envios por quantidade e da conferência anterior, com unidade e frações preservadas. Uma OP pode ter quantidade armazenada enquanto outra parte segue em circulação.

## Acesso e navegação

`OperatorAccess` centraliza os setores visíveis e a entrada nas rotas, inclusive quando a URL é aberta diretamente. O menu **Minha área e conta** reúne a navegação por setor; o painel mostra apenas **Meus setores** com consulta liberada para o usuário conectado.

Em **Colaboradores → Acesso ao setor**, há três níveis:

- **Somente operação:** usa a etapa atribuída; não abre consultas ou relatórios do setor.
- **Operação e consultas:** também visualiza as consultas e os relatórios do seu setor, sem gerir equipe.
- **Gestor do setor:** consulta e organiza a equipe do setor. Não pode conceder permissões a outras pessoas.

Tatiane define os acessos da produção (incluindo a equipe da expedição), Vera do almoxarifado, Paula do SMD e Bruno do suporte. O administrador atende todos os setores. Os responsáveis fixos são protegidos contra remoção por essa tela; Andressa e Vinicius mantêm inicialmente os perfis de gestão já cadastrados e podem ser ajustados pelos respectivos responsáveis.

A mesma regra vale para os diferentes logins de uma pessoa. Ao revogar um perfil antigo de gestor, seu login passa a abrir a etapa operacional atribuída. Operadores comuns entram diretamente em sua tela de trabalho; atalhos, consultas, relatórios e URLs diretas respeitam a permissão.

Permissões e etapas ficam em `vetti_flow.operator_access.v1`, no armazenamento local, e sobrevivem ao fechamento do navegador. Abas da mesma origem recebem as alterações; outros dispositivos ainda não compartilham esse cadastro. Não são gravados PINs/senhas nesse registro.

| Perfil atual | Operação | Consulta adicional |
|---|---|---|
| Tatiane e Andressa (gestão de produção) | Produção e expedição | SMD, sem apontamento |
| Paula | SMD e gestão de colaboradores | SMD |
| Vera | Almoxarifado e gestão de colaboradores | Almoxarifado |
| Bruno | Suporte e gestão de colaboradores | Suporte |
| Luis e demais operadores | Posto atribuído | Apenas com liberação do responsável |
| Administrador do sistema | Todos os setores | Armazéns e relatórios gerais |

Paula entra em `/smd/apontar` e acessa **Colaboradores** pelo menu da conta. Os gestores de área mantêm seu painel, limitado aos atalhos de seus setores.

Essas regras restringem a interface e as operações locais. Não substituem autenticação/autorização individual no servidor: a API ainda usa o token compartilhado existente.

## Consulta administrativa de armazéns

Rota separada: `/admin/armazens`. O atalho aparece para o perfil administrativo do sistema.
A própria tela recusa outros perfis antes de iniciar a consulta.

O seletor oferece somente os armazéns originais da operação:

| Código | Setor |
|---|---|
| 01 | Almoxarifado |
| 03 | SMD |
| 05 | Produção |
| 06 | Suporte |
| 07 | Suporte |
| 10 | Expedição |

Outros locais continuam conhecidos no mapeamento para explicar registros históricos e contrapartes; não são oferecidos no seletor.
A consulta comum do almoxarifado permanece fixa no 01. A criação local de OP também foi limitada aos seis códigos operacionais.

As consultas, os filtros e a paginação são os mesmos da [consulta do almoxarifado](../almoxarifado/README.md). Em telas estreitas, o seletor **Consultar** substitui as abas; filtros começam recolhidos. **Mais opções** reúne relatórios e rotas secundárias do setor.
O acesso por perfil é uma separação na interface atual. A API usa o token compartilhado já existente; ainda não possui autorização individual por usuário/armazém.

## O que falta

Autenticação e autorização no servidor, persistência compartilhada dos eventos locais, conciliação dos rascunhos e relatórios com os documentos oficiais.
A fila Protheus não envia operações enquanto a política de somente leitura estiver ativa.

Código: [DashboardPage](../../../lib/ui/dashboard/dashboard_page.dart), [rotas](../../../lib/app/app_routes.dart), [consulta administrativa](../../../lib/ui/warehouse/warehouse_read_page.dart).


## Relatório de movimentações

Disponível em `/gestao/relatorios`, pelo botão de relatório da tela ou pela aba Relatórios do painel. Escopo: 01, 03, 05, 06, 07 e 10 por armazém físico, sem sobrepor os contextos de OP. Usa a mesma base do almoxarifado: mês/período, tipo, produto, OP, usuário e códigos; prévia, resumo, evolução e PDF com detalhe opcional. Totais abrangem o recorte completo; detalhe limitado a 1.000 registros e 60 páginas, com aviso para refinar ou gerar resumo. Somente leitura do DEV.

O relatório abre resumido, com o período e **Gerar prévia**. Os grupos de filtros ficam em **Ajustar filtros**. O relatório geral exige administrador; cada setor mantém seu relatório dentro do acesso correspondente.

[Regras e verificação da ampliação](../../testing/relatorios-setores.md).
