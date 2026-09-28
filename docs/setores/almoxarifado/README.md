# Almoxarifado

## Como usar

Abra `/almoxarifado`. A tela fica no armazém **01**, filial **04**, e segue o cabeçalho e os painéis das outras telas. Vera define o acesso às consultas em **Colaboradores → Acesso ao setor**. Luis e os demais operadores começam nas telas de trabalho; consulta e relatórios exigem liberação. Veja a [regra de acesso](../administracao/README.md).

1. Escolha Visão geral, Histórico, Estoque, OPs ou Inventário.
2. Use a busca por produto, OP ou documento. No celular, abra **Filtros**.
3. O padrão é **Todo o período**. Clique no período para escolher **mês e ano**, ou use **Personalizar** para um intervalo. A seleção acompanha a troca de abas.
4. Abra um registro para conferir quantidades, origem/destino e informações do Protheus.

O histórico carrega 50 registros por página, com opções de 20 ou 100. A visão geral mostra oito registros recentes. Nenhuma opção baixa todo o histórico de uma vez.

**Último registro no DEV** considera as datas de SD3, SD1, SD2, SC2 e SB7, em todos os locais e filiais da empresa configurada. Esse indicador independe dos filtros da tela; usa cache de até um minuto. Não representa a última alteração técnica em qualquer tabela do banco.

## O que já funciona

| Aba | Informação |
|---|---|
| Visão geral | Contagem de entradas, saídas, notas sem efeito e registros estornados |
| Histórico | Transferências, consumo, produção, ajustes, desmontagens e notas |
| Estoque | Saldo atual, empenhado, reservado, a classificar, custo e valor |
| OPs | OPs do local, encerramento, empenhos e movimentos |
| Inventário | Contagens registradas no Protheus |

Estoque é a posição atual de SB2; o período não reconstrói saldos passados.
Nas OPs, o mês considera a emissão; no inventário, a data da contagem; nos movimentos, a data do registro (digitação nas notas de entrada).
Movimentos internos mostram o usuário registrado em SD3. O relatório mensal de movimentações está disponível no botão **Relatórios do almoxarifado**.
Transferência de entrada não é automaticamente vinculada a uma remessa anterior.
Inventário registrado não significa que o acerto de estoque já ocorreu.

## Relatórios e PDF

Use o botão de relatório no cabeçalho ou abra `/almoxarifado/relatorios`.
O botão aproveita período e busca da consulta; o acesso direto começa no mês atual.

1. Escolha mês, intervalo ou todo o período. Marque um ou vários tipos de movimento; nenhum marcado significa todos.
2. Refine por código de produto, OP ou usuário. **Mais filtros** contém fonte, sentido, documento, unidade, CF, TM, TES e CFOP. Os campos de código exigem correspondência exata; a busca geral aceita trecho.
3. Para levar os registros ao PDF, marque **Incluir registros no PDF**. Clique em **Aplicar filtros**. No celular, o painel de filtros se recolhe para mostrar o resultado.
4. Confira resumo, evolução e quantidades por produto/unidade. O ícone de filtro junto ao produto prepara esse recorte; aplique novamente para atualizar.
5. Clique em **Gerar PDF**. A prévia permite **Salvar PDF** e **Imprimir**. O arquivo usa exatamente a consulta apresentada; alterar um filtro exige reaplicar antes de exportar.

O resumo conta **todo o recorte**, mesmo com mais de 100 registros. Contagens são registros/itens, não peças nem notas distintas. Quantidades ficam separadas por produto, unidade, natureza, sentido e estorno; não representam um saldo líquido.

O ranking mostra até 100 grupos, informando quantos existem no total. O gráfico mostra até 24 períodos com registro mais recentes. O detalhamento completo aceita até 1.000 linhas e o PDF até 60 páginas. Acima de 1.000 linhas, o app oferece o resumo completo; um arquivo que ultrapasse 60 páginas pede um recorte menor ou resumo. Nenhum PDF detalhado é cortado para caber no limite.

Saldo atual, OPs e inventário continuam nas suas abas e ainda não possuem um modelo próprio de PDF. Os demais setores e o consolidado da gestão já possuem relatórios; comparação entre meses e filtros salvos permanecem pendentes. O relatório atual é apenas leitura do DEV, com a mesma proteção HTTP existente; autorização individual por conta no servidor permanece pendente.

[Especificação e continuação](../../desenvolvimento/relatorios-bi.md) · [Validação](../../testing/relatorios-almoxarifado.tdd.md).

