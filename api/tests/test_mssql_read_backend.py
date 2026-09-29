from fastapi.testclient import TestClient

from app import config, mssql
from app.main import app


def _client(monkeypatch):
    monkeypatch.setattr(config, "API_TOKEN", "")
    monkeypatch.setattr(
        mssql,
        "health",
        lambda: {"banco": "HMLp12", "servidor": "win-l1na6ce7lb4"},
    )
    return TestClient(app)


def test_health_usa_conexao_protheus_dev(monkeypatch):
    with _client(monkeypatch) as client:
        response = client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json()["banco"] == "HMLp12"
    assert response.json()["aplicando"] is False
    assert response.json()["readOnly"] is True


def test_produtos_delega_para_sql_server(monkeypatch):
    chamadas = []

    def fake_search(query, filial, limit):
        chamadas.append((query, filial, limit))
        return [{"code": "700001", "description": "Produto teste"}]

    monkeypatch.setattr(mssql, "search_products", fake_search)

    with _client(monkeypatch) as client:
        response = client.get("/api/v1/produtos?query=700&filial=04&limit=5")

    assert response.status_code == 200
    assert chamadas == [("700", "04", 5)]
    assert response.json()[0]["code"] == "700001"


def test_locais_delega_para_sql_server(monkeypatch):
    chamadas = []

    def fake_warehouses(filial):
        chamadas.append(filial)
        return [
            {
                "filial": "04",
                "code": "04",
                "description": "PRODUCAO PTH",
                "type": "1",
                "integratesProduction": "3",
                "mrp": "1",
            }
        ]

    monkeypatch.setattr(mssql, "warehouses", fake_warehouses)

    with _client(monkeypatch) as client:
        response = client.get("/api/v1/locais?filial=04")

    assert response.status_code == 200
    assert chamadas == ["04"]
    assert response.json()[0]["code"] == "04"
    assert response.json()[0]["description"] == "PRODUCAO PTH"


def test_movimentos_da_op_delega_para_sql_server(monkeypatch):
    chamadas = []

    def fake_op_movements(op, filial):
        chamadas.append((op, filial))
        return {
            "op": op,
            "filial": filial,
            "statusOficial": "apontada_parcial",
            "ordem": {
                "numero": "01621401001",
                "produto": "575-0863",
                "quantidadePlanejada": 150,
                "quantidadeProduzida": 100,
                "local": "05",
                "encerrada": False,
            },
            "empenhos": [
                {
                    "produto": "100-010",
                    "local": "05",
                    "quantidadeOriginal": 150,
                    "quantidadeRestante": 50,
                }
            ],
            "movimentos": [
                {
                    "cf": "PR0",
                    "tm": "001",
                    "produto": "575-0863",
                    "local": "10",
                    "quantidade": 100,
                    "documento": "016214010",
                    "numSeq": "398619",
                    "perda": 2,
                    "ganho": 1,
                    "estorno": False,
                },
                {
                    "cf": "RE1",
                    "tm": "999",
                    "produto": "100-010",
                    "local": "05",
                    "quantidade": 150,
                    "documento": "016214010",
                    "numSeq": "398619",
                    "perda": 0,
                    "ganho": 0,
                    "estorno": False,
                },
            ],
        }

    monkeypatch.setattr(mssql, "op_movements", fake_op_movements)

    with _client(monkeypatch) as client:
        response = client.get("/api/v1/ops/01621401001/movimentos?filial=04")

    assert response.status_code == 200
    assert chamadas == [("01621401001", "04")]
    assert response.json()["statusOficial"] == "apontada_parcial"
    assert response.json()["movimentos"][0]["cf"] == "PR0"
    assert response.json()["movimentos"][0]["numSeq"] == "398619"


