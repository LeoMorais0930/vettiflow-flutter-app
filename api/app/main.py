"""API VettiFlow: consultas Protheus e comandos SQL explícitos no DEV."""

import logging
import secrets
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from . import config, mssql, warehouse_writes
from .sql_production_api import router as sql_production_router, status as sql_status
from .schemas import FinalizarRequest, Health, MutationBatch
from .warehouse import router as warehouse_router
from .warehouse_reports import router as warehouse_reports_router

log = logging.getLogger("vetti_flow_api")

CABECALHO_TOKEN = "X-API-Token"
_LOOPBACK = {"127.0.0.1", "::1", "localhost", "testclient"}
_READ_ONLY_DETAIL = "Backend Protheus dev esta em modo somente leitura."


@asynccontextmanager
async def lifespan(_: FastAPI):
    if not config.API_TOKEN:
        log.warning("VF_API_TOKEN vazio - atendendo so localhost")
    yield


app = FastAPI(
    title="VettiFlow Protheus",
    version="0.3.0",
    description=__doc__,
    lifespan=lifespan,
)
app.include_router(warehouse_router)
app.include_router(warehouse_reports_router)
app.include_router(warehouse_writes.router)
app.include_router(sql_production_router)


@app.middleware("http")
async def exigir_token(request: Request, call_next):
    """Protege a API por `X-API-Token`, liberando loopback sem token em dev."""
    if request.method == "OPTIONS":
        return await call_next(request)

    origem = request.client.host if request.client else ""
    if config.API_TOKEN:
        enviado = request.headers.get(CABECALHO_TOKEN, "")
        if not secrets.compare_digest(enviado, config.API_TOKEN):
            return JSONResponse(
                status_code=401,
                content={"detail": f"{CABECALHO_TOKEN} ausente ou invalido"},
            )
    elif origem not in _LOOPBACK:
        log.warning("recusando %s: VF_API_TOKEN nao configurado", origem)
        return JSONResponse(
            status_code=503,
            content={
                "detail": "API sem VF_API_TOKEN configurado; so atende localhost"
            },
        )

    return await call_next(request)


app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/v1/health", response_model=Health)
def health() -> Health:
    info = mssql.health()
    return Health(
        ok=True,
        banco=info.get("banco") or config.MSSQL_DATABASE,
        aplicando=False,
        readOnly=warehouse_writes.readiness(info)["readOnly"] and not (
            sql_status()['enabled'] and str(info.get('banco', '')).lower() == 'hmlp12'
        ),
        empresa=config.EMPRESA,
    )


@app.get("/api/v1/write-readiness")
def write_readiness() -> dict:
    return mssql.write_readiness()


@app.get("/api/v1/produtos")
def produtos(
    query: str = "",
    limit: int = Query(default=12, ge=1, le=250),
    filial: str = config.FILIAL_PADRAO,
) -> list[dict]:
    return mssql.search_products(query, filial, limit)


@app.get("/api/v1/produtos/{codigo}")
def produto(codigo: str, filial: str = config.FILIAL_PADRAO) -> dict:
    code = codigo.strip().upper()
    product = mssql.product_by_code(code, filial)
    if product is None:
        raise HTTPException(status_code=404, detail="Produto nao encontrado")
    return {
        "filial": filial,
        "armazem": "",
        "product": product,
        "components": mssql.components_for(code, filial),
        "smdReleaseOrders": [],
    }


@app.get("/api/v1/ops/{op}/empenhos")
def empenhos(op: str, filial: str = config.FILIAL_PADRAO) -> list[dict]:
    return mssql.commitments_for(op, filial)


@app.get("/api/v1/ops/{op}/movimentos")
def movimentos_op(op: str, filial: str = config.FILIAL_PADRAO) -> dict:
    return mssql.op_movements(op, filial)


@app.get("/api/v1/ops/{op}/apontamento-preview")
def apontamento_preview(
    op: str,
    filial: str = config.FILIAL_PADRAO,
    quantidade: float | None = Query(default=None, gt=0),
    armazem: str | None = Query(default=None, pattern=r"^[A-Za-z0-9]{2}$"),
) -> dict:
    return mssql.production_completion_preview(
        op=op,
        filial=filial,
        quantidade=quantidade,
        armazem=armazem,
    )


@app.get("/api/v1/transferencias")
def transferencias(
    filial: str = config.FILIAL_PADRAO,
    produto: str = "",
    localOrigem: str = "",
    localDestino: str = "",
    limit: int = Query(default=20, ge=1, le=100),
) -> dict:
    return mssql.transfer_movements(
        filial=filial,
        produto=produto,
        local_origem=localOrigem,
        local_destino=localDestino,
        limit=limit,
    )


@app.get("/api/v1/desmontagens")
def desmontagens(
    filial: str = config.FILIAL_PADRAO,
    documento: str = "",
    produto: str = "",
    limit: int = Query(default=20, ge=1, le=100),
) -> dict:
    return mssql.dismantling_movements(
        filial=filial,
        documento=documento,
        produto=produto,
        limit=limit,
    )


@app.get("/api/v1/auditoria-estoque")
def auditoria_estoque(
    filial: str = config.FILIAL_PADRAO,
    documento: str = "",
    op: str = "",
    produto: str = "",
    tipo: str = "",
    limit: int = Query(default=50, ge=1, le=200),
) -> dict:
    return mssql.inventory_audit_movements(
        filial=filial,
        documento=documento,
        op=op,
        produto=produto,
        tipo=tipo,
        limit=limit,
    )


@app.get("/api/v1/ops/abertas")
def ops_abertas(filial: str = config.FILIAL_PADRAO) -> list[dict]:
    return mssql.open_orders(filial)


@app.get("/api/v1/produtos/{codigo}/saldos")
def saldos(codigo: str, filial: str = config.FILIAL_PADRAO) -> list[dict]:
    return mssql.stock_by_code(codigo, filial)


@app.get("/api/v1/locais")
def locais(filial: str = config.FILIAL_PADRAO) -> list[dict]:
    return mssql.warehouses(filial)


@app.post("/api/v1/mutations")
def armazenar(_lote: MutationBatch) -> None:
    raise HTTPException(status_code=503, detail=_READ_ONLY_DETAIL)


@app.post("/api/v1/finalizar")
def finalizar(_req: FinalizarRequest) -> None:
    raise HTTPException(status_code=503, detail=_READ_ONLY_DETAIL)


@app.get("/api/v1/mutations/{id_}")
def consultar(id_: str) -> dict:
    raise HTTPException(status_code=503, detail=_READ_ONLY_DETAIL)


@app.get("/api/v1/ops/{op}/armazenadas")
def armazenadas_da_op(op: str) -> list[dict]:
    raise HTTPException(status_code=503, detail=_READ_ONLY_DETAIL)
