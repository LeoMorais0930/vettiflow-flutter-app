import copy
import pytest
from fastapi.testclient import TestClient
from app import config, commitment_review as review, solicitacoes
from app.main import app

OP = '01642901001'
PATH = f'/api/v1/ops/{OP}/revisao-empenhos'
CONSUMER = {'X-VettiFlow-Consumer-Key': 'test-consumer'}

@pytest.fixture
def setup(monkeypatch, tmp_path):
    for name, value in {'FLOW_DB': tmp_path/'flow.db', 'QUEUE_DB': tmp_path/'queue.db',
                        'FLOW_ADMIN_USERS': ['fixture-negocio'], 'QUEUE_ENABLED': True,
                        'QUEUE_EXECUTION_ENABLED': True, 'QUEUE_OPERATIONS': ['exclusao_empenhos'],
                        'QUEUE_CONSUMER_TOKEN': 'test-consumer'}.items():
        monkeypatch.setattr(config, name, value)
    monkeypatch.setattr(solicitacoes, '_stores', {})
    data = {'order': {'numero': OP, 'produto': 'PA', 'emissao': '20260929', 'encerrada': False,
                     'numeroBase':'016429','item':'01','sequencia':'001','itemGrade':'',
                     'quantidadePlanejada': 100, 'quantidadeProduzida': 0, 'local': '05'},
            'items': [dict(id=i, produto='MP01' if i<3 else 'MOD001', local='01',
                           quantidade=10, quantidadeOriginal=10, tratamento='001', loteControle=f'L{i}',
                           numeroLote='', opOrigem='', sequencia=str(i), descricao='Item', unidade='UN')
                      for i in (1,2,3)]}
    monkeypatch.setattr(review.mssql, 'commitment_review_snapshot', lambda *_: copy.deepcopy(data))
    with TestClient(app) as c:
        yield c, data

def saved(c):
    read = c.get(PATH).json()
    result = c.put(PATH, json={'expectedVersion': read['version'], 'fingerprint': read['fingerprint'],
                               'excluded': [{'id':1, 'reason':'Já disponível no setor'}]})
    assert result.status_code == 200
    return {'expectedVersion': result.json()['version'], 'fingerprint': result.json()['fingerprint']}

def test_submit_is_idempotent_and_preserves_exact_rows(setup):
    c, data = setup
    cmd = saved(c)
    first = c.post(PATH+'/enviar', json=cmd)
    assert first.status_code == 200, first.text
    assert first.json()['status'] == 'pendente'
    assert c.post(PATH+'/enviar', json=cmd).json()['id'] == first.json()['id']
    payload = first.json()['payload']
    assert payload['excluded'] == [{'id':1, 'reason':'Já disponível no setor'}]
    assert payload['snapshot']['items'] == data['items']
    assert first.json()['solicitante'] == 'fixture-negocio'
    state = c.get(PATH).json()
    assert state['submission']['id'] == first.json()['id']
    assert state['canSave'] is False
    assert c.put(PATH, json={**cmd, 'excluded':[]}).status_code == 409

@pytest.mark.parametrize('changed', ['fingerprint','version','permission','disabled','mod','empty'])
def test_submit_revalidates_before_queue(setup, monkeypatch, changed):
    c, data = setup
    cmd = saved(c)
    expected = 409
    if changed == 'fingerprint': data['items'][0]['quantidade'] = 11
    if changed == 'version': cmd['expectedVersion'] = 999
    if changed == 'permission':
        monkeypatch.setattr(config,'FLOW_ADMIN_USERS',[]); expected=403
    if changed == 'disabled':
        monkeypatch.setattr(config,'QUEUE_ENABLED',False); expected=503
    if changed == 'mod':
        data['items'][0]['produto']='MOD002'
    if changed == 'empty':
        result=c.put(PATH,json={**cmd,'excluded':[]}).json()
        cmd={'expectedVersion':result['version'],'fingerprint':result['fingerprint']}; expected=422
    assert c.post(PATH+'/enviar',json=cmd).status_code == expected
    assert c.get('/api/v1/solicitacoes').json() == []

