import pytest

from app import config


@pytest.fixture(autouse=True, scope="session")
def _sem_token_do_env():
    """Isola a suite do `api/.env` da máquina, que é diferente em cada dev."""
    anterior = config.API_TOKEN
    config.API_TOKEN = ""
    yield
    config.API_TOKEN = anterior
