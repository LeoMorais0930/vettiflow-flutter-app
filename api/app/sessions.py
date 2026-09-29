"""Sessões locais de tokens recebidos diretamente do ERP por HTTPS.

Não aceita JWT arbitrário por decodificação: exige hash exato de token emitido
no login desta instância. Não possui a chave de assinatura privada do Protheus.
Memória de um único worker; reiniciar encerra todas as sessões VettiFlow.
"""
import base64
import hashlib
import json
import math
import threading
import time
import httpx

from fastapi import HTTPException, Request

from . import config

_lock = threading.Lock()
_active: dict[str, dict] = {}


def _target():
    return (config.PROTHEUS_REST_URL, config.PROTHEUS_COMPANY_GROUP, config.FILIAL_PADRAO)


def _key(token):
    return hashlib.sha256(token.encode()).hexdigest()


def _invalid(code: str, message: str, **diagnostic):
    raise HTTPException(502, {'code': code, 'message': message, **diagnostic},
                        headers={'Cache-Control': 'no-store'})


def validate_online(token: str):
    """ERP decide a validade; endpoint deve recusar controle negativo primeiro."""
    url = config.PROTHEUS_REST_URL + '/api/pcp/v1/prodOrders/fields'
    options = dict(timeout=10, follow_redirects=False, trust_env=False,
                   verify=config.protheus_ssl_context())
    headers = {'tenantId': f'{config.PROTHEUS_COMPANY_GROUP},{config.FILIAL_PADRAO}',
               'Accept': 'application/json'}
    try:
        control = httpx.get(url, headers={**headers, 'Authorization': 'Bearer vettiflow-invalid-probe'}, **options)
        if control.status_code != 401:
            raise HTTPException(503, 'Validação online indisponível: endpoint não recusou o token de controle.')
        result = httpx.get(url, headers={**headers, 'Authorization': 'Bearer ' + token}, **options)
        if result.status_code in (401, 403):
            revoke(token)
            raise HTTPException(result.status_code, 'O próprio Protheus recusou o JWT ou o acesso. Sessão bloqueada.')
        if result.status_code != 200 or not isinstance(result.json(), (dict, list)):
            raise HTTPException(503, 'Protheus não confirmou a validação online do JWT.')
    except (httpx.HTTPError, ValueError):
        raise HTTPException(503, 'Não foi possível validar o JWT no Protheus. Acesso bloqueado.') from None


def register(token: str, username: str, expires_in, *, allow_online_clock=False, publish=True) -> dict:
    # Claims lidas somente APÓS resposta HTTPS confiável do endpoint de login.
    # A confiança vem dessa origem + registro do hash, não de decode sem assinatura.
    if not isinstance(token, str) or len(token) > 16384:
        _invalid('jwt_format', 'Token ausente ou maior que o limite suportado.')
    parts = token.split('.')
    if len(parts) != 3 or not all(parts):
        _invalid('jwt_format', 'O token recebido não contém os três segmentos JWT esperados.',
                 segments=len(parts))
    try:
        claims = json.loads(base64.urlsafe_b64decode(parts[1] + '=' * (-len(parts[1]) % 4)))
    except (ValueError, TypeError, UnicodeError):
        _invalid('jwt_payload', 'Não foi possível ler o payload JSON do JWT retornado pelo ERP.')
    if not isinstance(claims, dict):
        _invalid('jwt_payload', 'O payload JWT recebido não é um objeto JSON.')
    if 'exp' not in claims:
        _invalid('exp_missing', 'O JWT retornado pelo ERP não contém o campo exp.')
    try:
        exp = float(claims['exp'])
        if isinstance(claims['exp'], bool) or not math.isfinite(exp):
            raise ValueError()
    except (ValueError, TypeError, OverflowError):
        _invalid('exp_invalid', 'O campo exp do JWT não é um número de segundos válido.')
    if expires_in is None:
        _invalid('expires_in_missing', 'A resposta do ERP não contém expires_in válido.')
    try:
        lifetime = float(expires_in)
        if isinstance(expires_in, bool) or not math.isfinite(lifetime) or lifetime <= 0:
            raise ValueError()
    except (ValueError, TypeError, OverflowError):
        _invalid('expires_in_invalid', 'expires_in precisa indicar uma duração positiva em segundos.')
    now = time.time()
    online = False
    if exp <= now:
        timing = {}
        try:
            issued = float(claims.get('iat'))
            if not isinstance(claims.get('iat'), bool) and math.isfinite(issued):
                timing = {'issuedSecondsAgo': round(max(-1e10, min(now - issued, 1e10))),
                          'tokenLifetimeSeconds': round(max(-1e10, min(exp - issued, 1e10)))}
        except (ValueError, TypeError, OverflowError):
            pass
        # Contorno específico do desvio de uma hora observado no DEV, nunca
        # aceitação genérica de JWT vencido. Revalida no ERP em toda requisição.
        online = (allow_online_clock and config.MSSQL_DATABASE.lower() == 'hmlp12'
                  and config.PROTHEUS_COMPANY_GROUP == '01' and config.FILIAL_PADRAO == '04'
                  and 0 < now-exp <= 120 and abs(lifetime-3600) <= 1
                  and abs(timing.get('tokenLifetimeSeconds', 0)-3600) <= 1
                  and 3600 <= timing.get('issuedSecondsAgo', 0) <= 3720)
        if online:
            validate_online(token)
        else:
            _invalid('token_expired', 'O exp recebido indica token já expirado no relógio desta API. '
                     'Confira data/hora da emissão no AppServer REST.',
                     expiredSecondsAgo=round(min(now - exp, 1e10)), expiresInSeconds=lifetime,
                     **timing)
    expires = min(now + lifetime, now + 300) if online else min(exp, now + lifetime, now + 3600)
    session = {'username': username, 'expiresAt': expires, 'target': _target(),
               'validationMode': 'protheus_online' if online else 'registered_token'}
    if not publish:
        return session
    with _lock:
        for key in list(_active):
            if _active[key]['expiresAt'] <= now:
                del _active[key]
        if len(_active) >= 1000:
            raise HTTPException(503, 'Limite de sessões atingido.')
        _active[_key(token)] = session
    return session


