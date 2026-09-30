# Revisão e exclusão de empenhos — integração para homologação DEV

A tela **Gerenciar empenhos desta OP** já consulta linhas reais, salva a revisão
no VettiFlow e envia explicitamente as exclusões para a fila ADVPL. MOD começa
visível, fica separado e não é excluído por este fluxo.

## Caminho implementado

1. A OP é criada pela MATA650, sem OPs intermediárias nem SCs automáticas,
   mantendo a geração de empenhos da OP principal.
2. Após a confirmação da OP, o usuário abre a lista de empenhos. Também pode
   abri-la pelo detalhe da OP ou por Minhas solicitações ADVPL.
3. Marca **Excluir**, informa o motivo e pode usar **Desfazer** antes do envio.
4. **Salvar revisão** salva somente o rascunho no banco próprio do VettiFlow.
5. **Enviar ao Protheus** apresenta a lista e pede **Confirmar envio**.
6. A API revalida a revisão, a permissão e os dados atuais. Enfileira uma
   `exclusao_empenhos` com identidade estável; repetir após timeout devolve o
   mesmo pedido. Uma revisão em andamento bloqueia outra para a mesma OP.
7. No DEV, `U_VFFILA01` reserva o pedido e chama `U_VFEMP01`.
8. O executor compara OP, linhas, quantidades e chaves com o estado revisado,
   adquire locks e chama MATA381 com operação **4**, `LINPOS` e `AUTDELETA="S"`
   somente para as linhas marcadas. Não usa exclusão da OP inteira (operação 5).
9. Confere as linhas remanescentes antes de concluir a transação. A API faz
   outra leitura da SC2/SD4 antes de classificar o pedido como `aplicada`.

Não há DELETE/UPDATE direto no SQL do ERP. Os motivos, o solicitante autenticado,
a versão revisada e o executor autenticado ficam registrados na fila. A revisão
salva não cancela uma solicitação já enviada. Rejeição, divergência ou perda de
retorno não autorizam nova execução automática.

## Compilar na VM

Compilar **VFFILA01.prw e VFEMP01.prw** no mesmo RPO de **P12DEV/P12REST**, com
includes da versão instalada. O código recusa outros ambientes e grupo/filial
fora de 01/04. Não foi compilado nem executado no AppServer nesta entrega.

O consumidor ainda é uma opção de menu, um pedido por vez com confirmação.
Compilar não cria um job e não inicia processamento automático em segundo plano.
Ele executa no contexto do usuário logado no Protheus; o solicitante Flutter e o
executor são registrados separadamente. Não há impersonação do solicitante.

## Configuração para o teste acompanhado

Na API, após revisar a conexão com a mesma base DEV do AppServer:

```dotenv
VF_QUEUE_ENABLED=true
VF_QUEUE_OPERATIONS=abertura_op,exclusao_empenhos
VF_QUEUE_EXECUTION_ENABLED=true
VF_QUEUE_CONSUMER_TOKEN=<chave privada do consumidor>
```

Manter as escritas SQL diretas desativadas. As configurações ativas da máquina
não foram liberadas automaticamente por esta implementação.

No appserver.ini DEV:

```ini
[VETTIFLOW]
Url=http://servidor-da-api:8000/api/v1
ConsumerKey=<mesma chave privada>
ApiToken=<chave da API>
SessionToken=<JWT temporário de login do executor no VettiFlow>
```

O JWT também pode ser passado como parâmetro `cSessionToken` de `U_VFFILA01`,
sem gravá-lo no ini. Não versionar tokens. Para este teste manual, fazer login
na API e fornecer um JWT ativo do mesmo usuário do menu. JWT expirado ou sessão
perdida após reinício da API exige novo login; não há renovação automática do
JWT no consumidor ADVPL. Remover o token temporário do ini ao terminar.
Todas as rotas do consumidor continuam exigindo JWT, além das chaves. O fonte
consulta a sessão e compara o usuário antes de reservar. Não existe exceção de
autenticação para o consumidor.

## Homologação necessária na VM

- Criar OP pequena: somente principal, SD4 gerada e nenhuma intermediária/SC.
- Excluir uma linha; conferir que outra linha do mesmo produto em outro lote,
  os demais componentes e MOD continuam intactos.
- Conferir reflexos nativos em saldos, lotes/endereço e pontos de entrada Vetti.
- Alterar o empenho entre revisão e execução: rejeitar sem excluir.
- Testar OP encerrada, permissões do menu e erro de ExecAuto, validando rollback.
- Testar chave LINPOS ambígua e linhas com lote/endereço: API recusa duplicidade
  da chave nativa; confirmar comportamento no RPO instalado.
- Repetir envio/reserva e simular queda de retorno: não executar duas vezes.
- Conferir situação `incerta` manualmente. Não reenfileirar automaticamente.
- Validar locks e concorrência com as rotinas já utilizadas na Vetti.

Referência técnica: [TOTVS — ExecAuto MATA381](https://tdn.totvs.com/pages/viewpage.action?pageId=415699242).
