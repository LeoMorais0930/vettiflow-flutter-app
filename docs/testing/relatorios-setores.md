# Relatórios dos setores — 24/09/2026

Ampliação autorizada usando a base do almoxarifado. O usuário pediu verificações leves e reservou a avaliação das telas para seu próprio uso; não foi rodada a suíte completa, cobertura, teste de carga ou uma nova campanha de PDFs.

## Entrega

- Uma tela, um contrato e um gerador PDF para almoxarifado, SMD, produção, suporte, expedição e gestão.
- SMD abre com apontamentos selecionados na rota direta; permite consultar os outros movimentos. A abertura pelas telas herda os filtros de histórico quando aplicáveis.
- Produção inclui histórico físico do 05 e SD3 vinculado às OPs do 05. O local efetivo aparece nos registros e agrupamentos.
- Suporte permite 06, 07 ou ambos. Gestão permite selecionar os seis armazéns físicos, sem duplicar o mesmo registro por contexto de OP.
- Entrada pela ação de relatórios em cada setor e pela aba Relatórios do painel. Gestores setoriais recebem os atalhos do setor; gestão geral recebe também o consolidado. Os indicadores locais existentes permanecem identificados separadamente.
- Mesmos limites de 1.000 registros/60 páginas no detalhe, 100 grupos no ranking e 120 períodos na série. Recorte completo nos totais. Somente SELECT.

## Verificação leve

Análise estática dos arquivos alterados sem problemas. Testes focados: 16 Python e 6 Flutter aprovados. Casos adicionais cobrem lista de armazéns, rejeição de locais fora do setor, múltipla seleção sem duplicatas, vínculo de OP exclusivo da produção e agregação por armazém. Build web e consultas HTTP locais atualizados.

Conferência visual pontual no navegador: SMD abriu com Apontamentos, retornou 9 registros de setembro e gerou prévia PDF de 4 páginas com nome do setor, filtro, local 03 e os mesmos totais. Não foi repetida a navegação completa em todos os setores.

Uma consulta resumida de setembro/2026 por endpoint retornou:

| Contexto | Registros | Locais físicos |
|---|---:|---|
| SMD | 396 | 03: 396 |
| Produção | 678 | 05: 657; 07: 1; 10: 20 |
| Suporte | 263 | 06: 87; 07: 176 |
| Expedição | 1.056 | 10: 1.056 |
| Gestão | 2.876 | 01: 504; 03: 396; 05: 657; 06: 87; 07: 176; 10: 1.056 |

Os 21 registros da produção em 07/10 já pertencem aos locais físicos da gestão. Não somar novamente os totais dos contextos de setor. São registros, não peças nem transferências empresariais.

## Ainda fora desta entrega

Relatórios próprios de estoque atual, OPs, inventário, rastreio/pedidos, comparações entre meses e filtros salvos. Autorização individual no servidor continua pendente; a proteção atual da API é a configuração de token/loopback existente. A geração/prévia do PDF mantém a base validada anteriormente; download no navegador interno e impressão física permanecem com as limitações registradas na verificação do almoxarifado.
