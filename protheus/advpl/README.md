# Fontes ADVPL do VettiFlow

Consumidores da fila de solicitações da API (`api/app/solicitacoes.py`). A API
nunca grava no Protheus: ela guarda o pedido, entrega a um consumidor com reserva
exclusiva e confere o resultado por SELECT. Quem grava é a rotina oficial,
chamada por estes fontes via ExecAuto.

**Estado: escrito, não compilado nem homologado.** Nada aqui foi executado no RPO.

| Fonte | Operação | Rotina | Modo |
| --- | --- | --- | --- |
| `VFFILA01.prw` | `abertura_op` | MATA650 | Opção de menu, um pedido por vez, com confirmação |

## Fluxo do `U_VFFILA01`

1. Confere o ambiente logado (grupo 01, filial 04).
2. `GET /consumidor/pendentes`: só consulta, nada é reservado.
3. Mostra cada pedido; o usuário confirma um.
4. `POST /consumidor/solicitacoes/{id}/reservar`: reserva exclusiva.
5. `VFAbreOP`: MATA650 por ExecAuto dentro de `Begin Transaction`, sem nenhuma tela.
6. `POST /consumidor/solicitacoes/{id}/resultado`, com até 3 tentativas. Se o
   retorno falhar, o fonte **não executa de novo**: mostra a referência para
   conferência manual.
7. A API confere a OP na SC2/SD4 e marca `aplicada`, ou `incerta` se divergir.

Como o resultado é classificado:

| Situação | Enviado | Estado na fila |
| --- | --- | --- |
| MATA650 ok e OP achada na SC2 | `sucesso=true`, refs | `aguardando_conferencia` → `aplicada` |
| MATA650 recusou e a OP **não** existe após o rollback | `semEfeito=true` | `rejeitada` |
| MATA650 recusou e a OP existe | `semEfeito=false` | `incerta` |
| Exceção no meio da rotina | `semEfeito=false` | `incerta` |

## Configuração

No `appserver.ini` do ambiente DEV (fora do SX6, para a chave não aparecer no
configurador):

```ini
[VETTIFLOW]
Url=http://servidor-da-api:8000/api/v1
ConsumerKey=<VF_QUEUE_CONSUMER_TOKEN da API>
ApiToken=<VF_API_TOKEN da API, se configurado>
```

Na API (`api/.env`): `VF_QUEUE_ENABLED=true`, `VF_QUEUE_CONSUMER_TOKEN=<chave aleatória>`.
Ver `api/.env.example`.

Menu: cadastrar `U_VFFILA01` no módulo de PCP pelo configurador, só para os
usuários que vão processar a fila.

## Roteiro do primeiro teste no DEV

1. Criar um pedido pela API (troque o `id` a cada pedido novo):

   ```bash
   curl -X POST http://localhost:8000/api/v1/solicitacoes \
     -H 'Content-Type: application/json' \
     -d '{"id":"6f1c2b9e-0000-4000-8000-000000000001","versaoContrato":"vettiflow.solicitacao.v1","operacao":"abertura_op","solicitante":"teste","payload":{"produto":"575-0863","quantidade":10,"armazem":"05","dataInicio":"2026-09-29","dataEntrega":"2026-09-30"}}'
   ```

2. No Protheus DEV, rodar `U_VFFILA01` e confirmar o pedido.
3. Conferir o estado: `GET /api/v1/solicitacoes/{id}` (traz o histórico e o log).
4. Comparar SC2 e SD4 da OP gerada com uma abertura manual equivalente, feita
   pela tela, no mesmo dia.

## Pendências antes de homologar

- [ ] Compilar no RPO do DEV (quem tem acesso ainda não está confirmado).
- [ ] `AUTEXPLODE="S"`: confirmar que gera a SD4 e as intermediárias como a tela.
- [ ] `GetSXENum("SC2","C2_NUM")` + `ConfirmSX8`/`RollBackSX8`: confirmar que é
      como a Vetti numera OP (a tela pode usar outro inicializador).
- [ ] Confirmar que `MTA650I` (`C2_VOP`/`C2_VGRU`) e `A650LEMP` disparam pelo
      ExecAuto. Pontos só de tela (ex. `MTA650GEM`) não disparam.
- [ ] Validar o `ErrorBlock` + `Begin Transaction`: se uma exceção deixa a
      transação desfeita. Até lá, exceção é tratada como `incerta`.
- [ ] Autorização por solicitante: hoje quem confirma no menu é o usuário
      logado, e o nome do solicitante vem do app sem validação.
- [ ] `C2_OBS` recebe `VF:<8 primeiros do id>` para conferência manual. É
      provisório até existir um campo próprio (`C2_XVFID`), gravado na mesma
      transação.
- [ ] Testes do plano: sucesso, rejeição, mesmo id repetido, queda antes do retorno.
