from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from datetime import date, timedelta
import sqlite3
import uuid

import pytest
from fastapi.testclient import TestClient

from app import config, mssql, solicitacoes
from app.main import app

CHAVE = "chave-consumidor-teste"
CONSUMIDOR = {"X-VettiFlow-Consumer-Key": CHAVE}


@pytest.fixture
def fila(monkeypatch, tmp_path):
    monkeypatch.setattr(config, "API_TOKEN", "")
    monkeypatch.setattr(config, "QUEUE_ENABLED", True)
    monkeypatch.setattr(config, "QUEUE_OPERATIONS", ["abertura_op"])
    monkeypatch.setattr(config, "QUEUE_CONSUMER_TOKEN", CHAVE)
    monkeypatch.setattr(config, "QUEUE_RESERVATION_MINUTES", 10)
    monkeypatch.setattr(config, "QUEUE_DB", tmp_path / "fila.sqlite3")
    monkeypatch.setattr(solicitacoes, "_stores", {})
    monkeypatch.setattr(mssql, "product_by_code", lambda codigo, filial: (
        {"code": codigo, "screenBlock": "2"} if codigo == "575-0863" else None))
    monkeypatch.setattr(mssql, "warehouses", lambda filial: [
        {"code": "01"}, {"code": "05"}, {"code": "10"}])
    conferencias = []

    def conferir_fake(item):
        conferencias.append(item.protheus_refs)
        return True, f"OP {item.protheus_refs[0]} confirmada na SC2 com 9 empenho(s) na SD4."

    monkeypatch.setitem(solicitacoes._CONFERENCIAS, "abertura_op", conferir_fake)
    with TestClient(app) as client:
        client.conferencias = conferencias
        yield client


def _pedido(**payload):
    hoje = date.today()
    return {
        "id": str(uuid.uuid4()),
        "versaoContrato": "vettiflow.solicitacao.v1",
        "operacao": "abertura_op",
        "solicitante": "tatiane",
        "payload": {
            "produto": "575-0863", "quantidade": 10, "armazem": "05",
            "dataInicio": hoje.isoformat(),
            "dataEntrega": (hoje + timedelta(days=1)).isoformat(),
            **payload,
        },
    }


def _reservar(client):
    return client.post("/api/v1/consumidor/reservar", headers=CONSUMIDOR)


def _resultado(client, id_, reserva, **dados):
    corpo = {"reserva": reserva, "sucesso": True, "protheusRefs": ["01643101001"],
             "mensagem": "MATA650 ok", "executor": "vfjob", **dados}
    return client.post(f"/api/v1/consumidor/solicitacoes/{id_}/resultado",
                       json=corpo, headers=CONSUMIDOR)


def test_fila_desativada_recusa_pedido(fila, monkeypatch):
    monkeypatch.setattr(config, "QUEUE_ENABLED", False)

    resposta = fila.post("/api/v1/solicitacoes", json=_pedido())

    assert resposta.status_code == 503


def test_cria_pendente_e_repeticao_devolve_a_mesma(fila):
    pedido = _pedido()

    primeira = fila.post("/api/v1/solicitacoes", json=pedido)
    segunda = fila.post("/api/v1/solicitacoes", json=pedido)

    assert primeira.status_code == 201
    assert primeira.json()["status"] == "pendente"
    assert "reserva" not in primeira.json()
    assert segunda.status_code == 200
    assert segunda.json()["criadoEm"] == primeira.json()["criadoEm"]


def test_mesmo_id_com_outro_conteudo_e_conflito(fila):
    pedido = _pedido()
    fila.post("/api/v1/solicitacoes", json=pedido)
    pedido["payload"]["quantidade"] = 20

    resposta = fila.post("/api/v1/solicitacoes", json=pedido)

    assert resposta.status_code == 409


@pytest.mark.parametrize("payload, trecho", [
    ({"produto": "999-999"}, "não existe"),
    ({"armazem": "99"}, "Armazém 99"),
    ({"dataInicio": "2020-01-01", "dataEntrega": "2020-01-02"}, "entrega"),
])
def test_valida_contra_o_erp_antes_de_enfileirar(fila, payload, trecho):
    resposta = fila.post("/api/v1/solicitacoes", json=_pedido(**payload))

    assert resposta.status_code == 422
    assert trecho in resposta.json()["detail"]
    assert fila.get("/api/v1/solicitacoes").json() == []