def test_transferencias_delega_para_sql_server(monkeypatch):
    chamadas = []

    def fake_transfer_movements(filial, produto, local_origem, local_destino, limit):
        chamadas.append((filial, produto, local_origem, local_destino, limit))
        return {
            "filial": filial,
            "transferencias": [
                {
                    "documento": "TRF000123",
                    "produto": "100-010",
                    "produtoDescricao": "PARAFUSO 2,9 X 6,5 MM ZI",
                    "quantidade": 20,
                    "localOrigem": "01",
                    "localDestino": "05",
                    "data": "09/09/2026",
                    "status": "pareada",
                    "movimentos": [
                        {
                            "cf": "RE4",
                            "tm": "999",
                            "local": "01",
                            "quantidade": 20,
                        },
                        {
                            "cf": "DE4",
                            "tm": "499",
                            "local": "05",
                            "quantidade": 20,
                        },
                    ],
                }
            ],
            "divergencias": [],
        }

    monkeypatch.setattr(mssql, "transfer_movements", fake_transfer_movements)

    with _client(monkeypatch) as client:
        response = client.get(
            "/api/v1/transferencias?filial=04&produto=100-010"
            "&localOrigem=01&localDestino=05&limit=10"
        )

    assert response.status_code == 200
    assert chamadas == [("04", "100-010", "01", "05", 10)]
    assert response.json()["transferencias"][0]["documento"] == "TRF000123"
    assert response.json()["transferencias"][0]["localOrigem"] == "01"
    assert response.json()["transferencias"][0]["localDestino"] == "05"


def test_desmontagens_delega_para_sql_server(monkeypatch):
    chamadas = []

    def fake_dismantling_movements(filial, documento, produto, limit):
        chamadas.append((filial, documento, produto, limit))
        return {
            "filial": filial,
            "desmontagens": [
                {
                    "documento": "Q000004AV",
                    "produtoOrigem": "575-0863",
                    "produtoOrigemDescricao": "SUB MEC SMART MODULO SIRENE SF",
                    "quantidadeOrigem": 1,
                    "localOrigem": "05",
                    "data": "09/09/2026",
                    "status": "pareada",
                    "componentesRetornados": [
                        {
                            "produto": "100-010",
                            "produtoDescricao": "PARAFUSO 2,9 X 6,5 MM ZI",
                            "quantidade": 4,
                            "local": "01",
                            "documento": "Q000004AV",
                            "data": "09/09/2026",
                        }
                    ],
                    "movimentos": [
                        {"cf": "RE7", "tm": "999", "produto": "575-0863"},
                        {"cf": "DE7", "tm": "499", "produto": "100-010"},
                    ],
                }
            ],
            "divergencias": [],
        }

    monkeypatch.setattr(mssql, "dismantling_movements", fake_dismantling_movements)

    with _client(monkeypatch) as client:
        response = client.get(
            "/api/v1/desmontagens?filial=04&documento=Q000004AV"
            "&produto=575-0863&limit=10"
        )

    assert response.status_code == 200
    assert chamadas == [("04", "Q000004AV", "575-0863", 10)]
    desmontagem = response.json()["desmontagens"][0]
    assert desmontagem["documento"] == "Q000004AV"
    assert desmontagem["produtoOrigem"] == "575-0863"
    assert desmontagem["componentesRetornados"][0]["produto"] == "100-010"


def test_auditoria_estoque_delega_para_sql_server(monkeypatch):
    chamadas = []

    def fake_inventory_audit_movements(
        filial,
        documento,
        op,
        produto,
        tipo,
        limit,
    ):
        chamadas.append((filial, documento, op, produto, tipo, limit))
        return {
            "filial": filial,
            "movimentos": [
                {
                    "cf": "ER0",
                    "tm": "999",
                    "tipo": "estorno_op",
                    "tipoLabel": "Estorno de OP",
                    "documento": "016214010",
                    "op": "01621401001",
                    "produto": "575-0863",
                    "produtoDescricao": "SUB MEC SMART MODULO SIRENE SF",
                    "quantidade": 10,
                    "local": "10",
                    "data": "09/09/2026",
                    "numSeq": "398619",
                    "usuario": "LEONARDO",
                    "motivo": "RETORNO TESTE",
                    "observacao": "Estorno conferido",
                    "estorno": True,
                }
            ],
            "resumoPorTipo": [{"tipo": "estorno_op", "quantidadeMovimentos": 1}],
            "pendenciasPesquisa": [],
        }

    monkeypatch.setattr(
        mssql,
        "inventory_audit_movements",
        fake_inventory_audit_movements,
    )

    with _client(monkeypatch) as client:
        response = client.get(
            "/api/v1/auditoria-estoque?filial=04&documento=016214010"
            "&op=01621401001&produto=575-0863&tipo=estorno_op&limit=10"
        )

    assert response.status_code == 200
    assert chamadas == [
        ("04", "016214010", "01621401001", "575-0863", "estorno_op", 10)
    ]
    movimento = response.json()["movimentos"][0]
    assert movimento["cf"] == "ER0"
    assert movimento["tipo"] == "estorno_op"
    assert movimento["usuario"] == "LEONARDO"
    assert movimento["motivo"] == "RETORNO TESTE"


