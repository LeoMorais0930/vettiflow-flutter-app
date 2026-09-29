"""Diagnóstico de autenticação: não cria sessão VettiFlow nem executa rotinas ERP."""
from urllib.parse import urlsplit

import httpx
from fastapi import APIRouter, Header, HTTPException, Response, Request

from . import config, sessions

router = APIRouter(prefix='/api/v1/auth/protheus', tags=['Login Protheus — teste'])


def fail(status: int, message: str):
    raise HTTPException(status, message, headers={'Cache-Control': 'no-store'})


@router.post('/test', summary='Testar usuário e senha no Protheus', description=(
    'Valida credenciais no endpoint de token do Protheus via HTTPS. '
    'Não guarda nem devolve senha/access_token/refresh_token. '
    'Não cria sessão no app, não comprova permissões de movimentação nem executa ADVPL. '
    'Use Authorize com X-API-Token da API VettiFlow, depois Try it out.'))
def test_login(
    response: Response,
    username: str = Header(description='Usuário do Protheus'),
    password: str = Header(description='Senha do Protheus', json_schema_extra={'format': 'password'}),
) -> dict:
    response.headers['Cache-Control'] = 'no-store'
    status, _ = authenticate(username, password)
    return {'authenticated': True, 'upstreamStatus': status,
            'message': 'Protheus aceitou as credenciais e retornou token. Tokens descartados neste teste.',
            'erpWritesEnabled': False, 'appSessionCreated': False}


def authenticate(username: str, password: str, *, refresh_token: str | None = None) -> tuple[int, dict]:
    # Validação manual evita que erros Pydantic devolvam o valor da senha.
    if refresh_token is None and (not username.strip() or not password or len(username) > 128
            or len(password) > 512 or any(ord(c) < 32 or ord(c) > 126
                                        for c in username + password)):
        fail(422, 'Credenciais ausentes ou incompatíveis com o transporte por cabeçalhos HTTP.')
    url = config.PROTHEUS_REST_URL
    try:
        target = urlsplit(url)
        valid = (target.scheme == 'https' and target.hostname and not target.username
                 and not target.password and not target.query and not target.fragment)
    except ValueError:
        valid = False
    if not valid:
        fail(503, 'Configure VF_PROTHEUS_REST_URL com a URL HTTPS do REST DEV, sem credenciais.')
    try:
        result = httpx.post(
            url.rstrip('/') + '/api/oauth2/v1/token',
            params={'grant_type': 'refresh_token' if refresh_token else 'password'},
            headers={**({'refresh_token': refresh_token} if refresh_token else
                        {'username': username.strip(), 'password': password}),
                     'tenantId': f'{config.PROTHEUS_COMPANY_GROUP},{config.FILIAL_PADRAO}',
                     'Accept': 'application/json'},
            timeout=15, follow_redirects=False, trust_env=False,
            verify=config.protheus_ssl_context(),
        )
    except httpx.TimeoutException:
        fail(504, 'O Protheus não respondeu em até 15 segundos. Autenticação não confirmada.')
    except (httpx.HTTPError, ValueError):
        fail(502, 'Falha de conexão ou TLS com o Protheus. Verifique rede e certificado do DEV.')
    messages = {
        400: 'Protheus recusou a solicitação de autenticação. Verifique credenciais e contrato da versão instalada.',
        401: 'Protheus recusou a autenticação. Verifique usuário e senha.',
        403: 'Protheus negou o acesso deste usuário ao serviço.',
    }
    if result.status_code in messages:
        fail(result.status_code, messages[result.status_code])
    if result.status_code not in (200, 201):
        fail(502, f'Endpoint de autenticação retornou HTTP {result.status_code}. Autenticação não confirmada.')
    try:
        body = result.json()
    except ValueError:
        fail(502, 'Protheus retornou conteúdo não JSON. Autenticação não confirmada.')
    if not isinstance(body, dict):
        fail(502, 'Resposta de autenticação inesperada do Protheus.')
    if body.get('hasMFA'):
        fail(502, 'Protheus exige MFA. Este diagnóstico não implementa a segunda etapa.')
    token = body.get('access_token')
    if (not isinstance(token, str) or not token.strip()
            or str(body.get('token_type', '')).lower() != 'bearer'):
        fail(502, 'Protheus não retornou um token Bearer válido. Autenticação não confirmada.')
    return result.status_code, body