def test_sem_leitura_do_erp_nada_e_enfileirado(fila, monkeypatch):
    def fora_do_ar(*_):
        raise RuntimeError("sem conexao")

    monkeypatch.setattr(mssql, "product_by_code", fora_do_ar)

    resposta = fila.post("/api/v1/solicitacoes", json=_pedido())

    assert resposta.status_code == 503
    assert fila.get("/api/v1/solicitacoes").json() == []


@pytest.mark.parametrize("payload", [
    {"quantidade": 0},
    {"quantidade": 1.234},
    {"armazem": "5"},
    {"dataEntrega": "2000-01-01"},
    {"sql": "DROP TABLE SC2010"},
])
def test_payload_invalido_e_recusado(fila, payload):
    resposta = fila.post("/api/v1/solicitacoes", json=_pedido(**payload))

    assert resposta.status_code == 422


def test_consumidor_exige_chave(fila, monkeypatch):
    assert fila.post("/api/v1/consumidor/reservar").status_code == 401
    assert fila.post("/api/v1/consumidor/reservar",
                     headers={"X-VettiFlow-Consumer-Key": "errada"}).status_code == 401
    monkeypatch.setattr(config, "QUEUE_CONSUMER_TOKEN", "")
    assert _reservar(fila).status_code == 503


def test_fluxo_completo_ate_aplicada(fila):
    pedido = _pedido()
    fila.post("/api/v1/solicitacoes", json=pedido)

    reservada = _reservar(fila)
    assert reservada.status_code == 200
    assert reservada.json()["status"] == "processando"
    assert reservada.json()["payload"]["produto"] == "575-0863"
    assert _reservar(fila).status_code == 204

    final = _resultado(fila, pedido["id"], reservada.json()["reserva"])

    assert final.status_code == 200
    assert final.json()["status"] == "aplicada"
    assert final.json()["protheusRefs"] == ["01643101001"]
    assert fila.conferencias == [["01643101001"]]
    detalhe = fila.get(f"/api/v1/solicitacoes/{pedido['id']}").json()
    assert [e["para"] for e in detalhe["eventos"]] == [
        "pendente", "processando", "aguardando_conferencia", "aplicada"]
    assert "reserva" not in detalhe


def test_dois_consumidores_nunca_pegam_o_mesmo_pedido(fila):
    fila.post("/api/v1/solicitacoes", json=_pedido())

    with ThreadPoolExecutor(max_workers=6) as pool:
        respostas = list(pool.map(lambda _: _reservar(fila), range(6)))

    assert sorted(r.status_code for r in respostas) == [200] + [204] * 5


def test_resultado_com_reserva_errada_e_recusado(fila):
    pedido = _pedido()
    fila.post("/api/v1/solicitacoes", json=pedido)
    _reservar(fila)

    resposta = _resultado(fila, pedido["id"], "outra-reserva")

    assert resposta.status_code == 409
    assert fila.get(f"/api/v1/solicitacoes/{pedido['id']}").json()["status"] == "processando"


def test_mesmo_resultado_reenviado_nao_muda_nada(fila):
    pedido = _pedido()
    fila.post("/api/v1/solicitacoes", json=pedido)
    reserva = _reservar(fila).json()["reserva"]
    _resultado(fila, pedido["id"], reserva)

    repetido = _resultado(fila, pedido["id"], reserva)

    assert repetido.status_code == 200
    assert repetido.json()["status"] == "aplicada"
    assert len(fila.conferencias) == 1


def test_rejeicao_sem_efeito_fica_rejeitada(fila):
    pedido = _pedido()
    fila.post("/api/v1/solicitacoes", json=pedido)
    reserva = _reservar(fila).json()["reserva"]

    resposta = _resultado(fila, pedido["id"], reserva, sucesso=False, semEfeito=True,
                          protheusRefs=[], mensagem="Produto sem estrutura")

    assert resposta.json()["status"] == "rejeitada"
    assert fila.conferencias == []


def test_falha_sem_garantia_de_rollback_fica_incerta(fila):
    pedido = _pedido()
    fila.post("/api/v1/solicitacoes", json=pedido)
    reserva = _reservar(fila).json()["reserva"]

    resposta = _resultado(fila, pedido["id"], reserva, sucesso=False, protheusRefs=[])

    assert resposta.json()["status"] == "incerta"
    assert _reservar(fila).status_code == 204


