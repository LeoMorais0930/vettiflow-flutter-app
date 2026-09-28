# Integração de escrita sem endpoint TOTVS pronto

Análise estática em 28/09/2026. Nenhuma rotina executada, fonte compilado ou tabela remota alterada. A existência de um fonte local não comprova que essa revisão esteja no RPO ativo.

## Conclusão

É tecnicamente viável construir uma integração própria usando os fontes customizados e as rotinas instaladas. A opção inicial recomendada é uma fila do VettiFlow consumida por uma rotina ADVPL executada dentro do Protheus. Isso dispensa um endpoint REST de entrada da TOTVS. Não comprova ausência de consumo de licenças: execução interativa e agendamento precisam funcionar no ambiente disponível.

A pasta analisada contém customizações; não foi encontrada nela a implementação padrão de MATA650, MATA250 ou MATA261. Portanto, não temos evidência para afirmar que possuímos todo o código necessário para reproduzir o ERP em SQL.

Raiz dos fontes: `C:/Users/Leonardo Morais/Desktop/vetti/VettiFlow/protheus_advpl/vettip12`.

## Evidências concretas nos fontes

| Fonte e linha | Comportamento observado | Aplicação no VettiFlow |
|---|---|---|
| `pcp/atualizacao/RPCPA001.prw:167–217` | ApontarPro valida OP, armazém e quantidade; monta D3_OP, D3_COD, D3_QUANT, D3_LOCAL, D3_TM=001 e D3_QTMAIOR; chama MATA250 por ExecAuto na linha 212 | Extrair a lógica para função com argumentos explícitos e retorno estruturado; substituir MsgYesNo/MostraErro e variáveis de tela |
| `pcp/execblock/RPCPE002.prw:89–143` | Monta origem/destino, chama MATA261; após sucesso preenche C2_3Envio por RecLock | Reutilizar o formato e a regra pertinente ao fluxo; revisar endereços fixos ENDER01/ENDER02 e campos de lote vazios |
| `estoque/atualizacao/RESTA003.PRW:224` | Chama MATA241 por ExecAuto | Referência para movimentos internos; exige mapear cabeçalho, itens e TM específicos antes de adaptar |
| `pcp/ponto de entrada/MTA650I.prw:25–28` | Altera C2_VOP e C2_VGRU por RecLock | Preservar campos específicos da Vetti na abertura |
| `pcp/ponto de entrada/A650LEMP.prw` | Retorna C2_LOCAL como armazém do empenho; comentário vincula execução à tela | Verificar comportamento automático e reproduzir a regra pelo mecanismo suportado se o ponto não executar |
| `pcp/atualizacao/RPCPA002.prw:74–109` | Insere SD3 por RecLock para componentes MOD, tipo MO, TM 999, local 10; calcula custo com B2_CM1 | É uma customização delimitada, não uma implementação completa de apontamento ou atualização de estoque |
| `estoque/atualizacao/RESTA001.prw:196–215` | Cria registro SB2 ausente, preenchendo produto, filial, local e custos zero | Demonstra inclusão de registro pelo ambiente ADVPL, não movimentação de saldo |
| `estoque/atualizacao/RESTA011.prw:575–591` | Tenta UPDATE SQL em SZ4/SZ5 | Não copiar: a segunda query é montada em cQryUpdSz4, mas executada com cQryUpdSz5 vazio; usa D_E_L_E_T em vez do campo padrão D_E_L_E_T_ |

Outro trecho de RESTA011, linhas 518–527, passa campos Z5 e valores de teste para MATA010 com opção 4, apesar do comentário mencionar inclusão. Não é um exemplo confiável para integração genérica.

## Qual mecanismo usar para cada escrita

1. **Dados próprios do VettiFlow:** INSERT/UPDATE parametrizados no banco próprio, incluindo fila, status, etapas e histórico. Não há necessidade de envolver rotina ERP para esses registros.
2. **Abertura/alteração de OP:** MATA650 via ExecAuto. A documentação apresenta inclusão, alteração e exclusão; para alterar/excluir exige posicionar SC2. Quantidade, estrutura e empenhos devem ser conferidos em conjunto: trocar um campo não demonstra que todos os efeitos ocorreram.
3. **Apontamento, transferência e movimentos:** adaptar MATA250, MATA261 e MATA241 conforme os exemplos locais e a operação desejada. Não generalizar códigos de operação ou payloads entre rotinas. Correção de movimento pode exigir estorno e novo lançamento.
4. **Campos customizados e manutenção delimitada:** RecLock com retorno verificado, posicionamento correto e MsUnlock. RecLock trata gravação/bloqueio do registro; não equivale à rotina de negócio completa.
5. **SQL direto em tabelas ERP:** tecnicamente possível com permissão de banco, mas não é equivalente a executar o processo. TCSQLExec não mantém automaticamente os campos de controle DBAccess. Não há evidência suficiente nesta análise para formular INSERT/UPDATE completos de OP/estoque.