@router.post('/login', summary='Login e sessão JWT', description=(
    'Retorna o JWT do Protheus. Copie access_token para Authorize → ProtheusJWT. '
    'Não salva senha. Refresh token somente em memória no servidor; renovação até oito horas. '
    'limitada à expiração do ERP. Reiniciar esta API exige novo login.'))
def login(response: Response, username: str = Header(),
          password: str = Header(json_schema_extra={'format': 'password'})):
    response.headers['Cache-Control'] = 'no-store'
    status, body = authenticate(username, password)
    token = body['access_token']
    session = sessions.register(token, username.strip(), body.get('expires_in'), allow_online_clock=True)
    sessions.enable_refresh(session, body.get('refresh_token'))
    return _login_response(token, session, status)


def _login_response(token, session, status):
    return {'access_token': token, 'token_type': 'Bearer',
            'expiresAt': session['expiresAt'], 'upstreamStatus': status,
            'username': session['username'], 'validationMode': session['validationMode'],
            'refreshAvailable': bool(session.get('refreshToken')),
            'erpWritesEnabled': False}


@router.post('/refresh', summary='Renovar sessão pelo Protheus')
def refresh(request: Request, response: Response):
    response.headers['Cache-Control'] = 'no-store'
    token, session, status = sessions.rotate(
        request.state.protheus_token,
        lambda secret: authenticate('', '', refresh_token=secret))
    return _login_response(token, session, status)


@router.get('/session', summary='Consultar sessão VettiFlow (sem chamar ERP)')
def session_info(request: Request, response: Response):
    response.headers['Cache-Control'] = 'no-store'
    session = request.state.protheus_session
    return {'authenticated': True, 'username': session['username'],
            'expiresAt': session['expiresAt'], 'validationMode': session['validationMode'],
            'persistentAppServerConnection': False}


@router.post('/logout', summary='Encerrar sessão nesta API')
def logout(request: Request, response: Response):
    response.headers['Cache-Control'] = 'no-store'
    sessions.revoke(request.state.protheus_token)
    return {'loggedOut': True, 'scope': 'VettiFlow local; não revoga o token em outros serviços ERP'}


@router.post('/probe', summary='Fazer uma leitura no REST DEV com o JWT', description=(
    'Consulta somente metadados de prodOrders/fields. Não movimenta o ERP. '
    'A requisição pode aparecer brevemente no monitor do AppServer REST. '
    'Não mantém thread/SmartClient aberto nem renova a expiração.'))
def probe(request: Request, response: Response):
    response.headers['Cache-Control'] = 'no-store'
    try:
        result = httpx.get(
            config.PROTHEUS_REST_URL + '/api/pcp/v1/prodOrders/fields',
            headers={'Authorization': 'Bearer ' + request.state.protheus_token,
                     'tenantId': f'{config.PROTHEUS_COMPANY_GROUP},{config.FILIAL_PADRAO}',
                     'Accept': 'application/json'},
            timeout=15, follow_redirects=False, trust_env=False,
            verify=config.protheus_ssl_context())
    except httpx.TimeoutException:
        fail(504, 'Protheus não respondeu à leitura em até 15 segundos.')
    except httpx.HTTPError:
        fail(502, 'Falha de conexão/TLS durante a leitura autenticada.')
    if result.status_code == 401:
        sessions.revoke(request.state.protheus_token)
        fail(401, 'Protheus recusou o token. Sessão local encerrada; faça novo login.')
    if result.status_code == 403:
        fail(403, 'Protheus negou acesso aos metadados de OP.')
    if result.status_code != 200:
        fail(502, f'Leitura REST retornou HTTP {result.status_code}.')
    try:
        data = result.json()
    except ValueError:
        fail(502, 'Leitura REST retornou conteúdo não JSON.')
    if not isinstance(data, (dict, list)):
        fail(502, 'Resposta de metadados inesperada.')
    return {'upstreamStatus': 200, 'readCompleted': True,
            'username': request.state.protheus_session['username'],
            'persistentAppServerConnection': False,
            'message': 'Leitura concluída. A sessão do app continua até expirar; não há thread ERP permanente.'}
