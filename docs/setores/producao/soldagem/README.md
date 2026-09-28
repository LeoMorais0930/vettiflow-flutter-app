# Soldagem

Rota: `/soldagem`.

A fila contém as OPs na etapa de soldagem do fluxo local. Permite iniciar, pausar, retomar e enviar para a próxima etapa com assinatura.
As sessões dos colaboradores são registradas no fluxo. Em `completeStage`, a etapa só avança quando não restam sessões ativas nela.

Isso não transfere material entre armazéns e não baixa componentes no Protheus.
Soldagem manual e produção SMD têm telas distintas no app.

Falta conciliar os materiais realmente utilizados com os empenhos oficiais e tratar retrabalho conforme o processo adotado pela Vetti.

Código: [SolderingPage](../../../../lib/ui/soldering/soldering_page.dart).
