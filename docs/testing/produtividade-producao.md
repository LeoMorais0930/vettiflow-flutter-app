# Produtividade da produção — 24/09/2026

## Implementação

As quatro análises locais leem o `ProductionFlowStore`, `ProductionStageTiming.elapsed`, `ProductionOperatorSession.workedDuration`, `ProductionPauseEvent.pauseDuration` e os defeitos existentes. Não há novas gravações, alteração das etapas ou exportação de PIN. A geração captura o resultado ao aplicar os filtros; PDF e prévia usam esse mesmo resultado.

Filtro mensal pela data do evento concluído, não pela criação da OP. Sessões/pausas abertas ficam fora. A duração é integral dos eventos concluídos no período, identificada na regra de leitura. OPs do 05 entram no escopo; OPs antigas sem local entram quando têm etapas/sessões de produção. Quantidade declarada na sessão não é tratada como o total final; defeitos não viram percentual de peças únicas.

As análises oficiais por quantidade, OP, evolução e destino usam agregação SQL de PR0 sem marca de estorno, agrupada por produto/unidade. Quantidades de produtos diferentes não são somadas. Os filtros efetivos são devolvidos e exibidos; consumo e estornos são análises distintas. Gráfico quantitativo somente quando os grupos têm o mesmo produto/unidade. Grupos limitados a 100, com tamanho total explícito.

## Verificação proporcional

Pedido anterior de não executar testes pesados preservado: análise estática dos arquivos alterados; 21 testes Python focados e 9 testes Flutter focados. Não foi executada a suíte completa, cobertura ou teste de carga.

Testes locais verificam duração com pausa, OP criada antes do mês, conclusão em setembro, etapa customizada, filtro por operador, quantidade declarada sem atribuir o lote inteiro, ausência de PIN no resultado e geração PDF das quatro análises locais.

Consulta real de setembro nas análises oficiais: 49 apontamentos PR0 sem marca de estorno, 47 OPs, 13 dias com apontamento e 28 grupos produto/unidade. Nenhuma consulta altera o DEV. Estes números não representam tempos nem trabalho individual, que vêm do VettiFlow.

Limites herdados: download no navegador interno não confirmado na entrega inicial; prévia usa PDF.js local. Autorização individual na API e persistência compartilhada dos eventos locais permanecem fora desta entrega.
