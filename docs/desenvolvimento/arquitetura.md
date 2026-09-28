# Arquitetura atual

Referência: 28/09/2026.

```text
Flutter ── consultas HTTP com token ── FastAPI ── SELECT ── SQL Server DEV
   └──── fluxo operacional local (separado dos documentos oficiais)
   └──── comandos explícitos + chave de escrita ── transação SQL DEV
```

## Componentes

| Camada | Código | Responsabilidade |
|---|---|---|
| Inicialização e dependências | lib/app/vetti_flow_app.dart | Providers e repositórios |
| Navegação | lib/app/app_routes.dart | Rotas operacionais e administrativa |
| Painel | FlowOpRepository + DashboardCubit | Projeta o fluxo local na gestão |
| Operação | ProductionFlowStore | Etapas, tempos, defeitos e quantidades locais |
| Consulta ERP | api/app/main.py, mssql.py, warehouse.py | Leitura parametrizada |
| Escrita SQL DEV | sql_production.py, sql_production_db.py, sql_production_api.py | Abertura, alteração, transferência e apontamento; desligada por padrão |
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
- Homologação do [fluxo SQL DEV](sql-producao-dev.md) no SQL Server e no SmartClient. A implementação tem testes isolados; ainda não foi executada contra as tabelas reais. A pesquisa ADVPL permanece como referência, não como garantia de equivalência ao ExecAuto.

## Validação

Na raiz:
```powershell
flutter analyze --no-pub lib test
flutter test --no-pub
.\api\venv\Scripts\python.exe -m pytest api/tests -q
```

As fontes ADVPL fornecidas pelo usuário foram copiadas da VM da Vetti e são referência das customizações. A análise atual foi estática, sem compilação ou execução no ERP.