def test_reserva_vencida_vira_incerta_e_aceita_resultado_tardio(fila):
    pedido = _pedido()
    fila.post("/api/v1/solicitacoes", json=pedido)
    reserva = _reservar(fila).json()["reserva"]
    with sqlite3.connect(config.QUEUE_DB) as conn:
        conn.execute("UPDATE solicitacoes SET reservado_em = '2000-01-01T00:00:00+00:00'")

    assert _reservar(fila).status_code == 204
    vencida = fila.get(f"/api/v1/solicitacoes/{pedido['id']}").json()
    assert vencida["status"] == "incerta"

    tardio = _resultado(fila, pedido["id"], reserva)

    assert tardio.json()["status"] == "aplicada"


def test_resultado_de_sucesso_exige_referencia(fila):
    pedido = _pedido()
    fila.post("/api/v1/solicitacoes", json=pedido)
    reserva = _reservar(fila).json()["reserva"]

    resposta = _resultado(fila, pedido["id"], reserva, protheusRefs=[])

    assert resposta.status_code == 422


def test_sem_leitura_na_conferencia_fica_aguardando_e_pode_refazer(fila, monkeypatch):
    def fora_do_ar(_item):
        raise RuntimeError("sem conexao")

    pedido = _pedido()
    fila.post("/api/v1/solicitacoes", json=pedido)
    reserva = _reservar(fila).json()["reserva"]
    monkeypatch.setitem(solicitacoes._CONFERENCIAS, "abertura_op", fora_do_ar)

    resposta = _resultado(fila, pedido["id"], reserva)

    assert resposta.json()["status"] == "aguardando_conferencia"
    assert fila.post(f"/api/v1/solicitacoes/{pedido['id']}/conferir").status_code == 503
    monkeypatch.setitem(solicitacoes._CONFERENCIAS, "abertura_op",
                        lambda item: (True, "ok"))
    refeita = fila.post(f"/api/v1/solicitacoes/{pedido['id']}/conferir")
    assert refeita.json()["status"] == "aplicada"


def test_conferencia_divergente_fica_incerta(fila, monkeypatch):
    pedido = _pedido()
    fila.post("/api/v1/solicitacoes", json=pedido)
    reserva = _reservar(fila).json()["reserva"]
    monkeypatch.setitem(solicitacoes._CONFERENCIAS, "abertura_op",
                        lambda item: (False, "OP diverge do pedido: armazém 01."))

    resposta = _resultado(fila, pedido["id"], reserva)

    assert resposta.json()["status"] == "incerta"
    assert "armazém 01" in resposta.json()["mensagem"]


def _conferencia_real(monkeypatch, ordem, linhas=9):
    @contextmanager
    def conexao():
        yield None

    respostas = iter([ordem, {"linhas": linhas}])
    monkeypatch.setattr(mssql, "conexao", conexao)
    monkeypatch.setattr(mssql, "_fetchone", lambda *_: next(respostas))
    item = solicitacoes.Solicitacao(
        id="x", versao_contrato="v1", operacao="abertura_op", empresa="01",
        filial="04", payload={"produto": "575-0863", "quantidade": 10.0, "armazem": "05"},
        payload_hash="h", solicitante="t", executor="", status="aguardando_conferencia",
        reserva=None, reservado_em=None, protheus_refs=["01643101001"], mensagem="",
        log_execauto="", criado_em="", atualizado_em="")
    return solicitacoes.conferir_abertura(item)


def test_conferir_abertura_confirma_sc2(monkeypatch):
    confere, mensagem = _conferencia_real(
        monkeypatch, {"produto": "575-0863", "quantidade": 10.0, "armazem": "05"})

    assert confere is True
    assert "9 empenho" in mensagem


def test_conferir_abertura_aponta_divergencia(monkeypatch):
    confere, mensagem = _conferencia_real(
        monkeypatch, {"produto": "575-0863", "quantidade": 12.0, "armazem": "01"})

    assert confere is False
    assert "quantidade 12.0" in mensagem and "armazém 01" in mensagem


def test_conferir_abertura_sem_op(monkeypatch):
    confere, mensagem = _conferencia_real(monkeypatch, None)

    assert confere is False
    assert "não encontrada" in mensagem
