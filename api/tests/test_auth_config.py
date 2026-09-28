from fastapi.testclient import TestClient

from app import config, mssql
from app.main import app


def _client(monkeypatch):
    monkeypatch.setattr(
        mssql,
        "health",
        lambda: {"banco": "HMLp12", "servidor": "win-l1na6ce7lb4"},
    )
    return TestClient(app)


def test_health_local_fica_aberto_quando_token_nao_configurado(monkeypatch):
    monkeypatch.setattr(config, "API_TOKEN", "")

    with _client(monkeypatch) as client:
        response = client.get("/api/v1/health")

    assert response.status_code == 200


def test_api_recusa_sem_token_quando_token_configurado(monkeypatch):
    monkeypatch.setattr(config, "API_TOKEN", "segredo-teste")

    with _client(monkeypatch) as client:
        response = client.get("/api/v1/health")

    assert response.status_code == 401


def test_api_aceita_header_x_api_token(monkeypatch):
    monkeypatch.setattr(config, "API_TOKEN", "segredo-teste")

    with _client(monkeypatch) as client:
        response = client.get(
            "/api/v1/health",
            headers={"X-API-Token": "segredo-teste"},
        )

    assert response.status_code == 200
