# Almoxarifado — consultas do Protheus

Implementação de 24/09/2026, restrita à visualização. Nenhuma rotina ADVPL é
executada e nenhum saldo, documento, OP ou empenho do Protheus é alterado.

## Acesso e navegação

- A rota `/almoxarifado` abre a nova tela. Vera e Luis já possuem perfis de
  almoxarifado; suas credenciais não foram alteradas.
- O painel desktop e mobile oferece **Almoxarifado** para gestores e operadores
  do almoxarifado, e **Consulta administrativa** para o administrador do sistema.
  Trata-se de navegação com os perfis existentes,
  não de um novo sistema de autenticação/autorização por usuário no servidor.
- Cinco abas: Visão geral, Histórico, Estoque, OPs e Inventário.
- Armazém fixo 01 e filial 04 na consulta comum. A rota separada `/admin/armazens`
  atende o perfil administrativo do sistema com os locais 01, 03, 05, 06, 07 e 10.
- Todo o período é o padrão: datas omitidas não criam corte artificial. Busca
  no servidor e páginas de 20, 50 (padrão) ou 100 registros. Filtros precedem
  contagem e paginação. A visão geral mostra oito registros recentes.
- A data mais recente do DEV considera SD3/SD1/SD2/SC2/SB7 em todos os locais
  e filiais da empresa configurada, sem os filtros da tela, com cache de 60 s.
- Cabeçalho VettiTopBar, painéis e moldura mobile seguem o restante do app.
- Registros abrem detalhes copiáveis; informações técnicas ficam recolhidas.

## Cobertura

| Consulta | Fonte | Comportamento |
|---|---|---|
| Transferências, consumo, produção, ajustes, desmontagem e outros movimentos | SD3 | CF/TM, documento, OP, motivo SZ1, unidade, quantidade decimal, estorno, lote/série/endereço e rateio |
| Notas de entrada | SD1 + SF4 | Data de digitação, TES, CFOP, contraparte/loja e efeito conforme cadastro atual da TES |
| Notas de saída | SD2 + SF4 | Data de emissão, TES, CFOP, contraparte/loja e efeito conforme cadastro atual da TES |
| Estoque | SB2 + SB1 | Saldo atual, empenhado, reservado, a classificar, unidade, custo médio e valor em moeda 1 |
| OPs do local | SC2 | Emissão, quantidade prevista/produzida, prazo, encerramento e campos de terceiro |
| Detalhes da OP | Endpoint existente SC2/SD4/SD3 | Empenhos originais/restantes e movimentos oficiais |
| Inventário | SB7 | Contagens, documento, status cadastrado e rastreabilidade; não confunde contagem com acerto |

As contrapartes das transferências são identificadas por filial + documento +
data + sequência + marca de estorno, com CF oposto. Produto não integra essa
chave: há transferências reais com troca de código. Se não houver exatamente
uma contraparte, a tela pede conferência em vez de inventar origem/destino.

Os detalhes de transferência/desmontagem consultam os registros relacionados
da mesma sequência, inclusive em outro armazém. Entradas DE7 podem vir de uma
saída RE7 do local 05 ou 10. Registros de mão de obra são identificados na tela.

O resumo conta registros, não soma quantidades de produtos/unidades diferentes.
Notas sem atualização de estoque ficam separadas. A TES atual não é uma prova
da configuração que existia na data de emissão. SB2 é posição atual: o filtro
de período não se aplica à aba Estoque. Saldo atual não recebe o nome de saldo
livre; compromissos são mostrados separadamente.

## API

`GET /api/v1/almoxarifado`

Parâmetros: `view` (overview/history/stock/orders/inventory), `filial`, `local`,
`start`, `end` (ISO), `query`, `kind`, `status`, `page`, `page_size` (até 100).

`GET /api/v1/almoxarifado/movimentos/{recno}?filial=04`

As rotas utilizam a proteção de token já existente. Só emitem SELECT, com
valores parametrizados, tabelas configuradas pelo backend e limite de tempo.
Erros do driver/conexão não são enviados à interface. Os endpoints existentes
de escrita continuam bloqueados.

Para usar a mudança em uma instalação que já esteja rodando, reiniciar a API
com o código atualizado e executar/recompilar o aplicativo com a URL e o token
que já são usados nessa instalação. Não houve publicação nem reinício de VM.

## Limites do que os dados permitem afirmar

- SZ4/SZ5 não foram encontradas na base DEV consultada: não foi inventado um
  histórico de solicitações do Protheus. Solicitações locais do app continuam
  sendo um fluxo separado; não são apresentadas como documentos oficiais.
- O retorno de material é exibido como transferência de entrada. Não é ligado
  automaticamente a uma remessa anterior sem referência suficiente.
- O fonte legado da separação foi preservado como `WarehousePickingPage`,
  sem rota na nova tela. A rota principal de almoxarifado agora é somente leitura.
- Não foram ativados criação de OP, transferência, recebimento fiscal, acerto,
  estorno, baixa ou gravação de solicitações. São operações fora deste escopo
  de visualização, embora seus registros oficiais possam ser consultados.
- Esta entrega não corrige todos os modelos dos outros setores: a nova leitura
  preserva decimais e contrapartes sem reutilizar conversões/pareamentos antigos.

## Conferência no DEV

Consultas somente leitura em HMLp12, filial 04, local 01, período 24/06–24/09/2026:

- 2.837 registros históricos: 1.879 SD3 + 955 SD1 + 3 SD2.
- SD3: 1.823 saídas e 37 entradas de transferência, 8 consumos, 2 produções,
  5 ajustes de entrada e 4 entradas de desmontagem.
- SD1: 242 registros com TES estoque=S e 713 sem efeito pelo cadastro atual.
- 2.554 registros SB2, dos quais 334 com saldo diferente de zero.
- 3 OPs emitidas no local, uma em aberto; nenhuma contagem SB7 no período.
- Consulta relacionada de desmontagem conferida com saída no 05 e entradas
  nos locais 05 e 01.

Valores representam o instante da verificação, não números fixos da interface.

## Conferência de todo o período em 24/09/2026

No local 01: 114.122 registros de histórico, 2.554 registros de estoque,
621 OPs e 5.101 contagens de inventário. A consulta carregou 50 itens por aba
(oito na visão geral), sem carregar os demais registros no aplicativo.

Cobertura das cinco fontes, todos os locais/filiais da empresa: 13/01/2020 a
18/09/2026. O resumo inicial levou 7,38 s; a página de histórico levou 4,81 s;
as demais abas levaram menos de 0,2 s nessa verificação. Tempos não são SLA.

A separação administrativa é de interface; a API conserva o token compartilhado
atual e não identifica individualmente cada usuário.
