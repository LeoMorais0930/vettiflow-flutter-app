# Documentação do VettiFlow

Atualizado em 25/09/2026. Os guias descrevem o código atual, inclusive o que ainda falta.

## Por setor

| Setor | O que consultar |
|---|---|
| [Almoxarifado](setores/almoxarifado/README.md) | Consulta do DEV, pedidos/retornos de materiais e liberação local de OPs |
| [SMD](setores/smd/README.md) | Consulta do DEV e apontamentos locais, seguindo a sequência escolhida |
| [Produção](setores/producao/README.md) | Etapas, operadores/tempos, envios/retornos por quantidade e consulta do 05 |
| [Expedição](setores/expedicao/README.md) | Consulta do 10, recebimento, armazenamento, despacho e retornos locais |
| [Suporte](setores/suporte/README.md) | Consulta do 06/07, recebimento, diagnóstico, reparo, materiais e devoluções locais |
| [Administração](setores/administracao/README.md) | Painel, equipe e consulta de armazéns |
| [TV](setores/tv/README.md) | Acompanhamento do fluxo local |

## Para continuar o desenvolvimento

- [Arquitetura e limites atuais](desenvolvimento/arquitetura.md).
- [Relatórios por setor, gestão e PDF](desenvolvimento/relatorios-bi.md) — movimentações disponíveis nos cinco setores e no consolidado da gestão; modelos adicionais especificados.
- [Padrão visual](desenvolvimento/design.md).
- [Instalação e endpoints da API](../api/README.md).
- [Auditoria do DEV de 24/09](auditorias/2026-09-24/relatorio.md), com dados reproduzíveis na mesma pasta.
- [Regras oficiais e contratos do Protheus](pesquisa_protheus_2026-09-24/regras_oficiais_e_contratos.md).
- [Evidências dos testes do almoxarifado](testing/almoxarifado-consulta.tdd.md).

Os relatórios datados, o roadmap e as evidências de sprints foram preservados para rastreabilidade.
Se uma descrição antiga divergir do app, use os guias por setor e confira o código atual.
O Protheus continua exclusivamente em leitura; botões operacionais de outros setores podem alterar o estado local do VettiFlow.

## Limpeza de documentos em 24/09/2026

Removidos/substituídos: `PROJETO_FIXO_ATUAL.md`, a documentação de 25/06,
o manual antigo dos colaboradores, o setup duplicado do Vitor, o guia visual
antigo e o README de exemplo dos assets de abertura do iOS.
O conteúdo ainda útil foi consolidado no README principal, na API e nos guias
por setor. O contrato do almoxarifado foi movido para sua pasta.

Preservados: `AGENTS.md`, pesquisas oficiais, auditorias e suas evidências,
roadmap histórico e relatórios de testes. Não houve limpeza de código, banco
ou arquivos de configuração privada.
