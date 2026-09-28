# Validação e continuidade

## Branches

`master` contém a base consolidada; `developer` é a branch de trabalho criada a partir dela. A consolidação não equivale a uma homologação de produção. O histórico anterior continua no Git.

## Verificações

Na raiz do projeto:

```powershell
flutter analyze --no-pub lib test
flutter test --no-pub
.\api\venv\Scripts\python.exe -m pytest api/tests -q
```

Use `flutter pub get` se as dependências ainda não estiverem instaladas. Os testes Python usam substitutos da conexão; não exigem executar escrita no ERP.

## Situação conhecida em 28/09/2026

Antes da consolidação, no commit `8329fe3`: análise de `lib` e `test` sem problemas, 77 testes Python aprovados, 173 testes Flutter aprovados e 42 falhas. A auditoria de dependências Python não encontrou vulnerabilidades conhecidas na resolução de `api/requirements.txt` feita nessa data.

Após resolver o merge com a `master` e limpar os documentos, as mesmas verificações foram repetidas: análise sem problemas, 77 testes Python aprovados, 173 testes Flutter aprovados e 42 falhas; auditoria Python sem vulnerabilidades conhecidas. Não foram executados builds nativos de Android, iOS, macOS ou Windows nesta consolidação.

As falhas Flutter incluem expectativas de navegação, permissões e apresentação de telas em expedição, produção e outros setores. A causa de cada falha ainda precisa ser diagnosticada; não presumir que todas sejam apenas testes desatualizados. Elas foram mantidas visíveis, sem apagar cobertura para obter uma suíte verde.

Os testes essenciais preservados cobrem fluxo de OP, materiais, envios/retornos, permissões, persistência, roteamento, relatórios, leitura do Protheus, autenticação da API e limites da preparação de escrita DEV.

## Limpeza

Removidos relatórios Word/PDF antigos, páginas renderizadas, capturas, JSONs de auditoria e diários de sprints. Guias atuais e conclusões técnicas continuam em `docs/`. Referências às evidências removidas usam links para o histórico do GitHub; não indicam arquivos que ainda estejam presentes no checkout.

A próxima frente na `developer` é diagnosticar as falhas Flutter, antes de considerar a base pronta para publicação operacional. Escrita no ERP e persistência compartilhada continuam pendências separadas, descritas na arquitetura e na preparação de escrita DEV.
