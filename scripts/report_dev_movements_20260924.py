"""Summarize saved audit evidence without any database access."""
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'api'))
from app.mssql import _pair_transfer_rows

OUT = ROOT / 'docs' / 'auditorias' / '2026-09-24'
j = json.loads((OUT / 'evidencias.json').read_text(encoding='utf-8'))
tes = {r['tes']: r for r in j['tes']}
assert len(tes) == len(j['tes']), 'TES ambiguity requires branch-aware lookup'
for key, coverage in [('sd3_tipos_locais','SD3_cobertura'),('SD1_tipos_locais','SD1_cobertura'),('SD2_tipos_locais','SD2_cobertura')]:
    assert sum(r['linhas'] for r in j[key]) == sum(r['linhas_periodo'] for r in j[coverage] if r['filial']=='04')
assert sum(r['ops'] for r in j['ops_criadas']) == 685
groups = defaultdict(list)
for r in j['transferencias_linhas']:
    groups[(r['filial'], r['data'], r['documento'], r['sequencia'])].append(r)
routes = Counter()
changes = []
for key, rows in groups.items():
    a = [r for r in rows if r['cf']=='RE4']
    b = [r for r in rows if r['cf']=='DE4']
    assert len(a)==len(b)==1, key
    a,b = a[0],b[0]
    routes[(a['local'],b['local'])] += 1
    if a['produto']!=b['produto']:
        changes.append({'data':a['data'],'documento':a['documento'],'sequencia':a['sequencia'],
                        'origem':a['local'],'destino':b['local'],'produto_saida':a['produto'],
                        'produto_entrada':b['produto'],'quantidade_saida':a['quantidade'],
                        'quantidade_entrada':b['quantidade'],'um_saida':a['unidade'],'um_entrada':b['unidade']})
