# VettiFlow Flutter App

Aplicativo Flutter para acompanhar os setores da Vetti e consultar o Protheus DEV.
A integração com o ERP é somente leitura. As operações locais do app continuam separadas dos documentos oficiais.

## Documentação

Comece pelo [índice por setor](docs/README.md). O [guia de arquitetura](docs/desenvolvimento/arquitetura.md) explica o que está integrado e o que falta.

## Executar localmente no Windows

Pré-requisitos: Flutter no PATH, Python, driver ODBC para SQL Server e acesso à rede do DEV.
Configure `api/.env` conforme [a documentação da API](api/README.md), sem substituir um arquivo já preenchido.

Na raiz, prepare dependências quando necessário:

```powershell
flutter pub get
python -m venv api/venv
.\api\venv\Scripts\python.exe -m pip install -r api/requirements.txt
```

Terminal 1, na raiz:

```powershell
.\api\venv\Scripts\python.exe -m uvicorn app.main:app --app-dir api --host 127.0.0.1 --port 8000
```

Terminal 2, na raiz:

```powershell
.\api\venv\Scripts\python.exe scripts/preparar_web_local.py
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5174 --dart-define-from-file=.dart_tool/vettiflow-local-defines.json
```

Abra [VettiFlow](http://127.0.0.1:5174). O script reutiliza o token local da API sem imprimi-lo. O arquivo gerado fica em `.dart_tool`, ignorada pelo Git.
Use Ctrl+C nos terminais para encerrar. Se as portas já estiverem ocupadas por uma instância do app, encerre essa instância antes de iniciar outra.

## Organização

- `lib/`: telas, modelos e repositórios Flutter.
- `api/`: FastAPI e consultas ao SQL Server DEV.
- `test/` e `api/tests/`: testes.
- `docs/setores/`: funcionamento e pendências por setor.
- `docs/desenvolvimento/`: arquitetura e padrão visual.
- `docs/auditorias/` e `docs/pesquisa_protheus_2026-09-24/`: conclusões técnicas essenciais.
- Relatórios antigos, capturas e dados brutos permanecem recuperáveis no histórico Git.

## Verificar alterações

```powershell
flutter analyze --no-pub lib test
flutter test --no-pub
.\api\venv\Scripts\python.exe -m pytest api/tests -q
```

## Branches

- `master`: base consolidada.
- `developer`: trabalho diário, criada a partir da `master`.

Veja [validação e pendências](docs/desenvolvimento/validacao.md) antes de publicar uma nova versão.