def require_session(request: Request) -> dict:
    header = request.headers.get('Authorization', '')
    scheme, _, token = header.partition(' ')
    if scheme.lower() != 'bearer' or not token or len(token) > 16384:
        raise HTTPException(401, 'Faça login no Protheus e informe o Bearer JWT.',
                            headers={'WWW-Authenticate': 'Bearer'})
    with _lock:
        session = _active.get(_key(token))
        if session and (session['expiresAt'] <= time.time() or session['target'] != _target()):
            _active.pop(_key(token), None)
            session = None
    if session is None:
        raise HTTPException(401, 'Sessão ausente, expirada ou encerrada. Faça login novamente.',
                            headers={'WWW-Authenticate': 'Bearer'})
    if session.get('validationMode') == 'protheus_online':
        validate_online(token)
        # Uma revogação concorrente ou expiração durante a rede deve prevalecer.
        with _lock:
            if _active.get(_key(token)) is not session or session['expiresAt'] <= time.time():
                raise HTTPException(401, 'Sessão encerrada ou expirada durante a validação.')
    request.state.protheus_token = token
    request.state.protheus_session = session
    return session


def revoke(token: str):
    with _lock:
        _active.pop(_key(token), None)


def enable_refresh(session: dict, secret, absolute_expiry=None):
    if isinstance(secret, str) and 0 < len(secret) <= 16384 and all(32 <= ord(c) <= 126 for c in secret):
        session['refreshToken'] = secret
    session['absoluteExpiry'] = absolute_expiry or time.time() + 8 * 3600
    session['refreshLock'] = threading.Lock()


def rotate(token: str, exchange):
    with _lock:
        previous = _active.get(_key(token))
    if not previous or not previous.get('refreshToken'):
        raise HTTPException(401, 'Entre novamente: renovação indisponível para esta sessão.')
    with previous['refreshLock']:
        with _lock:
            if (_active.get(_key(token)) is not previous
                    or min(previous['expiresAt'], previous['absoluteExpiry']) <= time.time()):
                raise HTTPException(401, 'Sessão encerrada ou expirada.')
        try:
            status, body = exchange(previous['refreshToken'])
        except HTTPException as exc:
            if exc.status_code in (400, 401, 403):
                revoke(token)
                raise HTTPException(401, 'Protheus recusou a renovação. Entre novamente.') from None
            raise
        # Serializa publicação com logout; uma resposta tardia não ressuscita sessão.
        new_token = body['access_token']
        renewed = register(new_token, previous['username'], body.get('expires_in'), allow_online_clock=True, publish=False)
        with _lock:
            current = _active.get(_key(token))
            if current is not previous or previous['absoluteExpiry'] <= time.time():
                raise HTTPException(401, 'Sessão encerrada durante a renovação.')
            enable_refresh(renewed, body.get('refresh_token'), previous['absoluteExpiry'])
            renewed['expiresAt'] = min(renewed['expiresAt'], previous['absoluteExpiry'])
            if new_token != token:
                _active.pop(_key(token), None)
            _active[_key(new_token)] = renewed
        return new_token, renewed, status
