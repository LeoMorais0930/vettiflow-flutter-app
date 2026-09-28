# Relatório de movimentações do almoxarifado

24/09/2026. Primeira etapa da [proposta de relatórios](../desenvolvimento/relatorios-bi.md), autorizada após sua apresentação. Somente leitura do Protheus DEV.

## Jornadas e evidências

| Garantia | Teste/evidência | Resultado |
|---|---|---|
| Filtros parametrizados, múltiplos tipos, escopo fixo 01, intervalo válido e proteção HTTP | `api/tests/test_warehouse_reports.py` | PASS |
| Resumo completo independe do detalhe; limite explícito de 1.000 linhas; contagem alterada impede detalhe incompleto | Mesmo arquivo | PASS |
| Fonte indisponível não vira zero; falha SQL não revela conexão; limite de consultas concorrentes | Mesmo arquivo | PASS |
| Prévia e PDF usam o resultado recebido, com filtros oficiais; mudar filtros bloqueia exportação desatualizada | `test/warehouse_report_test.dart` | PASS |
| Filtros no celular, erro da API e inspeção de registro não causam overflow | Mesmo arquivo, 390 × 844 e 1366 × 900 | PASS |
| PDF vazio, com resumo, com frações, sem gráfico e com detalhamento; recusa detalhe incompleto | Mesmo arquivo | PASS |
| Contagem de setembro confere com SELECTs independentes de SD3/SD1/SD2 | DEV HMLp12, empresa 010, filial 04, local 01 | 300 + 202 + 2 = **504** |
| Todo o período não devolve milhares de linhas ao cliente | Consulta real | **114.122** registros; detalhe `too_large`, lista vazia; 6.872 grupos |

RED: o teste de API falhou com importação do módulo inexistente `warehouse_reports`. O teste Flutter falhou pela ausência do modelo, método do repositório, tela e renderizador. Esses alvos foram executados antes da implementação correspondente.

GREEN: **9 testes de API do relatório**, **1 teste HTTP do servidor de prévia** e **6 testes Flutter do relatório**. Suíte completa: **61 testes Python e 171 Flutter aprovados**. Análise estática sem problemas; build web concluído com as configurações locais existentes.

Comandos executados:

```powershell
.\api\venv\Scripts\python.exe -m pytest api/tests -q
flutter test --no-pub
flutter test --no-pub --coverage --coverage-path coverage/warehouse-report.lcov.info test/warehouse_report_test.dart
flutter analyze --no-pub
flutter build web --no-pub --dart-define-from-file=.dart_tool/vettiflow-local-defines.json
```

Cobertura de linhas da suíte focada: modelo **92,9%** (92/99), tela **81,9%** (299/365), PDF **98,2%** (161/164). Não confundir esses percentuais com cobertura de todo o aplicativo ou da API. A tentativa de usar `python -m coverage` não estava disponível nesse ambiente; cobertura Python não medida.

## Verificação do PDF e do DEV

O modo `VF_REPORT_QA=1` dos testes gera PDFs de verificação em `tmp/pdfs/`, pasta ignorada pelo Git. O PDF de setembro usa o JSON de consulta real em `.dart_tool/report-september.json`; esse modo é opcional e exige essa consulta local, sem tornar a suíte comum dependente do banco.

O PDF real detalhado contém **58 páginas e 504 registros**. O resumo também contém os 100 grupos do ranking, identificados como parte dos 284 grupos do mês. Foi renderizado com Poppler; nomes, acentos, tabelas, cabeçalhos e rodapés foram inspecionados. Uma checagem de coordenadas em todas as páginas não encontrou texto fora da área segura. O ajuste de espaçamento das células manteve o documento abaixo do teto; o teste anterior detectou corretamente um documento de 61 páginas e interrompeu a geração.

Tempos observados de uma execução no DEV: setembro com detalhe 0,77 s; todo o período 18 s. São medições locais, não garantia de desempenho. A rota HTTP reiniciada retornou os mesmos 504 registros. Nenhum SQL de alteração, ADVPL, índice ou parâmetro do Protheus foi executado/alterado.

## Limites

- Esta entrega cobre movimentações do 01. PDF de estoque, OPs, inventário, outros setores e gestão permanecem pendentes.
- O controle por conta no servidor, comparação de meses, filtros salvos e cache de relatórios não estão implementados.
- O gráfico e ranking têm cortes identificados; os agregados do resumo usam todo o recorte.
- Se o detalhe não couber ou a contagem mudar, o aviso aparece junto ao botão de exportação, que passa a dizer **Gerar resumo em PDF**. Essa condição teve teste RED/GREEN próprio na mesma suíte de prévia.
- As leituras SQL têm horários de início/fim, mas não garantem um retrato transacional único. A conferência de contagem detecta mudanças de tamanho do detalhe, não todas as alterações possíveis entre consultas.
- Fontes IBM Plex e PDF.js 6.2.108 estão empacotados com suas licenças. A prévia web usa esses arquivos locais. Impressão física e execução nativa Windows/Android/macOS não foram verificadas nesta entrega.
- A validação no navegador detectou que o servidor genérico do Python herdava `text/plain` do Windows para `.mjs`, impedindo a prévia. `scripts/serve_web.py` fornece `text/javascript`; o teste HTTP falhou antes da implementação e passou depois. A hospedagem deve servir `.mjs` como JavaScript.
- O carregamento antecipado do PDF.js local em `web/index.html` também foi necessário à inicialização da prévia nesta combinação de navegador/plugin. A renderização do resumo de setembro foi confirmada visualmente no navegador. Os botões de salvar/imprimir ficam na barra superior, sem depender da barra de ações interna do plugin.
- A geração do arquivo foi validada em teste e a prévia foi validada no navegador interno. O download por **Salvar PDF** não pôde ser confirmado nele: uma página HTML isolada também não disparou o evento de download para Blob nem data URL, enquanto um arquivo HTTP estático disparou. O botão mantém o mecanismo padrão de `Printing.sharePdf`; o salvamento pelo navegador externo permanece sem verificação. Não foi criado envio do PDF para a API como contorno.
- Não foram criados checkpoints Git porque a árvore já reunia alterações extensas das entregas anteriores. Nenhuma dessas alterações foi revertida ou incluída em commit por esta tarefa; evidência RED/GREEN preservada aqui.

Arquivos principais: `api/app/warehouse_reports.py`, `lib/data/models/warehouse_report.dart`, `lib/ui/reports/warehouse_report_page.dart`, `lib/ui/reports/warehouse_report_pdf.dart`.
