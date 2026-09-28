# Arquitetura atual

Referência: 25/09/2026.

```text
Flutter ── consultas HTTP com token ── FastAPI ── SELECT ── SQL Server DEV
   └──── fluxo operacional local (separado dos documentos oficiais)
```

## Componentes

| Camada | Código | Responsabilidade |
|---|---|---|
| Inicialização e dependências | lib/app/vetti_flow_app.dart | Providers e repositórios |
| Navegação | lib/app/app_routes.dart | Rotas operacionais e administrativa |
| Painel | FlowOpRepository + DashboardCubit | Projeta o fluxo local na gestão |
| Operação | ProductionFlowStore | Etapas, tempos, defeitos e quantidades locais |
| Consulta ERP | api/app/main.py, mssql.py, warehouse.py | Leitura parametrizada |
| Interface comum | VettiTopBar, AppColors, AppTheme | Identidade visual |

## Persistência

O app injeta `EmptyProductionFlowDatabase` e `LocalWarehouseRequestDatabase`; não há banco compartilhado de eventos conectado. Pedidos de materiais usam `LocalJsonPersistence` com gravação local.
O fluxo web é persistido em localStorage. A implementação nativa de `ProductionFlowPersistence` é um stub sem gravação.
Não confundir essa classe com `LocalJsonPersistence`, usada por outros stores e que tem implementação própria para arquivos.

Uma OP local não vira automaticamente uma SC2. Também não há carga automática de todas as OPs oficiais na fila local.

## Consulta do almoxarifado

Datas omitidas significam todo o período, sem corte artificial no ano 2000.
Paginação ocorre no SQL: 50 registros por padrão, no máximo 100 por chamada. A visão geral solicita oito.
A busca e os filtros precedem contagem e paginação. Consultas têm timeout de 30 segundos no driver.
A cobertura de datas agrega SD3/SD1/SD2/SC2/SB7 de todos os locais e filiais da empresa configurada, com cache de 60 segundos.
Não há alteração de índice, estrutura ou configuração no Protheus.

## Pendências que afetam vários setores

- Persistência compartilhada e autorização real por usuário no servidor.
- Importação/conciliação entre OPs locais e oficiais.
- Preservação de decimais nos modelos antigos de produção.
- O pareamento antigo de transferências fora do módulo novo ainda precisa cobrir troca de código.
- Conciliar o fluxo local de entregas, reparos, materiais, despachos e retornos com OPs/documentos oficiais. O protótipo antigo de suporte fica fora das rotas; os novos eventos persistem no navegador.
- Integração de escrita ainda não concluída. A [pesquisa atual](integracao-sem-api-totvs-2026-09-28.md) avalia rotinas ADVPL e limitações de SQL direto; não descreve uma implementação já disponível.

## Validação

Na raiz:
```powershell
flutter analyze --no-pub lib test
flutter test --no-pub
.\api\venv\Scripts\python.exe -m pytest api/tests -q
```

As fontes ADVPL fornecidas pelo usuário foram copiadas da VM da Vetti e são referência das customizações. A análise atual foi estática, sem compilação ou execução no ERP.
