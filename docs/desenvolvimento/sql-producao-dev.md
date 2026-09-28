# Produção por SQL no DEV

Implementação de 28/09/2026, branch `developer`. Não depende do REST pago da TOTVS.
O Flutter chama o backend FastAPI existente; somente o backend conecta ao SQL Server.
As credenciais SQL não vão para o app. Esta entrega implementa o fluxo delimitado
abaixo, não uma reprodução integral do ExecAuto/Protheus.

## Operações implementadas

| Comando | Consulta | Insere/atualiza |
|---|---|---|
| `abrir` | SB1, SG1 vigente, NNR, SB2 | SC2 no 05, C2_VOP/C2_VGRU, SD4 e SB2.B2_QEMP; sem movimento físico SD3 |
| `alterar` | OP e empenhos registrados pelo módulo | C2_QUANT/entrega, SD4 original/restante, delta de B2_QEMP; antes de qualquer apontamento |
| `transferir` | Produto, armazéns e saldo disponível | SD3 RE4/999 + DE4/499 do mesmo produto; saldo físico, valor e custo médio dos dois locais |
| `apontar` | OP própria, SD4, SB2 | Consumo RE1/999 no 05, produção PR0/001 no 05/07/10, custos 1–5, baixa de empenhos, C2_QUJE/C2_APRATU1–5/C2_DATRF |

Saldo disponível desconta empenhos de outras OPs, reservas e saldo a classificar.
Apontamentos parciais usam consumo acumulado proporcional; o último consome o
restante, evitando resíduos de quantidade. Ao retirar todo o saldo, transfere-se
seu valor total, incluindo diferenças de arredondamento do custo médio.

Intermediárias são opcionais: gera SC2/SD4 por nível, mesma numeração e sequência
própria, com C2_SEQPAI. Gera a necessidade integral, não apenas a falta de estoque.
Limite de dez níveis e cem OPs por pedido. Produza as intermediárias antes da OP
pai, ou transfira o saldo existente; não há apontamento automático das filhas.

Estoque acabado já existente usa `transferir`, sem criar outra produção.
Etapas, operadores, tempos e preparos/envios locais continuam no fluxo local.
A fila antiga não é enviada automaticamente por este módulo.

## Uso pelo app

1. Entrar como gestão da produção ou administração e abrir **Produção → Operação**.
2. Usar **Gravar produção no DEV**, ou **Registrar OP no DEV** na OP local para preencher produto/quantidade.
3. Selecionar a operação, conferir dados e informar a chave de escrita.
4. **Conferir operação** calcula a prévia em uma transação desfeita com rollback.
5. **Gravar no DEV** revalida saldos/estrutura e grava. A numeração da prévia não é reservada.
6. Guardar a referência completa devolvida para alteração/apontamento.

Pedido sem confirmação permanece salvo localmente, sem a chave. Consultar ou
reenviar o mesmo pedido; nunca gerar outro identificador para repetir uma tentativa
incerta. O app impede outro envio enquanto houver um pendente e verifica a gravação
local antes de enviar. Não apagar o armazenamento do app durante a recuperação.
A OP local usa um identificador determinístico de abertura. Isso não deduplica duas
OPs locais diferentes que representem acidentalmente a mesma intenção de produção.

## Instalação no DEV

**Não executada nesta entrega.** O `.env` real não foi alterado.

1. Reservar `HMLp12` exclusivamente para este teste, com backup restaurável. Desconectar
   AppServer/DBAccess e outros gravadores desta base durante a escrita SQL.
2. Executar [001_sql_production_dev.sql](../../db/sqlserver/001_sql_production_dev.sql)
   em `HMLp12`. Cria apenas `VF_SQL_VERSION`, `VF_SQL_REQUESTS`, `VF_SQL_ORDERS` e
   `VF_SQL_COUNTERS`, sem alterar o schema ERP.
3. Configurar no `api/.env` local:

   ```dotenv
   VF_PROTHEUS_DATABASE=HMLp12
   VF_PROTHEUS_SCHEMA=dbo
   VF_EMPRESA=010
   VF_FILIAL=04
   VF_PROTHEUS_COMPANY_GROUP=01
   VF_SQL_WRITE_ENABLED=true
   VF_SQL_EXCLUSIVE_DEV=true
   VF_SQL_WRITE_TOKEN=<chave-aleatoria-exclusiva>
   ```

   Usar uma chave aleatória exclusiva, diferente da senha SQL e do token de consulta.
   Manter o `VF_API_TOKEN` de consulta para acesso remoto e reiniciar o backend.
   Não embutir a chave de escrita em `--dart-define` nem versioná-la.
4. Consultar `/api/v1/dev/producao-sql/status`. `enabled` informa configuração;
   `connectionVerified=false` indica que esse endpoint não validou banco/migração.
5. Fazer a prévia de um produto simples conhecido, confirmar uma OP pequena e
   comparar SC2/SD4/SB2. Testar transferência e apontamento parcial/final.
