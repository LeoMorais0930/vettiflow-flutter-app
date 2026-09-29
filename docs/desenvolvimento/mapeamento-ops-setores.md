# OPs oficiais e etapas do VettiFlow

Decisão confirmada por Leonardo em 29/09/2026: gravação, soldagem, teste e fechamento ainda não são registrados em outro sistema. O VettiFlow será a fonte desses apontamentos.

O dashboard agrupa OPs oficiais por C2_LOCAL, usando o cadastro WarehouseRouting validado contra a NNR do DEV. Esse agrupamento indica setor cadastrado na OP, não sua localização física atual nem sua etapa executada. Nenhum apontamento ou movimentação ERP é gerado ao consultar o painel.

| Código | Setor | OPs abertas observadas no DEV |
|---|---|---:|
| 01 | Almoxarifado | 2 |
| 03 | SMD | 19 |
| 04 | PTH | 3 |
| 05 | Produção | 141 |
| 06 | Suporte / assistência técnica | 2 |
| 07 | Suporte externo | 2 |
| 10 | Expedição | 40 |
| 70 | Terceiros - Mauro | 8 |

Total observado: 217. Quantidades mudam conforme o ERP. Código fora dos cinco grupos ou vazio permanece explícito, sem cair em Almoxarifado.

As OPs oficiais não recebem etapas inventadas a partir de C2_LOCAL. O fluxo local existente permanece separado. Ainda falta vincular e persistir os apontamentos do VettiFlow pela chave completa da OP oficial (filial, número, item, sequência e grade), com identidade autenticada e histórico. Essa implementação futura não deve duplicar OP nem habilitar escrita no ERP.

Agrupamento confirmado pelo usuário: Almoxarifado / SMD / PTH (01, 03, 04: 24 OPs); Sub MEC / Produção (05: 141); Suporte (06, 07: 4); Expedição (10: 40); Terceiros (70 a 73: 8). Os códigos originais permanecem nas OPs. Esses totais são a fotografia de DEV acima, não valores fixos na aplicação.


## Conclusão e apresentação (29/09/2026)

Regra confirmada pelo usuário: OP cadastrada na Expedição (C2_LOCAL=10), C2_QUJE >= C2_QUANT > 0 e nenhum empenho SD4 ativo com D4_QUANT > 0 para material físico é concluída no painel. A identidade correlacionada inclui filial, número, item, sequência e grade. MOD (prefixo já usado no aplicativo) é contado separadamente e não impede essa classificação. Campo de pendências ausente não comprova conclusão. A classificação não altera C2_DATRF nem executa gravação no ERP.

O painel inicia no ano atual pela emissão, com seleção de ano, mês/ano, todo o histórico ou data ausente. Filtro de setor e opção de mostrar concluídas se aplicam à lista e aos indicadores. Fotografia consultada: 201 OPs de 2026, 5 de 2025, 11 de 2024; nenhuma atende à regra completa de conclusão; 165 possuem MOD pendente.

Detalhes oficiais carregam sob demanda em seções expansíveis. MOD fica oculto inicialmente e pode ser exibido em seção própria. A prévia preserva movimentos de MOD, mas não busca nem acusa saldo físico insuficiente de mão de obra.


## Histórico oficial de encerramento

O dashboard consulta abertas e `/api/v1/ops/encerradas`, em páginas de até 2.000 registros com cursor por R_E_C_N_O_. O endpoint antigo de abertas mantém seu contrato. O carregamento só publica o resultado completo; falha no histórico gera erro e preserva os dados anteriores.

OP com C2_DATRF preenchido aparece como **Encerrada no Protheus**, independentemente de seu armazém ou da diferença entre quantidade produzida e planejada. **Concluída no painel** continua sendo a classificação das OPs ainda abertas que atendem à regra de Expedição. Nenhuma dessas consultas escreve no ERP.

O filtro Situação separa as duas classificações e Em aberto. Período usa encerramento para as encerradas no ERP e emissão para as demais. Listas são ordenadas por essa data, das recentes às antigas. O ano atual inclui OP emitida antes, desde que tenha sido encerrada no ano atual.

Validação direta no DEV em 29/09/2026: 12.492 encerradas em 7 páginas, 12.492 chaves únicas; 1.813 encerradas em 2026. Exemplo: OP 01643101001, emissão e encerramento em 28/09/2026, planejado 10 e produzido 10. Testes cobrem também encerramento parcial, falha de página e filtros por data de encerramento.
