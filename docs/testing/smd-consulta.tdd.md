# SMD e filtro mensal — 24/09/2026

## Comportamento entregue

`/smd` lê SC2/SD3 do armazém 03, filial 04, com as mesmas consultas paginadas do almoxarifado. OPs abertas são a visualização inicial. Apontamentos, consumo, movimentos e estoque têm abas próprias. Quantidades fracionadas e usuário do movimento são preservados.

O seletor de mês/ano é compartilhado com almoxarifado e administração. Aceita todo o período ou intervalo personalizado, mantém o período entre abas e reinicia a paginação ao alterar filtros. OP usa emissão; estoque é atual.

## RED → GREEN

Antes da implementação, os quatro novos testes de tela falharam: SMD ainda dependia de FirmwarePage/fluxo local e o seletor mensal não existia. O novo teste da API falhou pela ausência de D3_USUARIO.

Após a implementação:

- `flutter test --coverage --reporter expanded`: **147 testes aprovados**.
- `flutter analyze`: **sem problemas**.
- `api/venv/Scripts/python.exe -m pytest api/tests -q`: **40 testes aprovados**. Permanece aviso de depreciação de httpx do ambiente de testes.
- Cobertura de linhas: consulta compartilhada **91,0%**, SMD **85,7%**, seletor mensal **81,0%**.

Os testes cobrem OPs oficiais abertas, filtros separados de produção/consumo, usuário, frações, 29/02/2024, persistência do mês entre abas, paginação reiniciada, todo o período sem corte, ausência de botões de escrita/avanço local, tela móvel e estoque atual.

Os testes de Paula/Leandro foram atualizados para uma API simulada de leitura. Os testes existentes do modelo de fluxo local e da produção foram preservados; não são evidência de escrita no ERP.

## Verificação com DEV

Consultas SELECT retornaram 19 OPs abertas do SMD. Setembro/2026 retornou nove apontamentos e 268 registros de consumo. O endpoint local, após reiniciar a API, respondeu HTTP 200 e `readOnly=true`, com os logins TATIANE e paulad nos nove apontamentos.

`flutter build web --no-pub --dart-define-from-file=.dart_tool/vettiflow-local-defines.json` concluído. No navegador, `/smd` mostrou as 19 OPs; selecionar setembro e trocar de Consumo para Apontamentos preservou o mês e exibiu os totais 268 e nove, respectivamente, com `paulad` nos cartões. Layout conferido sem sobreposição. API e app local permaneceram rodando em 8000 e 5174.

Evidência de negócio: [auditoria do SMD](../auditorias/2026-09-24/smd-apontamentos.md).