## Transporte proposto sem REST TOTVS

Fluxo: Flutter → FastAPI própria → fila persistente do VettiFlow → consumidor ADVPL → rotina ERP → resultado para o VettiFlow.

Primeiro protótipo: comando de menu no Protheus para processar uma solicitação explícita. O consumidor pode buscar solicitações na FastAPI própria, por HTTP de saída; não precisa expor um serviço REST no AppServer. Se a rede não permitir, arquivos de entrada/retorno são alternativa. Só depois de validar o processamento deve-se considerar Schedule, conforme disponibilidade do ambiente. Essa arquitetura é proposta, não um conector já existente.

O contrato da fila deve conter ID único, operação permitida, empresa, filial, dados tipados, solicitante e referência ERP. Não aceitar comandos SQL arbitrários vindos do aplicativo. O consumidor deve verificar quem pode executar a operação; uma conta técnica não deve transformar qualquer usuário do app em operador irrestrito do ERP.

Estados mínimos: pendente, processando, aplicada, rejeitada e resultado_incerto. Reservar um pedido atomicamente impede dois consumidores de executar a mesma solicitação. Se houver queda após a gravação ERP e antes do retorno, conferir a referência e os efeitos antes de reenviar. Um ID na fila sozinho não garante execução única no ERP.

## Adaptação do projeto atual

`api/app/warehouse_writes.py` hoje depende de um serviço com `/capabilities` e `/orders`, um contrato proposto que não foi encontrado pronto no servidor. O transporte por fila substituiria essa dependência. O registro local de envios pode fornecer parte da base, mas não implementa sozinho reserva de pedidos, consumo ADVPL e recuperação de resultados incertos.

Preservar a consulta SQL existente. Separar a execução ADVPL da interface: argumentos explícitos, sem confirmação visual, captura de lMsErroAuto/GetAutoGRLog e retorno com referência completa. Confirmar empresa/filial/banco efetivos antes de consumir pedidos; o histórico local registra diferenças entre RootPath do REST e do DEV.

## Primeiro teste que decide a viabilidade

Compilar uma rotina pequena no ambiente de desenvolvimento e executar, pelo menu, uma única abertura com MATA650. Comparar com uma abertura manual equivalente: SC2, empenhos SD4, armazém dos componentes, campos C2_VOP/C2_VGRU e possíveis ordens intermediárias. Depois testar alteração suportada, rejeição e repetição do mesmo ID. A execução real ainda não foi feita; a presença dos fontes não confirma compilação, disponibilidade de licença, permissões ou comportamento do RPO atual.

## Referências consultadas

- [MATA650 — ExecAuto e opções](https://tdn.totvs.com/x/Q9vTJw): obtido pelo índice de pesquisa; abertura direta retornou 403.
- [RecLock — inclusão, alteração e bloqueio](https://tdn.totvs.com/pages/viewpage.action?pageId=24347041).
- [TCSQLExec — limitações dos campos de controle](https://tdn.totvs.com/display/tec/TCSQLExec): obtido pelo índice de pesquisa; abertura direta retornou 403.
- [Consumo de licença em Webservice, EAI e Schedule](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360018606751-Cross-Segmento-TOTVS-Backoffice-Linha-Protheus-ADVPL-Consumo-de-Licen%C3%A7a-Webservice-EAI-e-SCHEDULE): Schedule consome conforme a rotina; não assumir execução gratuita por eliminar REST.
- [Correção de empenhos MATA650 com Begin Transaction](https://tdn.totvs.com/pages/viewpage.action?pageId=745141044): evidencia dependência da revisão instalada; envolver uma chamada em transação não substitui verificar os efeitos.

Não foi feita avaliação contratual da licença da Vetti. A pesquisa não demonstra que a ausência do endpoint desejado tenha sido causada por licença.
