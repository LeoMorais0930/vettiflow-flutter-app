"""Read-only, reproducible audit of HMLp12; writes only local evidence files."""
import json
import sys
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'api'))
from app import config, mssql

OUT = ROOT / 'docs' / 'auditorias' / '2026-09-24'
OUT.mkdir(parents=True, exist_ok=True)
assert config.MSSQL_DATABASE.lower() == 'hmlp12', 'Audit restricted to dev HMLp12'
START, END, BRANCH = '20260624', '20260925', '04'
results = {'metadata': {'start_inclusive': START, 'end_exclusive': END, 'branch': BRANCH,
                        'captured_at': datetime.now().isoformat(), 'read_only': True}}
queries = []

with mssql.conexao() as conn:
    conn.timeout = 60
    def query(name, sql, params=()):
        assert sql.lstrip().upper().startswith(('SELECT', 'WITH'))
        queries.append({'name': name, 'sql': sql, 'params': list(params)})
        results[name] = mssql._fetchall(conn, sql, params)
        print(name, len(results[name]), flush=True)
        (OUT / 'evidencias.json').write_text(json.dumps(results, ensure_ascii=False, indent=2, default=str), encoding='utf-8')
        (OUT / 'consultas.json').write_text(json.dumps(queries, ensure_ascii=False, indent=2), encoding='utf-8')

    query('connection', 'SELECT DB_NAME() banco, @@SERVERNAME servidor, GETDATE() horario_servidor')
    assert results['connection'][0]['banco'].lower() == 'hmlp12'
    query('locais', "SELECT NNR_FILIAL filial, NNR_CODIGO local, NNR_DESCRI descricao FROM dbo.NNR010 WHERE D_E_L_E_T_='' ORDER BY NNR_FILIAL,NNR_CODIGO")
    query('tipos_movimento', "SELECT F5_FILIAL filial,F5_CODIGO tm,F5_TIPO tipo,F5_TEXTO descricao FROM dbo.SF5010 WHERE D_E_L_E_T_='' ORDER BY F5_CODIGO")
    query('tes', "SELECT F4_FILIAL filial,F4_CODIGO tes,F4_TEXTO descricao,F4_ESTOQUE estoque,F4_CF cfop FROM dbo.SF4010 WHERE D_E_L_E_T_='' ORDER BY F4_FILIAL,F4_CODIGO")
    for table, prefix, date in [('SD3','D3','EMISSAO'),('SD1','D1','DTDIGIT'),('SD2','D2','EMISSAO'),('SC2','C2','EMISSAO')]:
        query(f'{table}_cobertura', f"SELECT {prefix}_FILIAL filial,MIN({prefix}_{date}) primeira,MAX({prefix}_{date}) ultima,COUNT_BIG(*) linhas, SUM(CASE WHEN {prefix}_{date}>=? AND {prefix}_{date}<? THEN CAST(1 AS bigint) ELSE 0 END) linhas_periodo FROM dbo.{table}010 WHERE D_E_L_E_T_='' GROUP BY {prefix}_FILIAL", (START,END))
    where = "D_E_L_E_T_='' AND D3_FILIAL=? AND D3_EMISSAO>=? AND D3_EMISSAO<?"
    params = (BRANCH,START,END)
    query('sd3_tipos_locais', f"SELECT D3_LOCAL local,D3_CF cf,D3_TM tm,D3_ESTORNO estorno,COUNT_BIG(*) linhas,COUNT(DISTINCT D3_COD) produtos,COUNT(DISTINCT NULLIF(RTRIM(D3_OP),'')) ops,MIN(D3_EMISSAO) primeira,MAX(D3_EMISSAO) ultima FROM dbo.SD3010 WHERE {where} GROUP BY D3_LOCAL,D3_CF,D3_TM,D3_ESTORNO ORDER BY D3_LOCAL,D3_CF,D3_TM,D3_ESTORNO",params)
    query('sd3_mensal', f"SELECT LEFT(D3_EMISSAO,6) mes,D3_LOCAL local,D3_CF cf,D3_TM tm,D3_ESTORNO estorno,COUNT_BIG(*) linhas FROM dbo.SD3010 WHERE {where} GROUP BY LEFT(D3_EMISSAO,6),D3_LOCAL,D3_CF,D3_TM,D3_ESTORNO ORDER BY mes,local,cf,tm",params)
    query('sd3_amostras', f"WITH sample AS (SELECT D3_LOCAL local,D3_CF cf,D3_TM tm,D3_ESTORNO estorno,D3_EMISSAO data,D3_COD produto,D3_QUANT quantidade,D3_UM unidade,D3_DOC documento,D3_OP op,D3_NUMSEQ sequencia,R_E_C_N_O_ recno,ROW_NUMBER() OVER(PARTITION BY D3_LOCAL,D3_CF,D3_TM,D3_ESTORNO ORDER BY D3_EMISSAO DESC,R_E_C_N_O_ DESC) rn FROM dbo.SD3010 WHERE {where}) SELECT * FROM sample WHERE rn<=2 ORDER BY local,cf,tm,estorno,rn",params)
    for table,p,date in [('SD1','D1','DTDIGIT'),('SD2','D2','EMISSAO')]:
        query(f'{table}_tipos_locais',f"SELECT {p}_LOCAL local,{p}_TIPO tipo,{p}_CF cfop,{p}_TES tes,COUNT_BIG(*) linhas,COUNT(DISTINCT {p}_COD) produtos,MIN({p}_{date}) primeira,MAX({p}_{date}) ultima FROM dbo.{table}010 WHERE D_E_L_E_T_='' AND {p}_FILIAL=? AND {p}_{date}>=? AND {p}_{date}<? GROUP BY {p}_LOCAL,{p}_TIPO,{p}_CF,{p}_TES ORDER BY local,tipo,cfop,tes", params)
    query('ops_criadas', "SELECT C2_LOCAL local,COUNT_BIG(*) ops,SUM(CASE WHEN C2_DATRF<>'' THEN 1 ELSE 0 END) encerradas,SUM(CASE WHEN C2_QUJE>0 THEN 1 ELSE 0 END) com_producao,MIN(C2_EMISSAO) primeira,MAX(C2_EMISSAO) ultima FROM dbo.SC2010 WHERE D_E_L_E_T_='' AND C2_FILIAL=? AND C2_EMISSAO>=? AND C2_EMISSAO<? GROUP BY C2_LOCAL ORDER BY C2_LOCAL",params)
    query('roteamento_producao', "SELECT c.C2_LOCAL local_op,d.D3_LOCAL local_entrada,d.D3_ESTORNO estorno,COUNT_BIG(*) linhas,COUNT(DISTINCT d.D3_OP) ops FROM dbo.SD3010 d JOIN dbo.SC2010 c ON c.D_E_L_E_T_='' AND c.C2_FILIAL=d.D3_FILIAL AND RTRIM(c.C2_NUM)+RTRIM(c.C2_ITEM)+RTRIM(c.C2_SEQUEN)=RTRIM(d.D3_OP) WHERE d.D_E_L_E_T_='' AND d.D3_FILIAL=? AND d.D3_EMISSAO>=? AND d.D3_EMISSAO<? AND d.D3_CF='PR0' GROUP BY c.C2_LOCAL,d.D3_LOCAL,d.D3_ESTORNO ORDER BY local_op,local_entrada,estorno",params)
    query('transferencias_linhas', f"SELECT D3_FILIAL filial,D3_LOCAL local,D3_CF cf,D3_TM tm,D3_ESTORNO estorno,D3_EMISSAO data,D3_COD produto,D3_QUANT quantidade,D3_UM unidade,D3_DOC documento,D3_NUMSEQ sequencia,R_E_C_N_O_ recno FROM dbo.SD3010 WHERE {where} AND D3_CF IN ('RE4','DE4') ORDER BY D3_EMISSAO,D3_DOC,D3_COD,R_E_C_N_O_",params)
    query('empenhos_ops_periodo', "SELECT c.C2_LOCAL local_op,d.D4_LOCAL local_empenho,COUNT_BIG(*) linhas,COUNT(DISTINCT d.D4_OP) ops FROM dbo.SD4010 d JOIN dbo.SC2010 c ON c.D_E_L_E_T_='' AND c.C2_FILIAL=d.D4_FILIAL AND RTRIM(c.C2_NUM)+RTRIM(c.C2_ITEM)+RTRIM(c.C2_SEQUEN)=RTRIM(d.D4_OP) WHERE d.D_E_L_E_T_='' AND c.C2_FILIAL=? AND c.C2_EMISSAO>=? AND c.C2_EMISSAO<? GROUP BY c.C2_LOCAL,d.D4_LOCAL ORDER BY local_op,local_empenho",params)

print('Evidence saved:', OUT)
