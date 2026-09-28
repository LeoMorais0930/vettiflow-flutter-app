"""Os tipos que trafegam entre o VettiFlow e esta API.

Espelham `lib/data/models/pending_mutation.dart` no app Flutter. Quando um dos
lados mudar, o outro precisa mudar junto — os testes em `tests/` guardam o
formato do envelope contra isso.
"""
from datetime import datetime
from enum import Enum
from typing import Literal, Optional, Union

from pydantic import BaseModel, Field


class MutationStatus(str, Enum):
    pendente = "pendente"
    enviando = "enviando"
    armazenado = "armazenado"
    enviado = "enviado"
    erro = "erro"


class EmpenhoOperacao(str, Enum):
    incluir = "incluir"
    alterar = "alterar"
    excluir = "excluir"


class EmpenhoLinha(BaseModel):
    produto: str
    descricao: str = ""
    quantidade: float
    local: str
    structureSequence: str = ""


class AberturaOpPayload(BaseModel):
    produto: str
    produtoDescricao: str = ""
    quantidade: int
    localProducao: str
    previsao: Optional[str] = None
    observacao: Optional[str] = None
    # Vazio significa "usa a estrutura padrão do produto" (SG1), que é o que o
    # Protheus faz sozinho ao abrir a OP.
    empenhos: list[EmpenhoLinha] = Field(default_factory=list)


class EmpenhoPayload(BaseModel):
    op: str
    operacao: EmpenhoOperacao
    produto: str
    produtoDescricao: str = ""
    local: str
    quantidade: float = 0
    quantidadeAnterior: Optional[float] = None
    localAnterior: Optional[str] = None
    motivo: Optional[str] = None


class TransferenciaPayload(BaseModel):
    produto: str
    produtoDescricao: str = ""
    quantidade: float
    localOrigem: str
    localDestino: str
    op: Optional[str] = None
    motivo: Optional[str] = None


class BaixaComponente(BaseModel):
    produto: str
    local: str
    quantidade: float


class BaixaProducaoPayload(BaseModel):
    op: str
    produto: str
    produtoDescricao: str = ""
    quantidadeProduzida: int
    localProducao: str
    componentes: list[BaixaComponente] = Field(default_factory=list)


class _Envelope(BaseModel):
    id: str
    filial: str
    criadoEm: datetime
    autor: str
    status: MutationStatus = MutationStatus.pendente
    erro: Optional[str] = None
    protheusRef: Optional[str] = None


class AberturaOpMutation(_Envelope):
    kind: Literal["aberturaOp"]
    payload: AberturaOpPayload


class EmpenhoMutation(_Envelope):
    kind: Literal["empenho"]
    payload: EmpenhoPayload


class TransferenciaMutation(_Envelope):
    kind: Literal["transferencia"]
    payload: TransferenciaPayload


class BaixaProducaoMutation(_Envelope):
    kind: Literal["baixaProducao"]
    payload: BaixaProducaoPayload


Mutation = Union[
    AberturaOpMutation, EmpenhoMutation, TransferenciaMutation, BaixaProducaoMutation
]


class MutationBatch(BaseModel):
    """Um lote vai inteiro numa requisição.

    As mutações de uma mesma OP têm ordem entre si (incluir um empenho antes de
    alterá-lo), e mandar uma a uma abriria espaço para aplicar metade.
    """

    mutations: list[Mutation] = Field(default_factory=list, discriminator=None)


class MutationResult(BaseModel):
    id: str
    status: MutationStatus
    protheusRef: Optional[str] = None
    erro: Optional[str] = None


class BatchResult(BaseModel):
    results: list[MutationResult]


class FinalizarRequest(BaseModel):
    ids: list[str] = Field(min_length=1)


class Health(BaseModel):
    ok: bool
    banco: str
    aplicando: bool
    readOnly: bool
    empresa: str
