"""Garantias de entrada da API read-only do VettiFlow."""

from fastapi.testclient import TestClient

from app import config, mssql


def _patch_health(monkeypatch):
    monkeypatch.setattr(
        mssql,
        "health",
        lambda: {"banco": "HMLp12", "servidor": "win-l1na6ce7lb4"},
    )


def cliente_com_token(monkeypatch):
    monkeypatch.setattr(config, "API_TOKEN", "token-de-teste")
    _patch_health(monkeypatch)
    from app import main

    return TestClient(main.app)


def cliente_sem_token(monkeypatch):
    monkeypatch.setattr(config, "API_TOKEN", "")
    _patch_health(monkeypatch)
    from app import main

    return TestClient(main.app)


def test_sem_cabecalho_a_api_recusa(monkeypatch):
    with cliente_com_token(monkeypatch) as client:
        resposta = client.get("/api/v1/health")

    assert resposta.status_code == 401
    assert "X-API-Token" in resposta.json()["detail"]


def test_token_errado_recusa(monkeypatch):
    with cliente_com_token(monkeypatch) as client:
        resposta = client.get(
            "/api/v1/health", headers={"X-API-Token": "token-errado"}
        )

    assert resposta.status_code == 401


def test_token_certo_passa(monkeypatch):
    with cliente_com_token(monkeypatch) as client:
        resposta = client.get(
            "/api/v1/health", headers={"X-API-Token": "token-de-teste"}
        )

    assert resposta.status_code == 200
    assert resposta.json()["ok"] is True


def test_mutations_tambem_exige_token(monkeypatch):
    with cliente_com_token(monkeypatch) as client:
        resposta = client.post("/api/v1/mutations", json={"mutations": []})

    assert resposta.status_code == 401


def test_sem_token_configurado_o_loopback_passa(monkeypatch):
    with cliente_sem_token(monkeypatch) as client:
        resposta = client.get("/api/v1/health")

    assert resposta.status_code == 200


def test_sem_token_configurado_a_rede_e_recusada(monkeypatch):
    monkeypatch.setattr(config, "API_TOKEN", "")
    _patch_health(monkeypatch)
    from app import main

    with TestClient(main.app, client=("10.36.0.37", 5000)) as remoto:
        resposta = remoto.get("/api/v1/health")

    assert resposta.status_code == 503
    assert "VF_API_TOKEN" in resposta.json()["detail"]


def test_preflight_do_cors_nao_precisa_de_token(monkeypatch):
    with cliente_com_token(monkeypatch) as client:
        resposta = client.options(
            "/api/v1/mutations",
            headers={
                "Origin": "http://10.36.0.37:8080",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "x-api-token",
            },
        )

    assert resposta.status_code == 200
    assert "access-control-allow-origin" in resposta.headers
