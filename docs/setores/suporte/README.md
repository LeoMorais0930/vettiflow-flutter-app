# Suporte

Atualizado em 25/09/2026. Rota `/suporte`; Protheus exclusivamente em leitura.

## Como usar

O seletor alterna entre **06 · Assistência técnica** e **07 · Suporte externo**,
conforme o cadastro NNR do DEV. Cada consulta considera o armazém selecionado,
na filial 04. Outros armazéns continuam na consulta administrativa.

| Aba | Conteúdo |
|---|---|
| Visão geral | Contagens de entradas, saídas, notas sem efeito no estoque e estornos; oito registros mais recentes |
| Histórico | Movimentos SD3 e itens de notas SD1/SD2; filtro de transferências, apontamentos, consumo, ajustes, desmontagens e outros |
| Notas | Entradas e saídas fiscais juntas ou separadas; documento, série, contraparte/loja, TES e CFOP nos detalhes |
| Estoque | Saldo atual SB2, empenhos, reservas e quantidades a classificar; filtro de saldo diferente de zero |
| OPs | Ordens SC2 do armazém, com planejado, produzido, restante e encerramento; movimentos e empenhos nos detalhes |
| Inventário | Contagens SB7, data e situação registrada |

Todo o período é o padrão. Também é possível escolher mês/ano ou intervalo.
A escolha permanece ao trocar de aba ou armazém; a página volta à primeira.
O estoque é sempre atual, não um saldo reconstruído do mês escolhido.
Históricos usam páginas de 20, 50 ou 100 registros, com contagem e filtros no
servidor. A última data do DEV considera todas as fontes/filiais/armazéns da
empresa consultada, e não apenas o suporte.

Clique em um registro para ver detalhes e copiar suas referências. Nas
transferências, origem/destino aparecem quando há contraparte única por
filial, documento, data, sequência e estorno; produtos podem ser diferentes.
O fluxo inverso é exibido como outra transferência, sem afirmar que ele
encerra um conserto ou corresponde automaticamente a uma remessa anterior.

## O que o Protheus mostrou

- Transferências entram como DE4 e saem como RE4. Há trânsito com produção,
  expedição, almoxarifado, SMD e entre 06/07.
- Apontamentos PR0 e consumo RE1 existem no histórico completo; nem toda
  entrada de produto no suporte é transferência.
- Há ajustes RE0/DE0 e desmontagens RE7/DE7 no histórico completo. Outros
  códigos, como DE6/RE6, permanecem visíveis sem inventar uma classificação.
- Notas de retorno, conserto, garantia e serviço têm tratamentos distintos.
  O efeito exibido usa **a TES atual**; não prova a configuração histórica.
  Exemplo observado: TES 079 de conserto está com estoque N.
- Há quatro OPs abertas nos dois locais, mas OP não é ordem de serviço.

Evidências, números, autores dos lançamentos e fontes ADVPL estão na
[auditoria do suporte](../../auditorias/2026-09-24/suporte.md).

## Defeitos da produção e limites

O ícone **Defeitos da produção** abre os defeitos anotados nos testes locais do
VettiFlow, com OP, produto, código, descrição e quantidade. A lista continua
visível quando a OP termina: conclusão da OP não comprova reparo. Não representa
entrada física no 06/07 e não é conciliada automaticamente com o Protheus.

O protótipo anterior está preservado em `lib/ui/support/support_demo_page.dart`,
fora das rotas. Seus botões de conferência e requisição não gravavam os dados
necessários para uma operação real. A tela principal não apresenta esses
formulários como operações concluídas.

A operação local abaixo registra recebimento, diagnóstico, reparo, pedidos de
material e devoluções parciais. Ainda falta o vínculo conciliado entre defeito,
remessa, retorno e documento fiscal, além de autenticação e persistência compartilhadas. As antigas tabelas de atendimento/base instalada
encontradas no DEV não foram convertidas em chamados atuais. A escrita futura
deverá executar rotinas oficiais, com regras validadas, nunca gravar diretamente
nas tabelas SQL.

## Código

- `lib/ui/support/support_page.dart`: consulta e acesso aos defeitos locais.
- `lib/ui/warehouse/warehouse_read_page.dart`: layout e filtros compartilhados.
- `lib/data/repositories/warehouse_read_repository.dart`: somente GET.
- `api/app/warehouse.py`: `/api/v1/suporte`, limitado a 06/07, com SELECT e paginação.
- `test/support_workspace_test.dart` e `api/tests/test_support_read.py`: regressões.

O atalho de consulta aparece para gestores e pessoas liberadas por Bruno em **Colaboradores → Acesso ao setor**. Os demais usam a operação local do suporte. Isso é navegação da interface; a API
continua usando o token global existente, sem autorização individual por setor.


## Relatório de movimentações

Disponível em `/suporte/relatorios`, pelo botão de relatório da tela ou pela aba Relatórios do painel. Escopo: 06, 07 ou ambos. Usa a mesma base do almoxarifado: mês/período, tipo, produto, OP, usuário e códigos; prévia, resumo, evolução e PDF com detalhe opcional. Totais abrangem o recorte completo; detalhe limitado a 1.000 registros e 60 páginas, com aviso para refinar ou gerar resumo. Somente leitura do DEV.

[Regras e verificação da ampliação](https://github.com/LeoMorais0930/vettiflow-flutter-app/blob/8329fe3a23a2b12d98d63ab71ad405469b124a0b/docs/testing/relatorios-setores.md).


## Operação local — 25/09/2026

**Operação do suporte** abre `/suporte/operacao` (o endereço `/suporte/preparos` continua funcionando). Busca, mês/período e páginas de 20 acompanham os envios para 06/07. A data filtrada é a última movimentação do envio.

1. **Confirmar recebimento** aceita até o que a produção entregou, inclusive em partes.
2. **Registrar diagnóstico** guarda observação sem movimentar quantidade. **Concluir reparo** indica a quantidade reparada e seu resultado.
3. Devolva à produção peças reparadas ou sem reparo, em ações separadas. A produção confirma a chegada e escolhe a retomada permitida da OP.
4. **Enviar à expedição** usa apenas o saldo reparado; a expedição confirma o recebimento separadamente.
5. **Solicitar material** consulta código/unidade no DEV e cria um pedido local vinculado à OP, vindo do 01. `/suporte/materiais` reúne recebimento, uso e devolução dos materiais. A devolução só termina quando a origem confirma a chegada.

Cada evento guarda quantidade, data, responsável e motivo. Os limites impedem reparar/enviar o que ainda não foi recebido e reaproveitar peças já encaminhadas. A ficha é do envio local; não inventa número de OS, documento fiscal nem vínculo de peça única com ocorrências de defeito.

Tudo fica neste navegador, sem sincronização entre computadores e sem escrita no Protheus. Os PDFs oficiais continuam separados. [Regras dos envios](../producao/README.md#preparar-envio).