## O que movimenta o Protheus

Esta tela não cria OP, transfere, recebe, dá baixa, estorna nem faz acerto. Ela mostra registros dessas operações.
No Protheus, transferência usa RE4/DE4; produção e consumo aparecem como PR0/RE1; desmontagem usa RE7/DE7 e rateio de custo.
Os detalhes e as evidências estão no [contrato técnico](consulta-tecnica.md) e na [pesquisa das regras](../../pesquisa_protheus_2026-09-24/regras_oficiais_e_contratos.md).

## Pedidos de materiais no VettiFlow

Abra **Pedidos de materiais** no cabeçalho do almoxarifado (`/almoxarifado/materiais`). A consulta do Protheus permanece nas abas existentes.

1. A nova OP aberta pelo planejamento gera pedidos para os materiais com origem no 01. Também inclui materiais de OPs do próprio 01. Quantidade e unidade ficam registradas no pedido, sem arredondar componentes fracionados; mão de obra `MOD` fica de fora.
2. Vera, Luis ou um administrador confirmam a disponibilidade ou informam a falta e seu motivo. Confirmar disponibilidade não é reservar estoque.
3. Registre a quantidade separada. É possível separar em partes, até o total pedido.
4. Registre cada entrega, até o que já foi separado. O app mostra quanto falta e guarda data, responsável, quantidade e observação. Não altera a etapa da OP, nem cria transferência, consumo ou baixa no Protheus.
5. Consulte **Pendentes**, **Indisponíveis**, **Entregues** ou **Todos**. O filtro mensal considera a data de criação do pedido; começa em todo o período para não esconder pendências antigas. São 20 itens por página.

A rota escolhida pela produção aparece no pedido: SMD só consta quando foi escolhido para aquela OP. Entrega de material não é apontamento de produção nem confirmação do recebimento pelo destino. A origem 01 e o destino da solicitação são preservados; não há seleção de armazéns extras nessa tela. Gestores de outros setores podem consultar, mas somente a origem e a administração atendem. OP encerrada ou ausente fica com atendimento bloqueado na tela.

Os registros ficam no navegador/dispositivo atual, inclusive após recarregar, **sem sincronização entre computadores**. Erro de armazenamento aparece na tela e permite tentar salvar novamente. O histórico grava o nome do responsável, sem PIN. Não há importação automática de OPs do DEV, nem reconstrução retroativa dos materiais de OPs antigas a partir do catálogo atual. Pedidos manuais já existentes no painel de responsáveis também aparecem quando a origem é 01; se não possuem unidade, a tela informa isso.

O destino confirma recebimento, registra uso e pode devolver material sem uso. O almoxarifado confirma a chegada da devolução. As quantidades de cada ação são limitadas ao que realmente chegou à etapa anterior; não são saldo oficial do ERP. Paula mantém apenas consulta de materiais do 03; a conferência desse destino fica para administração.

É possível desfazer uma separação ainda não entregue e cancelar o restante não separado, com motivo. Um pedido indisponível também pode ser cancelado, sem inventar uma confirmação de estoque. Entregas e devoluções anteriores permanecem no histórico.

**OPs a liberar** (`/almoxarifado/operacao`) mostra OPs cuja etapa atual é almoxarifado. A liberação exige concluir a entrega ou cancelar o saldo dos pedidos originais da OP; pedidos manuais complementares não bloqueiam. A OP segue para a próxima etapa escolhida, com SMD somente se programado. **Liberadas** guarda data, responsável e destino. Busca, mês e páginas de 20 limitam a listagem.

Os PDFs existentes continuam sendo de movimentações do Protheus; separações, entregas, usos e retornos locais ainda não entram nesses relatórios. Falta persistência compartilhada e conciliação com o ERP.

## Limites e próximos passos

A consulta de vários armazéns fica na [interface administrativa](../administracao/README.md).
A antiga separação permanece no código como `WarehousePickingPage`, sem rota principal. O painel de gestão ainda contém solicitações locais; elas não são documentos oficiais de SZ4/SZ5.
A nova área de pedidos atende esses materiais pelo fluxo local descrito acima, sem reativar o avanço automático da antiga tela.
A escrita futura precisa de um projeto próprio com as rotinas oficiais; não faz parte desta entrega.

Código: [tela](../../../lib/ui/warehouse/warehouse_read_page.dart), [repositório](../../../lib/data/repositories/warehouse_read_repository.dart), [API](../../../api/app/warehouse.py).
