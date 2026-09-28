# Escrita DEV — preparação e conexão

Estado em 25/09/2026: integração em preparação. Não houve execução de rotina,
compilação ADVPL, gravação SQL no ERP ou alteração dos serviços da VM.
O usuário fará os testes reais. `VF_WRITE_ENABLED=true` foi salvo no `.env`
local da API por solicitação dele. Habilitar essa flag expressa a opção
do ambiente; não comprova que exista uma rotina de escrita conectada.

## Ambiente confirmado

- REST acessível: `https://10.36.0.5:8084/rest`. GET sem credenciais retornou a
  página de autenticação TOTVS. HTTP simples encerrou a conexão sem resposta.
- A verificação inicial com o pacote de autoridades padrão do httpx falhou.
  `ssl.create_default_context()` resolveu a validação utilizando também as
  autoridades do Windows. GET `/rest/api/pcp/v1/prodOrders/fields`, com
  `tenantId: 01,04`, passou pela validação TLS e retornou HTTP 401, pois nenhuma
  credencial foi enviada. O adapter usa esse contexto, sem desabilitar a
  validação de cadeia ou hostname. Os GETs públicos anteriores de diagnóstico
  sem validação também não enviaram credenciais.
  O navegador interno do Codex falhou com `ERR_TUNNEL_CONNECTION_FAILED`;
  ainda falta identificar a mensagem do navegador da VM.
- Usuário confirmou acesso autenticado pelo navegador. As imagens da instalação
  mostram `PRODORDERS` com `POST api/pcp/v1/prodOrders`, descrito como
  **Inclusão de Ordens de Produção**. Também existem PUT/DELETE e os GETs
  `fields`, `hdfields`, `detfields`, `engfields`, `athfields` e `register/{orderid}`.
  O detalhe do POST só mostra `_queryparam: Undefined`; não documenta o JSON.
  Não reutilizar por suposição o contrato de `ProdOrderApp` (outro serviço).
- INI informado pelo usuário: serviço `.TOTVS_appserver_p12Rest`, ambiente
  `p12Rest`, `DBALIAS=HMLp12`, `Security=1`, `PrepareIn=01,01`.
- SELECT em `SYS_COMPANY`: grupo `01`, filial `01` = `VETTI_OLD`; grupo `01`,
  filial `04` = `VT`. `010` é o sufixo SQL usado pelo app, não o grupo REST.
- `SC2010` contém 12.706 OPs não excluídas, todas na filial `04`, nessa consulta.
- O `RootPath` informado pelo REST é `E:\Protheus12\protheus_data`; o Master DEV
  informa `E:\Protheus12DEV\protheus_data`. Conferir essa diferença antes de usar
  o serviço para executar rotinas. Não alterar esses caminhos automaticamente.

As chamadas da integração devem usar `tenantId: 01,04` e confirmar o ambiente
efetivo retornado pelo serviço. Não inferir banco/filial somente pelo nome do
serviço ou pelo caminho do RPO. O INI não foi alterado.

## Primeiro fluxo planejado

Abertura explícita de OP do almoxarifado; liberação entre etapas permanece local.
Não reenviar automaticamente a fila antiga de rascunhos. O adapter preparado
em `api/app/warehouse_writes.py` aceita apenas abertura com a estrutura atual do
Protheus, data de entrega, produto, quantidade e armazém 01/03/05. Não implementa
alteração manual de empenhos, transferência, baixa, desmontagem ou exclusão.

O adapter ainda NÃO está adaptado ao endpoint nativo `prodOrders`. Seus caminhos
`/capabilities` e `/orders` são um **contrato proposto do VettiFlow**, não APIs que
já foram encontradas no RPO. Não colocar a raiz `/rest` em
`VF_PROTHEUS_WRITE_URL` supondo que ela execute esse contrato. Primeiro listar
os campos/retornos autenticados e adequar o adapter ao serviço encontrado.

O contrato proposto exige:

1. GET `/capabilities`: autenticação Protheus, autorização de abertura, identidade
   efetiva (`database`, `server`, `company`, `branch`, `userId`),
   `contract=vettiflow.op.v1`, `routine=MATA650`,
   `allowedOperations=[abertura_op]` e `vettiCommitmentWarehouse=true` somente
   se a regra de local dos empenhos estiver implementada.
2. POST `/orders`: envelope `contract`, `id`, `company=01`, `branch=04`,
   `database=HMLp12`, `operation=abertura_op`, `payload`. O payload tem `opLocal`,
   `criadaEm`, `produto`, `quantidade`, `armazem`, `entrega` e
   `usarEstruturaProtheus=true`. A chave `id` também vai em `Idempotency-Key`.
3. Retorno com identidade efetiva, mesmo `id`, `status=applied` e `protheusRef`
   completa; rejeição transacional deve declarar `status=rejected`,
   `rolledBack=true` e `message`. Qualquer retorno ambíguo exige conferência.

O registro de envio fica em SQLite **local à API**, não no SQL do Protheus.
É persistido antes do POST. Timeout ou reinício não autoriza repetir uma criação.
A referência retornada é conferida por SELECT na SC2. Isso confirma os campos
da OP; ainda não constitui reconciliação completa de SD4/SB2. Não apagar o
registro de envio para tentar novamente sem conferir o ERP.

## Fontes da Vetti e documentação

Fontes copiados da VM foram encontrados em
`C:\Users\Leonardo Morais\Desktop\vetti\VettiFlow\protheus_advpl\vettip12`.
`pcp/ponto de entrada/MTA650I.prw` preenche `C2_VOP` e `C2_VGRU`.
`A650LEMP.prw` retorna `C2_LOCAL` como armazém do empenho após a tela de empenhos.
Não assumir que esse evento de tela é disparado por ExecAuto.

- [MATA650 — execução automática](https://tdn.totvs.com/x/Q9vTJw)
- [Empenhos após abertura por ExecAuto](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360019196191-Cross-Segmento-Backoffice-Linha-Protheus-ADVPL-EXECAUTO-MATA650-com-Gera%C3%A7%C3%A3o-de-Ops-Interm-Empenhos)
- [Usuários REST e tenantId](https://tdn.totvs.com/pages/viewpage.action?pageId=502457209)
- [Configuração REST](https://tdn.totvs.com/pages/viewpage.action?pageId=185747842)