def test_previa_apontamento_delega_para_sql_server(monkeypatch):
    chamadas = []

    def fake_completion_preview(op, filial, quantidade, armazem=None):
        chamadas.append((op, filial, quantidade, armazem))
        return {
            "op": op,
            "filial": filial,
            "readOnly": True,
            "rotinaStatus": "pendente_pesquisa",
            "rotinasCandidatas": ["MATA250", "MATA680", "MATA681"],
            "quantidadeSolicitada": 50,
            "quantidadeRestante": 50,
            "ordem": {
                "numero": "01621401001",
                "produto": "575-0863",
                "produtoDescricao": "SUB MEC SMART MODULO SIRENE SF",
                "quantidadePlanejada": 150,
                "quantidadeProduzida": 100,
                "local": "05",
                "encerrada": False,
            },
            "movimentosPrevistos": [
                {
                    "cf": "PR0",
                    "tm": "001",
                    "produto": "575-0863",
                    "local": "10",
                    "quantidade": 50,
                },
                {
                    "cf": "RE1",
                    "tm": "999",
                    "produto": "100-010",
                    "local": "05",
                    "quantidade": 50,
                },
            ],
            "saldosComponentes": [
                {
                    "produto": "100-010",
                    "local": "05",
                    "saldoAtual": 80,
                    "quantidadePrevista": 50,
                    "suficiente": True,
                }
            ],
            "divergencias": [],
            "pendenciasPesquisa": ["Confirmar rotina oficial de apontamento."],
        }

    monkeypatch.setattr(
        mssql,
        "production_completion_preview",
        fake_completion_preview,
    )

    with _client(monkeypatch) as client:
        response = client.get(
            "/api/v1/ops/01621401001/apontamento-preview"
            "?filial=04&quantidade=50&armazem=10"
        )
        invalido = client.get(
            "/api/v1/ops/01621401001/apontamento-preview?armazem=10;x"
        )

    assert response.status_code == 200
    assert invalido.status_code == 422
    assert chamadas == [("01621401001", "04", 50, "10")]
    payload = response.json()
    assert payload["readOnly"] is True
    assert payload["rotinaStatus"] == "pendente_pesquisa"
    assert [item["cf"] for item in payload["movimentosPrevistos"]] == [
        "PR0",
        "RE1",
    ]


def test_governanca_escrita_delega_para_backend_read_only(monkeypatch):
    chamadas = []

    def fake_write_readiness():
        chamadas.append("write_readiness")
        return {
            "readOnly": True,
            "writeEnabled": False,
            "status": "bloqueada_por_politica",
            "database": "HMLp12",
            "blockedOperations": [
                "abertura_op",
                "apontamento_op",
                "transferencia",
                "desmontagem",
                "sql_direto",
            ],
            "futureRequirements": [
                "Projeto separado para wrapper oficial Protheus.",
                "Validar MSExecAuto/rotina oficial somente depois de aprovacao.",
            ],
            "candidateRoutines": ["MATA250", "MATA680", "MATA681"],
        }

    monkeypatch.setattr(mssql, "write_readiness", fake_write_readiness)

    with _client(monkeypatch) as client:
        response = client.get("/api/v1/write-readiness")

    assert response.status_code == 200
    assert chamadas == ["write_readiness"]
    payload = response.json()
    assert payload["readOnly"] is True
    assert payload["writeEnabled"] is False
    assert payload["status"] == "bloqueada_por_politica"
    assert "sql_direto" in payload["blockedOperations"]


def test_rotas_de_escrita_ficam_bloqueadas(monkeypatch):
    with _client(monkeypatch) as client:
        response = client.post("/api/v1/mutations", json={"mutations": []})

    assert response.status_code == 503
    assert "somente leitura" in response.json()["detail"]


def test_tabela_usa_sufixo_empresa_e_schema(monkeypatch):
    monkeypatch.setattr(config, "EMPRESA", "010")
    monkeypatch.setattr(config, "MSSQL_SCHEMA", "dbo")

    assert mssql.tabela("SB1") == "[dbo].[SB1010]"