app_counts=Counter(r['status'] for r in _pair_transfer_rows(j['transferencias_linhas']))
summary = {'transferencias_pareadas_por_sequencia':len(groups), 'rotas':[{'origem':a,'destino':b,'pares':n} for (a,b),n in routes.most_common()], 'mudancas_produto':changes,'resultado_pareamento_atual_app':dict(app_counts)}
(OUT/'analise.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
lines=[]
def paragraph(s): lines.extend([s,''])
def table(headers,rows):
    lines.append('| '+' | '.join(headers)+' |')
    lines.append('| '+' | '.join('---' for _ in headers)+' |')
    lines.extend('| '+' | '.join(str(v).replace('|','/').replace('\n',' ') for v in row)+' |' for row in rows)
    lines.append('')
paragraph('# Auditoria de movimentos Protheus × VettiFlow — 24/09/2026')
paragraph('Consulta real ao banco **HMLp12**, servidor WIN-L1NA6CE7LB4, empresa 010, filial 04. Período inclusivo: **24/06/2026 a 24/09/2026**. Somente SELECT; nenhuma escrita no Protheus. Captura: '+j['metadata']['captured_at']+'.')
paragraph('As quatro tabelas históricas consultadas terminam em **18/09/2026**. Não há registros de 19–24/09 nelas; esta auditoria não confirma a operação atual do banco de produção nem a data de restauração do dev. Os três meses são uma janela móvel, não junho/julho/agosto completos.')
paragraph('## Escopo e contagem')
paragraph('Varredura agregada de todas as linhas não excluídas no período, sem TOP/limite nas contagens. SD3 por emissão; SD1 por data de digitação/entrada; SD2 e SC2 por emissão. SD4 mostra o estado atual dos empenhos das OPs emitidas na janela, não um log histórico de reservas. Amostras SD3: até duas por combinação de local/CF/TM/estorno. Transferências: todas as linhas da janela. D3_ESTORNO foi separado na consulta; todos os valores retornados estão vazios. Não houve isolamento de snapshot entre consultas.')
table(['Fonte','Registros no período','Significado'],[
    ['SD3',15233,'Linhas de movimentos internos'],['SD1',1294,'Itens de notas de entrada, inclusive sem efeito em estoque'],
    ['SD2',1584,'Itens de notas de saída, inclusive sem efeito em estoque'],['SC2',685,'Registros de OP emitidos na janela']])
paragraph('Contagens são linhas/itens, não unidades produzidas, notas únicas ou operações únicas. Um apontamento pode gerar muitas linhas de consumo. Quantidades de produtos/unidades diferentes não foram somadas. O indicador de estoque abaixo é o cadastro TES atual (SF4.F4_ESTOQUE), não uma reconciliação histórica de saldo.')
paragraph('## Visão por setor')
sectors=[('Almoxarifado',['01']),('SMD',['03']),('Produção MEC/PTH',['05','04']),('Suporte',['06','07']),('Expedição',['10'])]
rows=[]
for name,locals in sectors:
    totals=[sum(r['linhas'] for r in j[k] if r['local'] in locals) for k in ['sd3_tipos_locais','SD1_tipos_locais','SD2_tipos_locais']]
    ops=sum(r['ops'] for r in j['ops_criadas'] if r['local'] in locals)
    rows.append([name,', '.join(locals),*totals,ops])
table(['Setor','Locais','SD3','Itens entrada','Itens saída','OPs emitidas'],rows)
paragraph('Outros locais também foram incluídos na varredura para preservar o fluxo com terceiros e estoques especiais; por isso a soma dos cinco setores não representa o total da base.')
paragraph('### Produção (05 MEC e 04 PTH)')
paragraph('No 05: 139 entradas PR0, 1.773 consumos RE1, 763 entradas e 587 saídas por transferência, 1 entrada de ajuste, 4 saídas de ajuste, 1 saída e 9 retornos de componentes por desmontagem. Foram emitidas 254 OPs no 05. No 04: 2 OPs com 14 linhas de empenho, nenhum movimento SD3 e 5 itens de entrada sem atualização de estoque pela TES atual. A falta de SD3 no 04 não significa ausência de planejamento.')
paragraph('122 OPs do local 05 tiveram 158 entradas de acabado no 10. Outras 4 OPs do 05 entraram no 07. Portanto, local da OP e destino do acabado precisam continuar separados. Cinco entradas no 05 vieram de OPs do 70.')
paragraph('### Almoxarifado (01)')
paragraph('1.823 saídas e 37 entradas por transferência; 5 entradas de ajuste; 4 retornos de desmontagem. Também existem 2 entradas de produção e 8 consumos de componentes: este local não é exclusivamente armazenamento. Dos 955 itens de notas de entrada, 242 usam TES com estoque=S; os demais incluem fretes, serviços, consumo e outros registros sem atualização de estoque pelo cadastro atual. Há 3 itens de saída, todos com estoque=S.')
paragraph('### SMD (03)')
paragraph('66 entradas de produção em 44 OPs distintas e 2.081 consumos; 19 entradas e 150 saídas por transferência; 1 entrada de ajuste. Foram emitidas 49 OPs na janela. Das 221 linhas de notas de entrada, 185 têm estoque=S, incluindo compras e importações. As transferências saem para 05, 70, 07, 72, 10 e 01. OPs movimentadas e OPs emitidas são recortes diferentes.')
paragraph('### Suporte (06 e 07)')
paragraph('No 06: 302 entradas e 37 saídas por transferência, mais 8 saídas de ajuste. No 07: 488 entradas e 12 saídas por transferência, mais 7 entradas de acabado oriundas de OPs do 05 ou 10. Não houve RE1 nos locais 06/07 na janela. Há notas de retorno de mostruário, conserto e garantia no 06; no 07, saídas de garantia, serviços e bonificações. O cadastro TES distingue registros com e sem atualização de estoque. Essas evidências não revelam por si só o diagnóstico, a ordem de serviço ou o motivo de cada reparo.')
paragraph('### Expedição (10)')
paragraph('766 entradas de produção, 2.924 consumos RE1, 464 entradas e 236 saídas por transferência, 7 entradas de ajuste, 4 saídas e 5 retornos de desmontagem. Foram emitidas 278 OPs no local. Logo, expedição também participa de OPs. Há 1.564 itens de saída fiscal, 1.462 com estoque=S, abrangendo vendas, exportação, bonificação, mostruário, conserto, garantia e entrega futura. Dos 100 itens de entrada, 35 têm estoque=S; aparecem devolução de venda, retorno de mostruário e recebimento para conserto.')
paragraph('## Todos os tipos internos observados')
meaning={'PR0':'Entrada de produção','RE1':'Consumo de componentes de OP','RE4':'Saída por transferência','DE4':'Entrada por transferência','RE7':'Saída de produto para desmontagem','DE7':'Retorno de componentes da desmontagem','DE0':'Entrada para ajuste (SF5: TM400)','RE0':'Saída para ajuste (SF5: TM501)'}
types=defaultdict(int)
for r in j['sd3_tipos_locais']: types[(r['cf'],r['tm'])]+=r['linhas']
table(['CF','TM','Interpretação','Linhas'],[[cf,tm,meaning[cf],n] for (cf,tm),n in sorted(types.items())])
paragraph('Não foram encontrados ER0/999 nem DE1/499 neste período do dev. Isso não invalida ocorrências em outros períodos ou bases. Os códigos 499/999 não constam como registros na SF5 consultada; as interpretações vêm dos pares observados e do mapeamento existente no projeto. Não se atribuiu uma rotina oficial específica a partir apenas desses códigos.')
paragraph('## Transferências e mudança de produto — lacuna confirmada no VettiFlow')
paragraph('As 5.904 linhas RE4/DE4 formam **2.952 pares** por filial + data + documento + D3_NUMSEQ: exatamente uma saída e uma entrada por chave nesta amostra. Em **11 pares o produto muda**, dez deles dentro do mesmo local. Um também muda a unidade PC → UN, sem diferença no valor numérico da quantidade; equivalência física não foi validada. A motivação da troca exige confirmação operacional.')
paragraph('Reexecutando apenas a função atual `_pair_transfer_rows` sobre os dados coletados, o app devolve 2.941 grupos pareados, 11 sem entrada e 11 sem saída. A função agrupa por documento/produto/quantidade/data, desconsiderando a sequência para o pareamento. Assim, essas 11 trocas reais viram 22 alertas de falta de contraparte. Nenhuma correção de código funcional foi feita nesta auditoria.')
table(['Data','Documento','Sequência','Locais','Produto saída → entrada','Quantidade saída/entrada','UM saída/entrada'],[
    [r['data'],r['documento'],r['sequencia'],r['origem']+' → '+r['destino'],r['produto_saida']+' → '+r['produto_entrada'],str(r['quantidade_saida'])+'/'+str(r['quantidade_entrada']),r['um_saida']+'/'+r['um_entrada']] for r in changes])
paragraph('### Todas as rotas observadas, incluindo troca de produto')
table(['Origem','Destino','Pares'],[[a,b,n] for (a,b),n in routes.most_common()])
paragraph('## Cobertura atual do VettiFlow e próximos ajustes identificados')
paragraph('1. A API já contempla os oito CF/TM internos encontrados, além de ER0/DE1, ausentes neste recorte. Reconhecer o código não significa modelar toda a rotina operacional.\n2. Corrigir futuramente a identidade dos pares de transferência para contemplar mudança de produto e unidade, preservando os dois lados e a sequência.\n3. Incluir leitura de SD1/SD2 com classificação por TES/CFOP para compras, vendas, devoluções, remessas, garantia, conserto e terceiros. O backend atual não consulta SD1/SD2/SF4.\n4. Preservar os destinos reais de produção 05→10, 05→07, 10→07 e 70→05; não forçar o acabado para o local da OP.\n5. Separar estoque próprio, movimentos/documentos de terceiros e documentos sem atualização de estoque; o local sozinho não define o processo. Para suportar assistência completa, ainda faltam vínculos com ordens de serviço e diagnósticos.')
paragraph('## Detalhamento completo por local e tipo interno')
table(['Local','CF','TM','Estorno','Linhas','Produtos distintos','OPs distintas','Primeira data','Última data'],[[r[k] for k in ['local','cf','tm','estorno','linhas','produtos','ops','primeira','ultima']] for r in j['sd3_tipos_locais']])
paragraph('## Detalhamento completo de notas por tipo/TES/CFOP')
paragraph('Descrições abaixo são literais do cadastro TES do próprio dev, não validação tributária. Estoque=S/N reflete o cadastro atual. Incluídos também registros administrativos para tornar explícito o que não deve ser contado automaticamente como movimento físico.')
for key,title in [('SD1_tipos_locais','Entradas (SD1)'),('SD2_tipos_locais','Saídas (SD2)')]:
    paragraph('### '+title)
    table(['Local','Tipo','CFOP','TES','Descrição cadastrada','Estoque','Itens'],[[r['local'],r['tipo'],r['cfop'],r['tes'],tes[r['tes']]['descricao'],tes[r['tes']]['estoque'],r['linhas']] for r in j[key]])
paragraph('## Roteamento real de produção')
table(['Local OP','Entrada acabado','Linhas PR0','OPs distintas'],[[r['local_op'],r['local_entrada'],r['linhas'],r['ops']] for r in j['roteamento_producao']])
paragraph('## Empenhos atuais das OPs emitidas na janela')
table(['Local OP','Local empenho','Linhas SD4','OPs distintas'],[[r['local_op'],r['local_empenho'],r['linhas'],r['ops']] for r in j['empenhos_ops_periodo']])
paragraph('## Evidência e reprodução')
paragraph('Arquivos locais: [evidencias.json](evidencias.json), [consultas.json](consultas.json), [analise.json](analise.json). Scripts: `scripts/audit_dev_movements_20260924.py` consulta exclusivamente HMLp12 e salva evidências; `scripts/report_dev_movements_20260924.py` gera este relatório a partir delas. Nenhum segredo foi exportado. O histórico mensal e as amostras por tipo estão no JSON. A validação local confere totais por fonte e a cardinalidade dos 2.952 pares.')
(OUT/'relatorio.md').write_text('\n'.join(lines),encoding='utf-8')
print('Report generated; totals and transfer pairing verified.')
