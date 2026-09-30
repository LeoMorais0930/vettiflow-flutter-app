"""API VettiFlow: consultas Protheus e comandos SQL explícitos no DEV."""

import logging
import secrets
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query, Request, Security
from fastapi.security import APIKeyHeader, HTTPBearer
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.openapi.utils import get_openapi
from starlette.concurrency import run_in_threadpool

from . import config, mssql, warehouse_writes, sessions
from .sql_production_api import router as sql_production_router, status as sql_status
from .schemas import FinalizarRequest, Health, MutationBatch
from .warehouse import router as warehouse_router
from .warehouse_reports import router as warehouse_reports_router
from .protheus_auth import router as protheus_auth_router
from .solicitacoes import router as solicitacoes_router
from .flow_tracking import router as flow_tracking_router
from .commitment_review import router as commitment_review_router

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
    dependencies=[Security(APIKeyHeader(name=CABECALHO_TOKEN, auto_error=False)),
                  Security(HTTPBearer(scheme_name='ProtheusJWT', auto_error=False))],
    swagger_ui_parameters={'persistAuthorization': False},
)
app.include_router(protheus_auth_router)
app.include_router(warehouse_router)
app.include_router(warehouse_reports_router)
app.include_router(warehouse_writes.router)
app.include_router(sql_production_router)
app.include_router(solicitacoes_router)
app.include_router(flow_tracking_router)
app.include_router(commitment_review_router)


def secured_openapi():
    if app.openapi_schema is None:
        schema = get_openapi(title=app.title, version=app.version,
                             description=app.description, routes=app.routes)
        for path, operations in schema['paths'].items():
            for operation in operations.values():
                required = {'APIKeyHeader': []}
                if path not in {'/api/v1/auth/protheus/login', '/api/v1/auth/protheus/test'}:
                    required['ProtheusJWT'] = []
                # Um objeto significa AND: chave interna + JWT, não alternativas.
                operation['security'] = [required]
        app.openapi_schema = schema
    return app.openapi_schema


app.openapi = secured_openapi


@app.middleware("http")
async def exigir_token(request: Request, call_next):
    """Protege a API por `X-API-Token`, liberando loopback sem token em dev."""
    if request.method == "OPTIONS":
        return await call_next(request)

    origem = request.client.host if request.client else ""
    # Documentação acessível localmente; as operações continuam exigindo o token.
    if (request.method == 'GET' and origem in _LOOPBACK
            and request.url.path in {'/docs', '/docs/oauth2-redirect', '/redoc', '/openapi.json'}):
        return await call_next(request)
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

    public_auth = request.method == 'POST' and request.url.path in {
        '/api/v1/auth/protheus/test', '/api/v1/auth/protheus/login',
    }
    if not public_auth:
        try:
            await run_in_threadpool(sessions.require_session, request)
        except HTTPException as exc:
            return JSONResponse(status_code=exc.status_code,
                                content={'detail': exc.detail},
                                headers={**(exc.headers or {}), 'Cache-Control': 'no-store'})
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
    armazem: str | None = Query(default=None, pattern=r'^[A-Za-z0-9]{2}$'),
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


@app.get("/api/v1/ops/encerradas")
def ops_encerradas(
    filial: str = config.FILIAL_PADRAO,
    after: int = Query(default=0, ge=0),
    page_size: int = Query(default=2000, ge=1, le=2000),
) -> dict:
    return mssql.closed_orders(filial, after, page_size)


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
