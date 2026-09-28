"""Configuracao do servico por variavel de ambiente."""

import os
import ssl
from pathlib import Path


def _load_local_env() -> None:
    """Carrega `api/.env` sem sobrescrever variaveis ja exportadas no sistema."""
    env_path = Path(__file__).resolve().parents[1] / ".env"
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


_load_local_env()


def _csv_env(nome: str, padrao: list[str]) -> list[str]:
    valor = os.getenv(nome, "").strip()
    if not valor:
        return padrao
    return [parte.strip() for parte in valor.split(",") if parte.strip()]


MSSQL_HOST = os.getenv("VF_PROTHEUS_HOST", "win-l1na6ce7lb4").strip()
MSSQL_PORT = int(os.getenv("VF_PROTHEUS_PORT", "1433"))
MSSQL_DATABASE = os.getenv("VF_PROTHEUS_DATABASE", "HMLp12").strip()
MSSQL_USER = os.getenv("VF_PROTHEUS_USER", "").strip()
MSSQL_PASSWORD = os.getenv("VF_PROTHEUS_PASSWORD", "")
MSSQL_SCHEMA = os.getenv("VF_PROTHEUS_SCHEMA", "dbo").strip() or "dbo"
MSSQL_DRIVER = os.getenv("VF_MSSQL_DRIVER", "ODBC Driver 17 for SQL Server")
MSSQL_ENCRYPT = os.getenv("VF_MSSQL_ENCRYPT", "No").strip()
MSSQL_TRUST_SERVER_CERT = os.getenv(
    "VF_MSSQL_TRUST_SERVER_CERT", "Yes"
).strip()

API_TOKEN = os.getenv("VF_API_TOKEN", "").strip()
CORS_ORIGINS = _csv_env("VF_CORS_ORIGINS", ["*"])

# Sufixo físico das tabelas (SC2010); não é o grupo enviado ao REST (01).
EMPRESA = os.getenv("VF_EMPRESA", "010")
FILIAL_PADRAO = os.getenv("VF_FILIAL", "04")
PROTHEUS_COMPANY_GROUP = os.getenv("VF_PROTHEUS_COMPANY_GROUP", "01").strip()
PROTHEUS_REST_URL = os.getenv("VF_PROTHEUS_REST_URL", "").strip().rstrip("/")

# Configuração do adapter AppServer legado, independente dos comandos SQL DEV.
WRITE_ENABLED = os.getenv("VF_WRITE_ENABLED", "false").lower() == "true"
# Fluxo SQL independente do adapter ADVPL e da fila de rascunhos antiga.
SQL_WRITE_ENABLED = os.getenv("VF_SQL_WRITE_ENABLED", "false").lower() == "true"
SQL_EXCLUSIVE_DEV = os.getenv("VF_SQL_EXCLUSIVE_DEV", "false").lower() == "true"
SQL_WRITE_TOKEN = os.getenv("VF_SQL_WRITE_TOKEN", "").strip()
PROTHEUS_WRITE_URL = os.getenv("VF_PROTHEUS_WRITE_URL", "").strip().rstrip("/")
WRITE_LEDGER = Path(os.getenv(
    "VF_WRITE_LEDGER", str(Path(__file__).resolve().parents[1] / "data" / "dev-writes.sqlite3")
))


def protheus_ssl_context() -> ssl.SSLContext:
    """Usa também as autoridades do Windows, mantendo cadeia e hostname validados."""
    return ssl.create_default_context()
