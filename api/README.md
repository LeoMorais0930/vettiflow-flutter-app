# VettiFlow API Protheus Dev

API interna para consultas Protheus e comandos explícitos de produção via SQL
Server no DEV. A escrita SQL é desativada por padrão.

## Base Atual

- Servidor: `win-l1na6ce7lb4`
- Porta: `1433`
- Database SQL Server: `HMLp12`
- Schema: `dbo`
- Empresa: `010`
- Filial padrao: `04`

As rotas legadas de sincronização continuam bloqueadas com `503`. Esta API lê
produtos, estrutura, saldos, OPs abertas, empenhos, movimentos oficiais de OP,
transferencias oficiais entre locais, desmontagens oficiais e auditoria de
movimentos especiais de estoque, alem de previa read-only de apontamento.
Tambem expoe governanca de escrita futura por `GET /api/v1/write-readiness`,
referente ao adapter AppServer, separado do módulo SQL.

O módulo `GET /api/v1/dev/producao-sql/status`,
`POST /api/v1/dev/producao-sql/comandos` e
`GET /api/v1/dev/producao-sql/comandos/{id}` implementa abertura, alteração,
transferência e apontamento. Exige `X-VettiFlow-Write-Key` além do token de
consulta. Veja [instalação, limites e validação SQL DEV](../docs/desenvolvimento/sql-producao-dev.md).
O `/health.readOnly` considera ambos os caminhos de escrita; disponibilidade
configurada não confirma migração instalada nem homologação no ERP.

O almoxarifado também consulta histórico, estoque, OPs e inventários. Datas omitidas abrangem todo o período, com até 100 registros por página.

O passo a passo do app está no [README principal](../README.md); os guias estão em [docs](../docs/README.md).

## Subir Local

```bash
python -m venv venv
./venv/Scripts/pip install -r requirements.txt
cp .env.example .env
```

Preencha `api/.env` com a senha local do SQL Server e um token interno. Esse
arquivo e ignorado pelo Git.

```bash
./venv/Scripts/uvicorn app.main:app --reload --port 8000
```

Documentacao interativa:

```text
http://localhost:8000/docs
```

### Testar login no Protheus pelo Swagger

Abra `/docs` localmente, expanda **Login Protheus — teste** e use
`POST /api/v1/auth/protheus/test` → **Try it out**. Preencha `username` e
`password` com sua conta Protheus e clique **Execute**. Se `VF_API_TOKEN`
estiver configurado, use antes **Authorize** com esse token interno (não a senha ERP).
A documentação dispensa esse token apenas em loopback; as operações permanecem protegidas.