6. Desativar `VF_SQL_WRITE_ENABLED` antes de reconectar o Protheus. Reabrir os serviços
   e conferir documentos/saldos no SmartClient. Validar os controles do DBAccess e a
   numeração antes de permitir qualquer gravação nativa posterior.

O backend confere `DB_NAME()` na conexão efetiva, grupo/filial/sufixo configurados,
versão da migração, campos, tamanhos e perfil de RECNO. Recusa triggers ativos não
mapeados. Usa transação serializável, `XACT_ABORT`, trava de aplicação e travas de
tabela. Os RECNOs observados no DEV não são IDENTITY; o módulo usa máximo + 1 sob
trava. **Essas travas não sincronizam caches do DBAccess**: o indicador de exclusividade
é uma declaração operacional, não detecção automática de serviços parados.

Numeração própria `V00001…V99999` para OPs e `X00001…X99999` para movimentos, sem
reutilizar chaves existentes, inclusive registros excluídos. Não manipula SX8/SXE/SXF.
O diário e a OP/empenhos/movimentos fazem parte da mesma transação. Falha de commit
ou perda de conexão não retorna sucesso; consultar pelo identificador.

Para parar, desativar a flag e reiniciar a API. **Não apagar diário/counters** depois
de usar: são necessários para idempotência e recuperação. Não há rollback de negócio
nem estorno implementado; restaurar um backup de homologação é uma ação separada.

## Contrato HTTP

Prefixo `/api/v1/dev/producao-sql`. `status` usa o token normal; POST/consulta de pedido
também exigem `X-VettiFlow-Write-Key`. Campos desconhecidos são recusados. Não há
endpoint que receba SQL arbitrário. Valores usam parâmetros e tabelas/campos permitidos.

Exemplo de abertura (usar a data corrente):

```json
{
  "id": "abertura-local-001",
  "operacao": "abrir",
  "autor": "Tatiane",
  "data": "2026-09-28",
  "entrega": "2026-10-10",
  "produto": "CODIGO-REAL",
  "quantidade": "10",
  "gerarIntermediarias": false,
  "simular": true
}
```

Para gravar, repetir o mesmo corpo com `simular=false`. `GET /comandos/{id}` recupera
o recibo. Mesmo ID e mesmos dados retornam o recibo anterior, inclusive em outro dia;
ID reutilizado com dados diferentes dá conflito. Novos movimentos aceitam somente hoje.
O autor é um rótulo declarado pelo cliente; a chave compartilhada não autentica
individualmente Tatiane. A restrição de gestor na interface não substitui isso.

Demais campos: `alterar` usa `op`, `novaQuantidade`, `entrega` opcional;
`transferir` usa `produtoTransferido`, `quantidadeTransferida`, `origem`, `destino`;
`apontar` usa `op`, `quantidadeApontada`, `destino`. Locais aceitos: 01/05/07/10;
destino de produção: 05/07/10. Quantidades positivas com até seis casas decimais.

## Limites concretos

- Só altera/aponta OP criada por este módulo, com manifesto próprio; divergências
  de quantidades, produtos, locais e empenhos interrompem a operação.
- Não altera quantidade depois de apontar nem replaneja conjuntos com intermediárias.
- Sem lote/série, endereço, segunda unidade, perdas, opcionais, revisão específica,
  fantasma, mão de obra/serviço ou consumo em local diferente do 05.
- Não implementa cancelamento/estorno, troca de código em transferência, desmontagem,
  saldo de terceiros, fiscal/contábil, fechamento/reprocessamento de custo ou todos
  os pontos de entrada/gatilhos/validações do Protheus.
- Sem uso simultâneo com o AppServer/DBAccess, sem habilitação em produção e sem
  certificação de equivalência ao ExecAuto. Homologação real ainda pendente.

## Evidência da implementação

Testes Python cobrem regras com banco transacional em memória, API com TestClient e
contratos do driver com conexão simulada. Testes Flutter exercitam as quatro telas
de comando, confirmação, autorização local, persistência e recuperação após falhas.
**Isso não equivale a executar transações num SQL Server ou testar no SmartClient.**

Checkpoints TDD locais: `f7cdc3b` → `e394c63` (núcleo), `81175ea`/`b220255` →
`4a6e7e6` (API/adapter), `15bdd75` → `0be3b10` (interface), `3a10e0a` → `9ddfe62`
(resíduo de custo, repetição em outro dia e persistência), `f59b053` → `de46c0e`
(local de consumo, rastreabilidade do empenho e health), `9bbc757` → correção de
persistência do recibo (mantém o pedido recuperável quando o disco falha).

Validação registrada: suíte Python 129 testes passando; módulo SQL com 91% de
cobertura de linhas. Flutter: 15 testes do módulo passando; repositório 96% e tela
91% de cobertura de linhas. Análise estática sem problemas. A suíte Flutter geral
executada com os primeiros 14 testes novos terminou em 187 aprovados e 42 falhas;
os nomes das 42 falhas coincidem exatamente com o baseline anterior. O 15º teste,
de persistência do recibo, passou junto com os outros 14 após a última correção.
Auditoria de dependências Python sem vulnerabilidades conhecidas.
