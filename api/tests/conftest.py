import pytest

from app import config


@pytest.fixture(autouse=True, scope="session")
def _sem_token_do_env():
    """Isola a suite do `api/.env` da máquina, que é diferente em cada dev."""
    anterior = config.API_TOKEN
    config.API_TOKEN = ""
    yield
    config.API_TOKEN = anterior


@pytest.fixture(autouse=True)
def _sessao_dos_testes_de_negocio(request, monkeypatch):
    """Fixtures de negócio usam sessão registrada; testes de login exercitam login real.

    Não desliga o middleware: injeta um JWT sintético registrado apenas nos
    clientes de teste legados que verificam SQL, relatórios e chave de API.
    """
    if request.node.path.name in {'test_jwt_sessions.py', 'test_protheus_auth.py'}:
        yield
        return
    import base64
    import json
    import time
    import uuid
    from fastapi.testclient import TestClient
    from app import sessions
    original = TestClient.__init__
    tokens = []

    def authenticated_client(self, *args, **kwargs):
        payload = base64.urlsafe_b64encode(json.dumps({
            'exp': time.time() + 3600, 'sub': 'fixture-negocio',
        }).encode()).decode().rstrip('=')
        token = 'eyJhbGciOiJIUzI1NiJ9.' + payload + '.' + uuid.uuid4().hex
        sessions.register(token, 'fixture-negocio', 3600)
        tokens.append(token)
        kwargs['headers'] = {'Authorization': 'Bearer ' + token, **(kwargs.get('headers') or {})}
        original(self, *args, **kwargs)

    monkeypatch.setattr(TestClient, '__init__', authenticated_client)
    yield
    for token in tokens:
        sessions.revoke(token)
