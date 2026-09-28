# SMD

Rota: `/smd`. Armazém **03**, filial **04**. A tela segue o mesmo cabeçalho, painéis e filtros do almoxarifado.

## Como usar

1. Abra **OPs** para ver as ordens oficiais em aberto. Cada cartão mostra planejado, produzido e restante. A situação permite consultar também encerradas.
2. Abra uma OP para conferir seus empenhos e movimentos no Protheus, inclusive componentes de outros locais quando vinculados à OP.
3. Em **Apontamentos**, confira produção e estornos, com quantidade, data, OP e usuário do movimento.
4. Em **Consumo**, confira baixas e devoluções de componentes. **Movimentações** reúne também transferências, ajustes e demais registros do local.
5. Em **Estoque**, consulte os saldos atuais de componentes e produtos do SMD.

O padrão é **Todo o período**. Clique no período para escolher **mês e ano**, ou **Personalizar** para um intervalo. No celular, abra **Filtros**. A seleção é mantida entre abas e volta à primeira página quando muda.

Nas OPs, o filtro usa a **emissão da OP**; nos apontamentos e consumos, a **data do movimento**. Assim, uma OP antiga ainda aberta pode não aparecer ao selecionar um mês recente: use todo o período para ver toda a fila. Estoque é saldo atual, sem reconstrução histórica.

A consulta carrega 50 registros por página, com opções de 20 ou 100. O indicador de último registro considera todos os locais e filiais das tabelas consultadas na empresa do DEV, independente do filtro.

## O que foi confirmado sobre a Paula

O login Protheus `paulad` corresponde à Paula. Desde 24/06/2026, foram encontrados **59 registros de produção e 1.970 de consumo**, em 37 OPs, sem transferências desse login. O fonte Vetti RPCPA001 chama **MATA250** para apontar e valida a quantidade restante; o DEV tem parâmetros compatíveis com consumo no apontamento.

Isso sustenta uma tela focada em apontamentos. Não prova que Paula só tenha essa permissão ou que use exclusivamente essa tela ADVPL. A consulta mostra o setor completo, incluindo registros de outros usuários. Veja a [auditoria e os limites da evidência](../../auditorias/2026-09-24/smd-apontamentos.md).

## O que a tela faz no ERP

**Somente leitura.** Não aponta, consome, transfere, estorna ou encerra OPs. A entrada do produto e a baixa de componentes mostradas aqui já foram registradas no Protheus.

A consulta principal mostra OPs da SC2. No cabeçalho, **Apontar no VettiFlow** abre a operação local descrita abaixo; seus registros não são lançamentos oficiais do ERP.

## Apontamentos no VettiFlow

Rota: `/smd/apontar`, acessível pelo cabeçalho de `/smd`.

1. **Em SMD** mostra apenas as OPs locais que chegaram à etapa SMD. **Programadas** mostra as que ainda têm etapas anteriores. Uma rota sem SMD não aparece nessas filas.
2. Em **Apontar produção**, informe a quantidade produzida agora. O app soma os apontamentos válidos e mostra planejado, apontado e restante. Aceita parciais e frações, sem ultrapassar o saldo da OP. Não usa a quantidade entregue pelo almoxarifado como quantidade produzida.
3. Em **Histórico**, consulte data, quantidade, nome do operador e observação. Antes de concluir o SMD, é possível anular um apontamento com motivo: o original permanece e uma correção vinculada devolve a quantidade ao saldo.
4. Ao atingir o total, **Concluir SMD** mostra a próxima etapa e pede a confirmação local. Segue a rota escolhida, inclusive quando termina no SMD; não insere gravação ou expedição. Apontar todo o saldo não conclui a etapa automaticamente. Retrabalho após a conclusão precisa de nova programação, sem apagar o histórico.
5. Escolha mês ou intervalo nos filtros. Nas filas, a data é a criação da OP; no histórico, é a data do apontamento/correção. O padrão é todo o período e há 20 registros por página.

A conta do SMD e os administradores podem apontar. Consultas e relatórios do SMD exigem perfil de gestor ou liberação de Paula em **Colaboradores → Acesso ao setor**. A gestão da produção mantém consulta ao SMD, sem apontamento. Paula abre **Colaboradores** pelo menu da conta, sem precisar entrar no painel de produção. Não há criação de OP nessa página. A aplicação ainda usa autenticação e permissões locais; isso não equivale a autorização por usuário no servidor do Protheus.

Quando houver pedidos do armazém 01 ligados à mesma OP, o cartão mostra as entregas registradas e seus destinos originais. É uma consulta do atendimento: não comprova recebimento no SMD, não faz reserva/baixa e não bloqueia apontamentos automaticamente por material pendente.

Os apontamentos ficam no cache local das OPs **neste navegador**, sem backend compartilhado entre computadores. Os novos registros guardam nomes, sem PIN. Não importam OPs do DEV para a fila local, não chamam MATA250/MATA685 e não atualizam SC2/SD3/estoque. O registro de quantidade não cria duração de trabalho nem produtividade por hora. Tempos já medidos no fluxo anterior são preservados.

O PDF de movimentações continua usando os dados oficiais; os apontamentos locais ainda não entram nesse PDF. Após o SMD, a OP segue para a etapa programada, já conectada à operação local da produção e aos destinos suporte/expedição. O botão **Materiais do setor** abre `/smd/materiais`: Paula consulta pedidos/entregas, e a administração pode registrar a conferência; não foram adicionadas movimentações de material à conta da Paula.

Verificação pontual: `test/smd_pointing_test.dart` cobre parciais, limite, idempotência, correção, persistência, recuperação de falha, SMD opcional, rota de saída e interface desktop/celular.

## Próximas entregas

- Apontamento de quantidade parcial pela rotina oficial, após validar o contrato completo, retornos, erros, duplicidade e estorno.
- Validar uso de perdas pela Paula: RPCPA001 contém MATA685, mas a existência do código não confirma uso real.
- Relatório próprio dos apontamentos locais, separado dos movimentos oficiais.
- Backend compartilhado e conciliação dos materiais locais com os movimentos oficiais.

Código: [SMD](../../../lib/ui/smd/smd_page.dart), [consulta compartilhada](../../../lib/ui/warehouse/warehouse_read_page.dart), [filtro mensal](../../../lib/ui/shared/widgets/read_period_filter.dart).


## Relatório de movimentações

Disponível em `/smd/relatorios`, pelo botão de relatório da tela ou pela aba Relatórios do painel. Escopo: 03; apontamentos selecionados inicialmente, com os demais movimentos disponíveis. Usa a mesma base do almoxarifado: mês/período, tipo, produto, OP, usuário e códigos; prévia, resumo, evolução e PDF com detalhe opcional. Totais abrangem o recorte completo; detalhe limitado a 1.000 registros e 60 páginas, com aviso para refinar ou gerar resumo. Somente leitura do DEV.

[Regras e verificação da ampliação](https://github.com/LeoMorais0930/vettiflow-flutter-app/blob/8329fe3a23a2b12d98d63ab71ad405469b124a0b/docs/testing/relatorios-setores.md).
