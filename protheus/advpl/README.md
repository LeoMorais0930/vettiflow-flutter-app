# Fontes ADVPL do VettiFlow

**Preparados para compilação e homologação no DEV. Não compilados nesta entrega.**

| Fonte | Função | Responsabilidade |
| --- | --- | --- |
| `VFFILA01.prw` | `U_VFFILA01(cSessionToken)` | Autentica, lista/reserva pedidos, abre OP pela MATA650 e devolve resultados |
| `VFEMP01.prw` | `U_VFEMP01(oPed)` | Executor interno: exclusão seletiva de empenhos pela MATA381 |

Compilar os dois arquivos no mesmo RPO. Somente `U_VFFILA01` deve ser opção de
menu, restrita aos executores autorizados. `U_VFEMP01` não é uma tela de menu.

A criação usa `GERAOPI="N"`, `GERASC="N"`, `GERAEMP="S"` e `AUTEXPLODE="S"`:
somente a OP solicitada, sem gerar intermediárias, mantendo seus empenhos.
A exclusão usa MATA381 em alteração (4), com LINPOS e AUTDELETA por linha.
A API não escreve nas tabelas do ERP.

O menu exige o JWT do mesmo usuário logado no Protheus e as chaves da API e do
consumidor. Não há dispensa de JWT nem impersonação do usuário do Flutter. O
JWT temporário pode ser fornecido pelo parâmetro ou `SessionToken` do ini DEV.
É preciso renovar manualmente o login quando expirar durante esta homologação.

Configuração completa, limites e passos de validação estão em
[Revisão de empenhos](HOMOLOGACAO.md).

## Pendências do RPO

- Compilar os dois fontes com os includes instalados no DEV.
- Confirmar MATA650/numeração SX8, geração de SD4 sem intermediárias/SCs.
- Validar pontos Vetti MTA650I/A650LEMP e quaisquer efeitos de tela não chamados por ExecAuto.
- Validar MATA381/LINPOS, lotes/endereço, permissões e atualização de saldos.
- Validar locks, rollback, concorrência e resultado perdido.
- Processamento automático contínuo exige uma etapa posterior; o consumidor atual é de menu.

Se a resposta à API falhar, o consumidor reenvia somente o resultado, nunca
repete o ExecAuto. A reserva vencida fica incerta e exige conferência manual.
