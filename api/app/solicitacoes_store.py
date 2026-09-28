"""Armazenamento da fila de solicitações consumida pelo ADVPL.

A fila é dado próprio do VettiFlow: nada aqui toca tabela do Protheus. A
interface existe para trocar o SQLite (DEV, uma instância da API) pelo SQL
Server sem mexer em quem usa.

Estados:
    pendente -> processando -> aguardando_conferencia -> aplicada
    processando -> rejeitada   (só com ausência de efeito confirmada)
    processando/aguardando_conferencia -> incerta
Uma solicitação `incerta` nunca volta sozinha para `pendente`.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import secrets
import sqlite3
from typing import Any, Iterator

PENDENTE = "pendente"
PROCESSANDO = "processando"
AGUARDANDO_CONFERENCIA = "aguardando_conferencia"
APLICADA = "aplicada"
REJEITADA = "rejeitada"
INCERTA = "incerta"


class ConflitoError(Exception):
    """Mesmo id com conteúdo diferente, ou transição fora de ordem."""


class NaoEncontradaError(Exception):
    pass


class ReservaInvalidaError(Exception):
    """Resultado enviado por quem não detém a reserva."""


@dataclass(frozen=True)
class NovaSolicitacao:
    id: str
    versao_contrato: str
    operacao: str
    empresa: str
    filial: str
    payload: dict[str, Any]
    solicitante: str

    @property
    def payload_hash(self) -> str:
        texto = json.dumps(
            {"operacao": self.operacao, "empresa": self.empresa,
             "filial": self.filial, "payload": self.payload},
            sort_keys=True, ensure_ascii=False, separators=(",", ":"),
        )
        return hashlib.sha256(texto.encode()).hexdigest()


@dataclass(frozen=True)
class Resultado:
    """O que o consumidor ADVPL devolve depois de chamar a rotina."""
    sucesso: bool
    sem_efeito: bool = False
    protheus_refs: list[str] = field(default_factory=list)
    mensagem: str = ""
    log_execauto: str = ""
    executor: str = ""


@dataclass(frozen=True)
class Solicitacao:
    id: str
    versao_contrato: str
    operacao: str
    empresa: str
    filial: str
    payload: dict[str, Any]
    payload_hash: str
    solicitante: str
    executor: str
    status: str
    reserva: str | None
    reservado_em: str | None
    protheus_refs: list[str]
    mensagem: str
    log_execauto: str
    criado_em: str
    atualizado_em: str


class SolicitacaoStore(ABC):
    @abstractmethod
    def criar(self, nova: NovaSolicitacao) -> tuple[Solicitacao, bool]:
        """Grava como `pendente`. Repetir o mesmo id e conteúdo devolve a
        existente (`False`); mesmo id com outro conteúdo é conflito."""

    @abstractmethod
    def obter(self, id_: str) -> Solicitacao | None: ...

    @abstractmethod
    def listar(self, status: str | None = None, limit: int = 50) -> list[Solicitacao]: ...

    @abstractmethod
    def reservar(self, operacoes: list[str], minutos: int) -> Solicitacao | None:
        """Passa a mais antiga `pendente` para `processando`, atomicamente."""

    @abstractmethod
    def reservar_id(self, id_: str, minutos: int) -> Solicitacao | None:
        """Reserva uma solicitação específica, se ainda estiver `pendente`."""

    @abstractmethod
    def registrar_resultado(self, id_: str, reserva: str, resultado: Resultado) -> Solicitacao: ...

    @abstractmethod
    def concluir_conferencia(self, id_: str, confere: bool, mensagem: str) -> Solicitacao: ...

    @abstractmethod
    def eventos(self, id_: str) -> list[dict[str, Any]]: ...


def _agora() -> datetime:
    return datetime.now(timezone.utc)


def _iso(momento: datetime) -> str:
    return momento.isoformat(timespec="seconds")


_SCHEMA = """
CREATE TABLE IF NOT EXISTS solicitacoes (
    id TEXT PRIMARY KEY,
    versao_contrato TEXT NOT NULL,
    operacao TEXT NOT NULL,
    empresa TEXT NOT NULL,
    filial TEXT NOT NULL,
    payload TEXT NOT NULL,
    payload_hash TEXT NOT NULL,
    solicitante TEXT NOT NULL,
    executor TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL,
    reserva TEXT,
    reservado_em TEXT,
    protheus_refs TEXT NOT NULL DEFAULT '[]',
    mensagem TEXT NOT NULL DEFAULT '',
    log_execauto TEXT NOT NULL DEFAULT '',
    criado_em TEXT NOT NULL,
    atualizado_em TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS solicitacoes_status ON solicitacoes (status, criado_em);
CREATE TABLE IF NOT EXISTS solicitacao_eventos (
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    solicitacao_id TEXT NOT NULL REFERENCES solicitacoes (id),
    de TEXT,
    para TEXT NOT NULL,
    em TEXT NOT NULL,
    detalhe TEXT NOT NULL DEFAULT ''
);
"""


class SqliteSolicitacaoStore(SolicitacaoStore):
    """Serve para uma instância da API. Com mais de uma, usar SQL Server."""

    def __init__(self, caminho: Path):
        self.caminho = caminho
        caminho.parent.mkdir(parents=True, exist_ok=True)
        with self._conexao() as conn:
            conn.executescript(_SCHEMA)

    @contextmanager
    def _conexao(self) -> Iterator[sqlite3.Connection]:
        conn = sqlite3.connect(self.caminho, timeout=15, isolation_level=None)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()

    @contextmanager
    def _transacao(self) -> Iterator[sqlite3.Connection]:
        with self._conexao() as conn:
            conn.execute("BEGIN IMMEDIATE")
            try:
                yield conn
            except BaseException:
                conn.execute("ROLLBACK")
                raise
            conn.execute("COMMIT")

    @staticmethod
    def _linha(row: sqlite3.Row | None) -> Solicitacao | None:
        if row is None:
            return None
        return Solicitacao(
            id=row["id"], versao_contrato=row["versao_contrato"],
            operacao=row["operacao"], empresa=row["empresa"],
            filial=row["filial"], payload=json.loads(row["payload"]),
            payload_hash=row["payload_hash"], solicitante=row["solicitante"],
            executor=row["executor"], status=row["status"],
            reserva=row["reserva"], reservado_em=row["reservado_em"],
            protheus_refs=json.loads(row["protheus_refs"]),
            mensagem=row["mensagem"], log_execauto=row["log_execauto"],
            criado_em=row["criado_em"], atualizado_em=row["atualizado_em"],
        )

    def _buscar(self, conn: sqlite3.Connection, id_: str) -> Solicitacao | None:
        return self._linha(conn.execute(
            "SELECT * FROM solicitacoes WHERE id = ?", (id_,)).fetchone())

    @staticmethod
    def _evento(conn, id_: str, de: str | None, para: str, detalhe: str = "") -> None:
        conn.execute(
            "INSERT INTO solicitacao_eventos (solicitacao_id, de, para, em, detalhe)"
            " VALUES (?, ?, ?, ?, ?)", (id_, de, para, _iso(_agora()), detalhe[:1000]))

    def _expirar(self, conn, minutos: int) -> None:
        limite = _iso(_agora() - timedelta(minutes=minutos))
        vencidas = conn.execute(
            "SELECT id FROM solicitacoes WHERE status = ? AND reservado_em < ?",
            (PROCESSANDO, limite)).fetchall()
        for row in vencidas:
            conn.execute(
                "UPDATE solicitacoes SET status = ?, mensagem = ?, atualizado_em = ?"
                " WHERE id = ? AND status = ?",
                (INCERTA, "Reserva venceu sem retorno do consumidor. Confira no Protheus"
                 " antes de qualquer novo pedido.", _iso(_agora()), row["id"], PROCESSANDO))
            self._evento(conn, row["id"], PROCESSANDO, INCERTA, "reserva vencida")

    def criar(self, nova: NovaSolicitacao) -> tuple[Solicitacao, bool]:
        with self._transacao() as conn:
            existente = self._buscar(conn, nova.id)
            if existente:
                if existente.payload_hash != nova.payload_hash:
                    raise ConflitoError(
                        "Este id já foi usado com outro conteúdo. Consulte a solicitação"
                        " original antes de criar outra.")
                return existente, False
            agora = _iso(_agora())
            conn.execute(
                "INSERT INTO solicitacoes (id, versao_contrato, operacao, empresa, filial,"
                " payload, payload_hash, solicitante, status, criado_em, atualizado_em)"
                " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (nova.id, nova.versao_contrato, nova.operacao, nova.empresa, nova.filial,
                 json.dumps(nova.payload, ensure_ascii=False, sort_keys=True),
                 nova.payload_hash, nova.solicitante, PENDENTE, agora, agora))
            self._evento(conn, nova.id, None, PENDENTE)
            return self._buscar(conn, nova.id), True

    def obter(self, id_: str) -> Solicitacao | None:
        with self._conexao() as conn:
            return self._buscar(conn, id_)

    def listar(self, status: str | None = None, limit: int = 50) -> list[Solicitacao]:
        sql = "SELECT * FROM solicitacoes"
        params: tuple = ()
        if status:
            sql += " WHERE status = ?"
            params = (status,)
        sql += " ORDER BY criado_em DESC LIMIT ?"
        with self._conexao() as conn:
            return [self._linha(r) for r in conn.execute(sql, (*params, limit))]

    def reservar(self, operacoes: list[str], minutos: int) -> Solicitacao | None:
        if not operacoes:
            return None
        marcadores = ",".join("?" * len(operacoes))
        with self._transacao() as conn:
            self._expirar(conn, minutos)
            row = conn.execute(
                f"SELECT id FROM solicitacoes WHERE status = ? AND operacao IN ({marcadores})"
                " ORDER BY criado_em, id LIMIT 1", (PENDENTE, *operacoes)).fetchone()
            if row is None:
                return None
            return self._reservar(conn, row["id"])

    def reservar_id(self, id_: str, minutos: int) -> Solicitacao | None:
        with self._transacao() as conn:
            self._expirar(conn, minutos)
            return self._reservar(conn, id_)

    def _reservar(self, conn, id_: str) -> Solicitacao | None:
        agora = _iso(_agora())
        cursor = conn.execute(
            "UPDATE solicitacoes SET status = ?, reserva = ?, reservado_em = ?,"
            " atualizado_em = ? WHERE id = ? AND status = ?",
            (PROCESSANDO, secrets.token_hex(16), agora, agora, id_, PENDENTE))
        if cursor.rowcount != 1:
            return None
        self._evento(conn, id_, PENDENTE, PROCESSANDO)
        return self._buscar(conn, id_)

    def registrar_resultado(self, id_: str, reserva: str, resultado: Resultado) -> Solicitacao:
        with self._transacao() as conn:
            atual = self._buscar(conn, id_)
            if atual is None:
                raise NaoEncontradaError(id_)
            if not atual.reserva or not secrets.compare_digest(atual.reserva, reserva):
                raise ReservaInvalidaError(id_)
            # Resultado tardio (reserva já vencida para `incerta`) é aceito da
            # mesma reserva: vai para conferência, nunca direto para aplicada.
            if atual.status not in (PROCESSANDO, INCERTA):
                # O ADVPL reenvia o mesmo resultado se a resposta se perdeu.
                # A conferência reescreve a mensagem, então compara só refs e desfecho.
                mesmo_desfecho = resultado.sucesso == (
                    atual.status in (AGUARDANDO_CONFERENCIA, APLICADA))
                if mesmo_desfecho and atual.protheus_refs == list(resultado.protheus_refs):
                    return atual
                raise ConflitoError(
                    f"Solicitação em '{atual.status}' não aceita outro resultado.")
            if resultado.sucesso:
                novo = AGUARDANDO_CONFERENCIA
            elif resultado.sem_efeito and atual.status == PROCESSANDO:
                novo = REJEITADA
            else:
                novo = INCERTA
            conn.execute(
                "UPDATE solicitacoes SET status = ?, protheus_refs = ?, mensagem = ?,"
                " log_execauto = ?, executor = ?, atualizado_em = ? WHERE id = ?",
                (novo, json.dumps(resultado.protheus_refs), resultado.mensagem[:2000],
                 resultado.log_execauto[:20000], resultado.executor[:80],
                 _iso(_agora()), id_))
            self._evento(conn, id_, atual.status, novo, resultado.mensagem)
            return self._buscar(conn, id_)

    def concluir_conferencia(self, id_: str, confere: bool, mensagem: str) -> Solicitacao:
        with self._transacao() as conn:
            atual = self._buscar(conn, id_)
            if atual is None:
                raise NaoEncontradaError(id_)
            if atual.status != AGUARDANDO_CONFERENCIA:
                raise ConflitoError(
                    f"Solicitação em '{atual.status}' não está aguardando conferência.")
            novo = APLICADA if confere else INCERTA
            conn.execute(
                "UPDATE solicitacoes SET status = ?, mensagem = ?, atualizado_em = ?"
                " WHERE id = ? AND status = ?",
                (novo, mensagem[:2000], _iso(_agora()), id_, AGUARDANDO_CONFERENCIA))
            self._evento(conn, id_, AGUARDANDO_CONFERENCIA, novo, mensagem)
            return self._buscar(conn, id_)

    def eventos(self, id_: str) -> list[dict[str, Any]]:
        with self._conexao() as conn:
            return [dict(r) for r in conn.execute(
                "SELECT de, para, em, detalhe FROM solicitacao_eventos"
                " WHERE solicitacao_id = ? ORDER BY seq", (id_,))]