def _preview_016431(monkeypatch, armazem=None):
    from contextlib import contextmanager

    @contextmanager
    def fake_conexao():
        yield None

    monkeypatch.setattr(mssql, "conexao", fake_conexao)
    monkeypatch.setattr(mssql, "_official_order", lambda *_: {
        "produto": "575-0863", "local": "05", "numeroBase": "016431",
        "quantidadePlanejada": 10, "quantidadeProduzida": 0, "encerrada": False,
    })
    monkeypatch.setattr(mssql, "_official_commitments", lambda *_: [
        {"produto": "106-008", "local": "05",
         "quantidadeOriginal": 10, "quantidadeRestante": 10},
    ])
    # PR0 anterior no 10 nao muda a sugestao: a MATA250 sempre traz o C2_LOCAL.
    monkeypatch.setattr(mssql, "_official_movements", lambda *_: [
        {"cf": "PR0", "local": "10", "documento": "016431010"},
    ])
    monkeypatch.setattr(mssql, "_component_preview_balance", lambda c, f, q: {
        "produto": c["produto"], "local": c["local"], "saldoAtual": 13,
        "quantidadePrevista": q, "suficiente": True,
    })
    monkeypatch.setattr(mssql, "warehouses", lambda _f: [
        {"code": "01"}, {"code": "05"}, {"code": "10"},
    ])
    return mssql.production_completion_preview(
        "01643101001", "04", 10, armazem=armazem,
    )


def test_previa_apontamento_sugere_local_da_op_como_a_mata250(monkeypatch):
    preview = _preview_016431(monkeypatch)

    assert preview["armazemPadrao"] == "05"
    assert preview["armazemInformado"] == ""
    assert preview["movimentosPrevistos"][0]["local"] == "05"
    # RE1 continua saindo do local do empenho, independente do acabado.
    assert preview["movimentosPrevistos"][1]["local"] == "05"


def test_previa_apontamento_aceita_armazem_editado(monkeypatch):
    # Caso real da OP 016431: MATA250 sugeriu 05 e a Tatiane apontou no 10.
    preview = _preview_016431(monkeypatch, armazem="10")

    assert preview["armazemPadrao"] == "05"
    assert preview["movimentosPrevistos"][0]["local"] == "10"
    assert preview["movimentosPrevistos"][1]["local"] == "05"
    assert preview["divergencias"] == []


def test_previa_apontamento_avisa_armazem_fora_da_nnr(monkeypatch):
    preview = _preview_016431(monkeypatch, armazem="99")

    assert preview["movimentosPrevistos"][0]["local"] == "99"
    assert any("99" in item for item in preview["divergencias"])


def test_mod_preview_does_not_validate_physical_stock(monkeypatch):
    _preview_016431(monkeypatch)
    monkeypatch.setattr(mssql, "_official_commitments", lambda *_: [
        {"produto": "MOD001", "local": "05", "quantidadeOriginal": 10, "quantidadeRestante": 10},
    ])
    def unexpected_balance(*_):
        raise AssertionError("MOD must not query physical balance")
    monkeypatch.setattr(mssql, "_component_preview_balance", unexpected_balance)
    preview = mssql.production_completion_preview("01643101001", "04", 10)
    assert preview["saldosComponentes"] == []
    assert preview["divergencias"] == []
    assert preview["movimentosPrevistos"][1]["produto"] == "MOD001"


def test_encerradas_endpoint_paginado(monkeypatch):
    calls = []
    def query(filial, after, page_size):
        calls.append((filial, after, page_size))
        return {"items": [{"numero": "123", "encerrada": True, "encerramento": "28/09/2026"}], "nextCursor": None}
    monkeypatch.setattr(mssql, "closed_orders", query, raising=False)
    with _client(monkeypatch) as client:
        result = client.get('/api/v1/ops/encerradas?filial=04&after=7&page_size=2000')
        assert result.status_code == 200
        assert result.json()['items'][0]['encerrada'] is True
        assert client.get('/api/v1/ops/encerradas?page_size=2001').status_code == 422
    assert calls == [('04', 7, 2000)]


def test_closed_orders_cursor_and_dates(monkeypatch):
    from contextlib import contextmanager
    @contextmanager
    def connection():
        yield None
    monkeypatch.setattr(mssql, 'conexao', connection)
    def fetch(conn, sql, args):
        assert args == (3, '04', 5)
        return [dict(recordId=i, emissao='20240101', previsao='20240120', encerramento='20260928') for i in (6, 7, 8)]
    monkeypatch.setattr(mssql, '_fetchall', fetch)
    page = mssql.closed_orders('04', 5, 2)
    assert page['nextCursor'] == 7
    assert len(page['items']) == 2
    assert page['items'][0] == dict(emissao='01/01/2024', previsao='20/01/2024', encerramento='28/09/2026', encerrada=True)