def test_consumer_confirmation_reads_actual_remaining_rows(setup):
    c,data=setup
    item=c.post(PATH+'/enviar',json=saved(c)).json()
    assert 'id' in item, item
    reserved=c.post(f"/api/v1/consumidor/solicitacoes/{item['id']}/reservar",headers=CONSUMER).json()
    data['items']=data['items'][1:]
    result=c.post(f"/api/v1/consumidor/solicitacoes/{item['id']}/resultado",headers=CONSUMER,
                  json={'reserva':reserved['reserva'],'sucesso':True,'protheusRefs':[OP], 'executor':'vm-user'})
    assert result.status_code==200, result.text
    assert result.json()['status']=='aplicada'
    assert c.get(PATH).json()['submission']['status']=='aplicada'
    assert c.get(PATH).json()['appliedToErp'] is True

@pytest.mark.parametrize('damage',['still_present','retained_deleted','retained_changed','wrong_reference','read_failure'])
def test_does_not_accept_false_success(setup,monkeypatch,damage):
    c,data=setup
    item=c.post(PATH+'/enviar',json=saved(c)).json()
    assert 'id' in item, item
    reserved=c.post(f"/api/v1/consumidor/solicitacoes/{item['id']}/reservar",headers=CONSUMER).json()
    if damage!='still_present': data['items']=data['items'][1:]
    if damage=='retained_deleted': data['items']=data['items'][1:]
    if damage=='retained_changed': data['items'][0]['quantidade']=9
    if damage=='read_failure':
        def unavailable(*_): raise RuntimeError('private')
        monkeypatch.setattr(review.mssql,'commitment_review_snapshot',unavailable)
    result=c.post(f"/api/v1/consumidor/solicitacoes/{item['id']}/resultado",headers=CONSUMER,
                  json={'reserva':reserved['reserva'],'sucesso':True,'protheusRefs':['wrong' if damage=='wrong_reference' else OP]})
    assert result.status_code==200
    assert result.json()['status']==('aguardando_conferencia' if damage=='read_failure' else 'incerta')

def test_consumer_key_alone_does_not_bypass_jwt(setup):
    c,_=setup
    assert c.get('/api/v1/consumidor/pendentes',headers={**CONSUMER,'Authorization':''}).status_code==401


def test_duplicate_native_key_cannot_target_wrong_line(setup):
    c,data=setup
    data['items'][1].update(loteControle='L1',sequencia='1')
    result=c.post(PATH+'/enviar',json=saved(c))
    assert result.status_code==409
    assert 'identificação nativa duplicada' in result.json()['detail']


def test_other_user_cannot_queue_concurrent_review(setup, monkeypatch):
    from uuid import uuid4
    from app.solicitacoes_store import NovaSolicitacao, ConflitoError
    c,_=setup
    queued=c.post(PATH+'/enviar',json=saved(c)).json()
    duplicate=NovaSolicitacao(str(uuid4()), queued['versaoContrato'],queued['operacao'],
                             queued['empresa'],queued['filial'],queued['payload'],'other-admin')
    with pytest.raises(ConflitoError):
        solicitacoes.store().criar(duplicate)


def test_retry_after_execution_returns_original_and_no_new_write(setup):
    c,data=setup
    cmd=saved(c)
    queued=c.post(PATH+'/enviar',json=cmd).json()
    reserved=c.post(f"/api/v1/consumidor/solicitacoes/{queued['id']}/reservar",headers=CONSUMER).json()
    data['items']=data['items'][1:]
    c.post(f"/api/v1/consumidor/solicitacoes/{queued['id']}/resultado",headers=CONSUMER,
           json={'reserva':reserved['reserva'],'sucesso':True,'protheusRefs':[OP]})
    retry=c.post(PATH+'/enviar',json=cmd)
    assert retry.status_code==200
    assert retry.json()['id']==queued['id']
    assert retry.json()['status']=='aplicada'
    assert len(c.get('/api/v1/solicitacoes').json())==1