Configure `VF_PROTHEUS_REST_URL` com a raiz HTTPS do REST DEV.
O diagnóstico chama `POST /api/oauth2/v1/token?grant_type=password`, com
credenciais nos cabeçalhos, conforme o [contrato TOTVS](https://tdn.totvs.com/pages/viewpage.action?pageId=465383509).
Não segue redirecionamentos nem desativa a verificação do certificado.

`200` com `authenticated=true` confirma que o Protheus retornou token Bearer
em uma resposta HTTP 200 ou 201; `upstreamStatus` preserva o status do ERP;
`400` indica solicitação recusada; `401/403`, autenticação/acesso recusado;
`502`, falha TLS/conexão ou resposta incompatível; `504`, timeout;
`503`, configuração ausente/inválida. MFA requer integração adicional.
Senhas e tokens não são persistidos nem devolvidos. Limpe os campos ou feche
o Swagger após o teste. Não há sessão VettiFlow, execução de rotina ou
confirmação de permissões de movimentação. A configuração da filial enviada
também não comprova a base efetiva do servidor remoto.

## Configuracao

### Sessão JWT obrigatória (29/09/2026)

Todas as rotas de negócio agora exigem **Authorization: Bearer JWT**, inclusive
em loopback e mesmo quando `VF_API_TOKEN` está vazio. Quando configurada, a
chave `X-API-Token` continua sendo uma exigência adicional. As exceções são
login/teste de login (precisam receber credenciais antes de ter JWT), preflight
CORS e documentação local. A documentação não executa operações sem autenticação.

No Swagger:

1. **Authorize → APIKeyHeader**: informe a chave interna.
2. Execute `POST /api/v1/auth/protheus/login` com usuário e senha.
3. Copie o `access_token` retornado para **Authorize → ProtheusJWT**, sem prefixo Bearer.
4. `GET /api/v1/auth/protheus/session` consulta a sessão local.
   `POST /api/v1/auth/protheus/probe` faz uma leitura de metadados no REST DEV.
5. `POST /api/v1/auth/protheus/logout` encerra a sessão nesta API.

`/test` permanece somente diagnóstico e não registra sessão. `/login` devolve
o token do Protheus ao usuário; não salva senha. O refresh_token fica apenas em memória para renovação. O servidor
registra somente hash do token, login informado, destino e expiração em memória.
Só aceita tokens obtidos diretamente pelo login HTTPS desta instância: não
valida JWT arbitrário apenas decodificando seus campos. A assinatura do ERP
não é verificada localmente por uma chave pública; a confiança é a resposta
HTTPS do ERP e a correspondência exata do hash registrado. A expiração é o
menor valor entre `exp`, `expires_in` e uma hora. Reiniciar a API exige novo login.
Use **um worker**; múltiplos workers exigem armazenamento compartilhado de sessões.

Logout é local, não revoga o JWT nos demais serviços Protheus. Bloqueios de conta
ou revogação no ERP não são consultados a cada SELECT SQL; um 401 no probe
encerra a sessão local. Privilégios por rotina/setor ainda precisam ser integrados:
login válido não comprova autorização para escrita. O Flutter autentica pelo
endpoint de login e injeta o Bearer nos clientes dos repositórios. Não há fallback
para senha local na tela de entrada. JWT e senha não são persistidos; expiração,
logout e HTTP 401 encerram o acesso à interface. Usuários sem vínculo de perfil
veem apenas a tela de conta pendente; `leonardo.morais` foi vinculado ao perfil de
administrador VettiFlow, sem alterar permissões ERP. O perfil local controla a
interface e não substitui autorização por operação no servidor.

Configure `VETTIFLOW_API_URL` e `VETTIFLOW_API_TOKEN` no build Flutter. A chave
incluída no cliente web não é um segredo de usuário: a autenticação individual
continua dependendo do JWT. Fora de localhost, o cliente exige HTTPS. Enquanto
o contorno de horário do DEV estiver ativo, cada token tem janela local de cinco minutos, renovável pelo ERP até o limite absoluto de oito horas.

O probe não mantém thread ERP aberta nem renova tokens. Acompanhe o monitor do
**AppServer REST DEV**, não o P12OFICIAL. A requisição pode ser breve demais para
aparecer no intervalo de atualização. Manter uma linha permanente no monitor
exige suporte/configuração do ERP; não é consequência de conservar um JWT.
Não foram alterados AppServer/RPO, habilitadas escritas ou criados jobs.

#### Contorno temporário de relógio no DEV

Para a configuração HMLp12/grupo 01/filial 04, `/login` pode reconhecer o caso
observado: JWT recebido diretamente do ERP, `exp` vencido há no máximo 120 s,
`iat` aproximadamente uma hora atrás e duração interna/`expires_in` de 3600 s.
Nesse caso, antes de registrar a sessão, consulta os metadados de OP por HTTPS:
um token inválido de controle precisa receber 401 e o token recebido precisa
receber 200 com JSON. Não há soma de uma hora ao `exp` nem liberação offline.

O retorno identifica `validationMode=protheus_online`. A sessão dura no máximo
**5 minutos por token**, com renovação automática quando disponível; cada chamada protegida repete essa validação (duas leituras
HTTP, sem cache). 401/403 do ERP revoga a sessão; timeout, resposta inesperada
ou endpoint que aceite o controle inválido bloqueiam o acesso. Essa leitura
confirma acesso ao endpoint consultado, não os privilégios de todas as rotinas.
Fora desse caso específico a verificação de expiração original permanece.
O contorno não corrige o relógio do AppServer, não mantém conexão no monitor
e pode falhar se o próprio ERP recusar o JWT ou os metadados de OP.

Os exemplos de consultas abaixo também precisam de `-H "Authorization: Bearer $PROTHEUS_JWT"`.

| Variavel | Padrao | O que faz |
|---|---|---|
| `VF_PROTHEUS_HOST` | `win-l1na6ce7lb4` | Host SQL Server |
| `VF_PROTHEUS_PORT` | `1433` | Porta SQL Server |
| `VF_PROTHEUS_DATABASE` | `HMLp12` | Base dev |
| `VF_PROTHEUS_SCHEMA` | `dbo` | Schema das tabelas |
| `VF_PROTHEUS_USER` | vazio | Login SQL Server |
| `VF_PROTHEUS_PASSWORD` | vazio | Senha SQL Server local |
| `VF_MSSQL_DRIVER` | `ODBC Driver 17 for SQL Server` | Driver ODBC instalado |
| `VF_MSSQL_ENCRYPT` | `No` | Criptografia da conexao |
| `VF_MSSQL_TRUST_SERVER_CERT` | `Yes` | Aceita certificado interno |
| `VF_API_TOKEN` | vazio | Token exigido em `X-API-Token`; vazio libera so loopback |
| `VF_CORS_ORIGINS` | `*` | Origens web aceitas |
| `VF_EMPRESA` | `010` | Sufixo das tabelas, como `SB1010` |
| `VF_FILIAL` | `04` | Filial padrao |

## Validar

```bash
./venv/Scripts/python -m pytest tests/ -q
```

```bash
curl -H "X-API-Token: $VF_API_TOKEN" http://localhost:8000/api/v1/health
curl -H "X-API-Token: $VF_API_TOKEN" "http://localhost:8000/api/v1/produtos?query=710&filial=04&limit=5"
curl -H "X-API-Token: $VF_API_TOKEN" "http://localhost:8000/api/v1/ops/01621401001/movimentos?filial=04"
curl -H "X-API-Token: $VF_API_TOKEN" "http://localhost:8000/api/v1/transferencias?filial=04&produto=100-010&limit=10"
curl -H "X-API-Token: $VF_API_TOKEN" "http://localhost:8000/api/v1/desmontagens?filial=04&documento=DESMONT23"
curl -H "X-API-Token: $VF_API_TOKEN" "http://localhost:8000/api/v1/auditoria-estoque?filial=04&tipo=estorno_op&limit=10"
curl -H "X-API-Token: $VF_API_TOKEN" "http://localhost:8000/api/v1/ops/01621401001/apontamento-preview?filial=04&quantidade=50"
curl -H "X-API-Token: $VF_API_TOKEN" "http://localhost:8000/api/v1/write-readiness"
```

## App Flutter

```bash
flutter run \
  --dart-define=VETTIFLOW_API_URL=http://localhost:8000 \
  --dart-define=VETTIFLOW_API_TOKEN=trocar-por-um-token-interno
```

## Endpoints

| Metodo | Rota | Para que serve |
|---|---|---|
| `GET` | `/api/v1/health` | Confirma conexao com `HMLp12` |
| `GET` | `/api/v1/write-readiness` | Declara governanca de escrita: `readOnly=true`, `writeEnabled=false`, operacoes bloqueadas e requisitos futuros |
| `GET` | `/api/v1/produtos?query=...` | Busca produtos para autocomplete |
| `GET` | `/api/v1/produtos/{codigo}` | Produto, estrutura e saldos |
| `GET` | `/api/v1/produtos/{codigo}/saldos` | Saldo por almoxarifado |
| `GET` | `/api/v1/ops/abertas` | OPs em aberto |
| `GET` | `/api/v1/ops/{op}/empenhos` | Empenhos SD4 da OP |
| `GET` | `/api/v1/ops/{op}/movimentos` | Snapshot read-only de `SC2`, `SD4` e `SD3` com `PR0`, `RE1`, `ER0`, `DE1`, documento, `D3_NUMSEQ`, perda, ganho e status oficial |
| `GET` | `/api/v1/ops/{op}/apontamento-preview` | Previa read-only de apontamento, simulando `PR0/001`, `RE1/999`, quantidade restante, saldo de componentes e pendencias de rotina oficial |
| `GET` | `/api/v1/transferencias` | Snapshot read-only de transferencias `RE4/999` e `DE4/499`, pareando origem, destino, produto, quantidade, documento e status |
| `GET` | `/api/v1/desmontagens` | Snapshot read-only de desmontagens `RE7/999` e `DE7/499`, separando produto origem, componentes retornados, locais, documento e status |
| `GET` | `/api/v1/auditoria-estoque` | Snapshot read-only de `ER0/999`, `DE1/499`, `DE0/400` e `RE0/501`, separando tipo, documento, OP, usuario, motivo, produto, local, quantidade e sequencia |
| `GET` | `/api/v1/almoxarifado` | Visão geral/histórico/estoque/OPs/inventário; filtros, contagem e paginação no servidor |
| `GET` | `/api/v1/relatorios/almoxarifado` | Relatório de movimentos do 01, filial configurada: totais do recorte completo, série temporal, ranking por produto/unidade e detalhe opcional; somente SELECT |
| `GET` | `/api/v1/relatorios/{setor}` | Mesmo modelo para `smd` (03), `producao` (05 e SD3 de suas OPs), `suporte` (06/07), `expedicao` (10), `gestao` (locais físicos 01/03/05/06/07/10) |
| `GET` | `/api/v1/almoxarifado/movimentos/{recno}` | Contrapartes de transferência e desmontagem |
| `GET` | `/api/v1/producao` | OPs/estoque do 05; histórico do 05 e SD3 vinculados a suas OPs em outros locais, com os mesmos filtros de data e paginação |
| `GET` | `/api/v1/suporte` | Consulta do 06/07 (parâmetro `local`, padrão 06); mesmas visões e filtros, `kind=fiscal` reúne SD1/SD2 antes de contar/paginar; limite 100 |
| `GET` | `/api/v1/expedicao` | Consulta física do 10: histórico, notas, estoque, OPs e inventário; mesmos filtros e limite de 100 registros |
| `GET` | `/api/v1/expedicao/notas/{recno}` | Pedido do item SD2 do 10 e transporte/volumes/rastreio de SF2, por identidade fiscal completa; sem enviar email ou gravar rastreio |
| `POST` | `/api/v1/mutations` | Bloqueado: somente leitura |
| `POST` | `/api/v1/finalizar` | Bloqueado: somente leitura |

### Relatórios de movimentações

Filtros: `start`/`end` juntos em ISO ou ambos omitidos (todo o período), `query`,
`kinds` repetível, `product`, `op`, `operator`, `document`, `unit`, `cf`, `tm`,
`tes`, `cfop`, `source` (all/SD3/SD1/SD2), `flow` (all/in/out/none/unknown),
`status` (all/active/reversed), `details` (boolean). Campos exatos, exceto `query`,
que busca trecho no produto/descrição/documento/OP. Campos desconhecidos são recusados;
`local` e filial não são selecionáveis. `warehouses` é repetível e aceita somente os locais do setor (omitido = todos os do setor). Duplicatas são removidas. Fonte e tipo aplicam-se antes de contar.

Contrato versionado: `id`, filtros normalizados, origem/filial, janela de consulta,
`total`, `summary`, `series`, `products`, `items`, contagens de grupos e `detailStatus`.
Inclui `sector`, `warehouses`, `scopeNote` e `warehouseSummary` para identificar o contexto e o armazém físico. O resumo não depende da paginação da tela. Quantidades não são somadas entre produtos/unidades/armazéns. A produção usa `EXISTS` para vincular OPs sem duplicar movimentos; a gestão usa apenas armazéns físicos distintos, sem somar contextos sobrepostos.
Detalhe: até 1.000 linhas; acima, `too_large` sem itens. Se a contagem mudar durante
a leitura, `changed` sem itens. `not_requested` significa que o detalhe não foi solicitado.
Ranking de até 100 grupos; série de até 120 períodos com registro, com tamanho total informado.

Até dois relatórios simultâneos por processo; excedentes recebem 429. Orçamento de
40 segundos para consultas do relatório, com timeout de até 20 por SQL; a cobertura
global é informativa, usa o cache existente e pode ficar indisponível separadamente.
Não há cache do relatório, autorização individual ou garantia de snapshot transacional.
O Flutter gera o PDF com o resultado recebido, sem nova consulta durante a exportação.

Na produção, `analysis` aceita `movements` (padrão), `output`, `orders`, `evolution`,
`destinations`, `consumption` e `reversals`. As quatro análises de quantidade fixam
SD3/PR0/sem estorno; a resposta inclui os filtros efetivos e `production` com métricas
do recorte inteiro e até 100 grupos por produto/unidade. `reversals` inclui ER0 ou
registros marcados como estornados sem calcular saldo líquido. Nos demais setores,
somente `movements` é aceito. Tempos, operadores, pausas e qualidade locais não
passam por esta API: usam a lógica existente do VettiFlow no Flutter.

Depois do build, a prévia web local pode ser iniciada na raiz com
`api/venv/Scripts/python.exe scripts/serve_web.py --port 5174`.
Esse servidor fica em loopback e fixa o MIME de `.mjs` como `text/javascript`,
necessário ao PDF.js; no Windows o `python -m http.server` genérico pode herdar
`text/plain` do registro e impedir a prévia. A hospedagem definitiva precisa
servir os módulos JavaScript com MIME apropriado.


### Renovação e integração da fila (29/09/2026)

O Flutter chama `POST /api/v1/auth/protheus/refresh` antes do vencimento.
O refresh token retornado pelo ERP fica somente em memória na API, nunca no
JSON entregue ao navegador. Cada renovação precisa ser aceita pelo Protheus;
a sessão tem limite absoluto de oito horas desde o login. Logout impede
renovações tardias de restabelecer o acesso. Reiniciar a API exige novo login.
Sem refresh token, mantém-se a expiração original. Indisponibilidade de rede
não amplia o prazo. O desvio de horário do DEV ainda precisa ser corrigido;
a janela de cinco minutos permanece por token no modo online, com renovação.
O transporte de refresh usa cabeçalhos, como o login instalado; precisa de
validação real no REST DEV (os testes automatizados simulam o ERP).

O dashboard usa `GET /api/v1/ops/abertas?filial=04` para OPs oficiais, apenas
consulta. Quantidades produzidas vêm de C2_QUJE; não inferimos a etapa física
da fábrica a partir dessa quantidade. Rascunhos locais continuam separados.

Base da fila importada de `origin/developer` em `1e12242` (Vitor), mantendo
a autenticação JWT. `solicitante` é obtido da sessão; listagem/detalhe expõem
somente pedidos do usuário. O consumidor continua exigindo JWT **e** a chave
`X-VettiFlow-Consumer-Key`; a chave isolada não libera acesso.
`VF_QUEUE_ENABLED` libera criação de pedidos; `VF_QUEUE_EXECUTION_ENABLED`
controla separadamente o consumidor e permanece false até homologação.
O ADVPL original ainda precisa obter/enviar o JWT e ser compilado no DEV.
A tela Integração Protheus → ícone de nuvem consulta a fila central; ela não
envia automaticamente os rascunhos locais. Nenhuma escrita ERP foi liberada.
