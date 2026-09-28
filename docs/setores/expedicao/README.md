# Expedição

Atualizado em 24/09/2026. `/expedicao` consulta o **armazém 10, filial 04**, no
Protheus DEV. Todos os acessos ao ERP são de leitura.

## Consulta principal

| Aba | O que mostra |
|---|---|
| Visão geral | Entradas, saídas, notas sem efeito no estoque e estornos; oito registros recentes |
| Histórico | SD3, SD1 e SD2; transferências, apontamentos, consumo, ajustes, desmontagens e outros |
| Notas | Itens de entrada e saída, juntos ou separados, com TES/CFOP nos detalhes |
| Estoque | Saldo atual SB2, empenhos, reservas e quantidades a classificar |
| OPs | SC2 do 10, planejado, produzido, restante e encerramento; movimentos/empenhos nos detalhes |
| Inventário | Contagens SB7 e suas datas/situações |

O padrão é todo o período. O filtro aceita mês/ano ou intervalo e permanece ao
trocar de aba. Páginas de 20, 50 ou 100 registros são calculadas no servidor.
A data do último registro do DEV considera todos os locais e filiais da empresa
nas fontes consultadas. Estoque é sempre saldo atual, sem reconstrução mensal.

A consulta é do local físico 10: também inclui PR0 de uma OP aberta no 05 quando
a entrada do acabado foi registrada no 10. Não importa todos os movimentos de
uma OP do 10 feitos em outros locais. A aba OPs continua limitada a C2_LOCAL=10.

## Pedido e transporte

Ao abrir um item de nota de saída, o app consulta seu pedido e item em SD2, e
transportadora, volumes/espécies e rastreio registrados em SF2. O cabeçalho é
localizado por filial, documento, série, contraparte, loja e tipo. Mais de um
cabeçalho gera aviso; não se escolhe silenciosamente um registro ambíguo.

O pedido exibido é **D2_PEDIDO do item**, não uma suposição a partir da OP nem
o primeiro pedido gravado no campo customizado do cabeçalho. Os volumes são da
nota inteira, que pode conter outros itens/armazéns. Campos vazios aparecem
como “Não informado”. Rastreio não comprova coleta ou entrega; o registro da
nota também não é uma consulta de autorização na SEFAZ.

O efeito das notas no estoque usa a TES atual (SF4). Exemplo do DEV: faturamento
antecipado TES 609 não movimenta estoque; remessa de entrega futura TES 610
movimenta. Não são tratamentos intercambiáveis.

## Conferência local preservada

O botão **Conferência local** abre `/expedicao/fluxo-local`, com as OPs prontas,
iniciar/pausar, divisão entre despacho e armazenamento e despacho parcial do
saldo local. Há um aviso permanente identificando esse fluxo e um botão para
voltar à consulta do Protheus.

Essa tela não emite nota, não fatura pedido e não altera SB2. A origem acompanha
a sequência da OP, sem presumir “teste aprovado”. Pedido, cliente e transportadora
sem vínculo não são inventados. O saldo local não substitui o oficial.

A conclusão local ainda utiliza a sugestão de destino do acabado e pode bloquear
destino incerto. Os resumos exibidos de despacho são estado da tela; a conciliação
com o documento fiscal e um histórico operacional persistente ainda precisam
de desenvolvimento. Os testes de despacho parcial/total anteriores foram mantidos.

## Evidências e próximos passos

[Auditoria e fontes ADVPL](../../auditorias/2026-09-24/expedicao.md).
[Testes e limites](https://github.com/LeoMorais0930/vettiflow-flutter-app/blob/8329fe3a23a2b12d98d63ab71ad405469b124a0b/docs/testing/expedicao-consulta.tdd.md).

Faltam conciliação entre OP local/pedido/nota/retorno, fila de pedidos ainda não
faturados e confirmação efetiva de coleta/entrega. O PDF mensal dos movimentos oficiais já está disponível. Não há
ação para emitir documento, transferir, desmontar, enviar email ou gravar rastreio
no Protheus. A escrita futura deve seguir as rotinas oficiais e as regras da Vetti.

## Código

- `lib/ui/expedition/expedition_read_page.dart`: entrada principal e atalhos.
- `lib/ui/expedition/expedition_page.dart`: conferência local anterior.
- `lib/ui/warehouse/warehouse_read_page.dart`: layout/filtros e detalhes compartilhados.
- `api/app/warehouse.py`: GET `/api/v1/expedicao` e `/api/v1/expedicao/notas/{recno}`.
- `test/expedition_workspace_test.dart`, `api/tests/test_expedition_read.py`.

O atalho de consulta é visível para gestores e pessoas liberadas por Tatiane em **Colaboradores → Acesso ao setor**. Os demais operadores entram na operação local da expedição. A API mantém
o token global existente, sem autorização individual por setor.


## Relatório de movimentações

Disponível em `/expedicao/relatorios`, pelo botão de relatório da tela ou pela aba Relatórios do painel. Escopo: 10; movimentos internos e itens de notas. Usa a mesma base do almoxarifado: mês/período, tipo, produto, OP, usuário e códigos; prévia, resumo, evolução e PDF com detalhe opcional. Totais abrangem o recorte completo; detalhe limitado a 1.000 registros e 60 páginas, com aviso para refinar ou gerar resumo. Somente leitura do DEV.

[Regras e verificação da ampliação](https://github.com/LeoMorais0930/vettiflow-flutter-app/blob/8329fe3a23a2b12d98d63ab71ad405469b124a0b/docs/testing/relatorios-setores.md).


## Operação local — 25/09/2026

**Operação da expedição** abre `/expedicao/operacao` (o endereço `/expedicao/preparos` continua funcionando). Reúne envios diretos da produção para 10 e os reparados encaminhados pelo suporte. Busca, mês/período e páginas de 20 usam a última movimentação de cada envio.

1. Confirme cada recebimento até a quantidade entregue pela produção ou enviada pelo suporte.
2. Divida o recebido entre **Armazenar** e **Registrar despacho**, em quantidades parciais. Para despachar itens armazenados, use primeiro **Retirar do armazenamento**.
3. O despacho exige referência (pedido, documento ou identificação local) e observação. Esse texto não comprova vínculo fiscal nem confirma coleta/entrega.
4. **Registrar retorno de cliente** limita-se à quantidade já despachada. **Receber retorno de cliente** confirma a chegada e libera a quantidade para novo despacho, armazenamento ou devolução à produção.
5. **Devolver à produção** usa apenas a quantidade disponível. A produção precisa confirmar sua chegada e a etapa de retomada.
6. **Solicitar material** cria pedido complementar ao 01. `/expedicao/materiais` permite receber, registrar uso e devolver materiais.

Quando a última etapa programada é expedição, a OP sai dessa fila ao ter todo o lote armazenado ou despachado, desde que não exista sessão antiga ainda aberta. O armazenamento continua disponível para retiradas e despachos pela nova operação. A conclusão da sequência local não encerra SC2.

O histórico conserva data, responsável, motivo, referência e quantidade. Os saldos de trânsito, disponibilidade, armazenamento e despacho não são somados como se fossem novas peças. O retorno de cliente reduz o total líquido despachado; o histórico mantém os despachos originais.

A conferência antiga continua separada para OPs sem quantidades comprometidas neste fluxo. Os novos eventos ficam neste navegador, sem sincronização entre computadores; não emitem nota, não alteram estoque oficial e não entram no PDF de movimentos do Protheus. [Regras dos envios](../producao/README.md#preparar-envio).
