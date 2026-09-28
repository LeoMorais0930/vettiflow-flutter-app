# Padrão visual do VettiFlow

A referência é a interface já existente, não um novo tema.

- Use `VettiTopBar` para marca e título do setor. `AccountMenu` concentra a conta, os setores permitidos, a conexão e a saída, sem sobrepor ícones ao título.
- Use `AppColors` e `AppTheme`; o tema principal utiliza IBM Plex Sans.
- Mantenha painéis claros, bordas discretas, cantos arredondados e hierarquia de títulos.
- Nas consultas, mantenha a ação principal visível e os caminhos secundários em **Mais opções**. Recolha filtros e detalhes; mostre o período e a seleção atual no resumo.
- A consulta usa abas quando há espaço e o seletor **Consultar** em larguras menores. Não corte os nomes das consultas.
- No celular, use a largura disponível sem uma segunda moldura de aparelho. O menu da conta dá acesso aos setores, sem repetir uma lista de atalhos abaixo do cabeçalho.
- Nos relatórios, mantenha período e **Gerar prévia** à vista. **Ajustar filtros** organiza tipos/situação, produto/OP/operador e filtros técnicos em grupos expansíveis.
- Nos cartões de operação, priorize OP, produto, quantidade, etapa e ações. Sequência, tempos, participantes e histórico ficam nos detalhes expansíveis.
- No painel, mantenha a busca visível e agrupe os filtros secundários. O quadro Kanban usa barra de rolagem horizontal visível quando as etapas não cabem na largura disponível.
- Utilize `AppBreakpoints` (600/1024) nas novas telas. Há telas antigas com limites próprios; confira o contexto antes de trocar.
- Strings em pt-BR, ações curtas e rótulos concretos.
- Mostre unidade, quantidade decimal e estado vazio/erro. Não use zero para representar informação que falhou.
- Mantenha detalhes técnicos recolhidos; não esconda informações necessárias para conferir o registro.
- Verifique desktop e mobile com os mesmos componentes do app.

A navegação segue `OperatorAccess`, compartilhado pelo menu, pelas rotas e pelas telas. Consulte a [matriz de acesso](../setores/administracao/README.md). A autorização individual da API ainda precisa ser implementada; os bloqueios atuais são locais.

Fontes do padrão: [tema](../../lib/shared/theme/app_theme.dart), [cores](../../lib/shared/theme/app_colors.dart), [cabeçalho](../../lib/ui/shared/widgets/vetti_top_bar.dart), [breakpoints](../../lib/shared/layout/app_breakpoints.dart).

O guia visual antigo continha contas de demonstração e referências desatualizadas de tipografia e cabeçalho. Foi substituído por este documento, vinculado ao código atual.
