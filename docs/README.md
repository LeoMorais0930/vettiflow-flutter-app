# Documentação do VettiFlow

Atualizado em 28/09/2026. Os guias descrevem o código atual, inclusive o que ainda falta.

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
- [Auditoria do DEV de 24/09](auditorias/2026-09-24/relatorio.md); dados brutos no histórico Git.
- [Regras oficiais e contratos do Protheus](pesquisa_protheus_2026-09-24/regras_oficiais_e_contratos.md).
- [Integração sem API pronta da TOTVS](desenvolvimento/integracao-sem-api-totvs-2026-09-28.md).
- [Preparação de escrita DEV](desenvolvimento/escrita-dev.md).
- [Produção via SQL DEV: implementação e ativação](desenvolvimento/sql-producao-dev.md).
- [Validação, testes e pendências](desenvolvimento/validacao.md).


## Documentação preservada

Mantidos os guias por setor, arquitetura, design, relatórios, preparação de escrita e conclusões das pesquisas Protheus. Removidos relatórios antigos em Word/PDF, imagens renderizadas, capturas, JSONs brutos e registros de sprints. Links para evidências removidas apontam para o commit anterior no GitHub.

Os testes de comportamento, permissões, persistência e contratos da API permanecem no projeto. Falhas conhecidas não foram eliminadas pela remoção de testes.
