"""Prepara defines locais do Flutter sem imprimir credenciais."""
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "api"))
from app import config

if config.MSSQL_DATABASE.lower() != "hmlp12":
    raise SystemExit("A configuração não aponta para o banco DEV HMLp12.")

destination = root / ".dart_tool" / "vettiflow-local-defines.json"
destination.parent.mkdir(exist_ok=True)
destination.write_text(json.dumps({
    "VETTIFLOW_API_URL": "http://127.0.0.1:8000",
    "VETTIFLOW_API_TOKEN": config.API_TOKEN,
}), encoding="utf-8")
print("Configuração local preparada em .dart_tool/vettiflow-local-defines.json.")
