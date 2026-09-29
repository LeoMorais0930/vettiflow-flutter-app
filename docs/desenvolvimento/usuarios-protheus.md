# Cadastro de usuários Protheus no VettiFlow

## Fontes entregues

Inspeção em 29/09/2026 dos 122 fontes PRW/TLPP disponíveis em `C:/Users/Leonardo Morais/Desktop/vetti/VettiFlow/protheus_advpl`.

- `vettip12/estoque/atualizacao/RESTA011.prw`, linhas 70–71: RetCodUsr e UsrRetName identificam o usuário que executa a requisição.
- `vettip12/CFG/MSCFGA02.prw`, linhas 80–86: identificação do executor no log.
- `vettip12/pcp/execblock/RPCPE002.prw` e `RPCPE003.prw`, linha 142: identificação em envio/retorno para terceiros.

Não foi encontrada nesses fontes uma rotina de listagem de todos os usuários ativos. Os exemplos de identificação do executor não constituem um diretório de usuários.

## Consulta implementada

GET `/api/v1/flow/access/directory` exige JWT e perfil de administrador da API. Faz SELECT em `SYS_USR` no banco configurado. Retorna exclusivamente ID, login e nome, além do banco de origem e instante UTC da consulta. Não lê senhas, hashes, e-mails ou privilégios ERP.

Critério: registro não excluído, login preenchido, `USR_MSBLQL = '2'` e `USR_MSBLQD` vazio ou uma data válida igual/posterior à data atual do SQL Server. Datas inválidas são excluídas. A [documentação TOTVS sobre os campos de bloqueio](https://centraldeatendimento.totvs.com/hc/pt-br/articles/12171324016023-Cross-Segmento-Backoffice-Linha-Protheus-SIGAEST-Campo-NNR-MSBLQL-s%C3%B3-aparece-para-usu%C3%A1rio-adm) descreve bloqueio manual e bloqueio quando a data do sistema supera a data cadastrada.

Conferência local: HMLp12 tinha 82 registros não excluídos, 37 bloqueados, 44 liberados sem data de bloqueio e um liberado com bloqueio datado de 15/09/2025. A consulta retornou 44 logins, sem duplicados por diferença de caixa e compatíveis com o formato aceito no editor de permissões. São contas habilitadas no cadastro, não sessões online nem uma garantia de autenticação: políticas adicionais continuam sendo validadas pelo Protheus no login.

O cadastro é geral do banco, não limitado automaticamente à filial 04. A lista não comprova acesso a uma filial ou rotina. Também pode incluir contas de serviço; não há inferência de colaborador, setor ou perfil a partir do nome.

## Tela e atualização

Em Colaboradores → Permissões de execução, a lista permite busca por nome/login e seleção da conta para consultar suas permissões VettiFlow. Selecionar não grava nem concede etapas. A atribuição só ocorre ao salvar explicitamente. Contas já configuradas continuam acessíveis para revogação, mesmo se saírem da lista de ativos.

Abrir a tela ou usar Atualizar acessos faz uma nova consulta. O horário mostrado é o da leitura, não o da atualização da base oficial. Enquanto a conexão apontar para HMLp12, o resultado reflete essa cópia; a periodicidade de sua substituição não foi comprovada. Uma falha SQL é apresentada como erro e não bloqueia a gestão das permissões já configuradas.

Esta integração consulta o cadastro; não importa permissões ERP, não altera contas Protheus e não cria automaticamente o perfil de navegação Flutter.


## Vínculos confirmados em 29/09/2026

O login remoto usa `ProtheusOperatorProfiles`, sem reaproveitar senhas/PINs
ou atribuir um perfil por semelhança de nome. Usuários sem vínculo ficam
pendentes de cadastro no app. A autenticação continua sendo feita pelo Protheus.
Este cadastro define a interface; não concede escrita no ERP nem altera os
acessos individuais de execução da etapa na API.

| Setor | Logins confirmados |
| --- | --- |
| Produção | tatiane, andressa.camargo |
| SMD | paulad, leandro |
| Almoxarifado | vera, luis, silvania.teixeira, rosangela.prestes |
| Suporte | bruno, vinicius, douglas, matheus, natalina.rosimeire, gabriel.fontes |
| Expedição | expedicao (Bruna e Tamara, conta compartilhada) |
| Administração | leonardo.morais, artur, vitor.vasconcelos |

Silvania foi transferida para Almoxarifado. Brayan (`brayan.vieira`) está no
Comercial, fora dos setores operacionais; o app ainda não tem módulo Comercial.
Natalina Rosimeire é a Rose do Suporte; Rosangela é a Rose do Almoxarifado.
Gestão preservada para Tatiane, Andressa, Paula, Vera, Bruno e Vinicius.

Gabriel Fontes confirmado no Suporte. Giovana Camargo (`giovanna.camargo`)
está no Comercial e não recebeu perfil operacional. Bruna e Tamara podem usar
`expedicao`: registros autenticados terão essa identidade compartilhada, sem
atribuição individual presumida.

Pendência: Guilherme Assis (Suporte) provavelmente ainda não tem login, segundo
o responsável. Aguardar cadastro/login próprio confirmado. A exportação contém apenas
Guilherme Nascimento (`guilherme`, bloqueado) e Guilherme Neves Luques de Lima
(`guilhermem`, liberado); não foram associados ao Assis sem confirmação.
Contas exportadas bloqueadas não foram vinculadas: juliana, rafaela, david,
bruna, paula e guilherme. Os demais nomes antigos sem correspondência precisam
de login individual confirmado. Nenhuma conta foi criada ou desbloqueada no ERP.

Artur Augusto e Vitor Vasconcelos promovidos por solicitação explícita do responsável.
A instalação local inclui os três em VF_FLOW_ADMIN_USERS. Outros ambientes precisam
de configuração equivalente; o perfil Flutter não substitui a autorização da API.


Revisão de escrita após promoção dos administradores:
- `ProtheusSyncClient.push/finalizar` retorna bloqueio de somente leitura sem POST.
- Execução de etapa (`flow_tracking.py`) persiste no SQLite do VettiFlow.
- `VFFILA01.prw` possui abertura MATA650, mas está sem compilação/homologação e
  sem integração JWT do consumidor. A fila e a execução estão desativadas localmente.
- O adaptador DEV de abertura tem configuração separada; uma flag de escrita
  ligada não demonstra conectividade nem homologação da rotina.
- O formulário Nova OP agora recebe capacidade de planejamento pelo perfil,
  incluindo administradores, em vez de depender apenas do nome de duas pessoas.

Validação desta alteração: 15 testes de perfil/login/permissões, 4 testes API de
acesso e teste específico de planejamento por administrador aprovados. Na suíte
mais ampla production_workspace, dois testes de consulta falharam (atalho de
texto ausente e consulta vinculada); essa suíte não foi considerada aprovada.
