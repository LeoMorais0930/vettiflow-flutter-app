# Fechamento

Rota: `/fechamento`.

A tela recebe as OPs na etapa de fechamento. Permite iniciar, pausar e concluir com assinatura e observação.
A ação atual chama `completeStage` e envia a OP para a próxima etapa planejada, normalmente expedição.

O método `completeClosing` existe no repositório, mas a ação principal da tela não o utiliza.
Portanto, não considerar implementada uma conferência de quantidade fechada apenas porque esse método existe.

Fechar uma etapa no VettiFlow não encerra a SC2 nem aponta produção no Protheus.
Falta ligar as quantidades boas, defeituosas e parciais à conferência final e à OP oficial.

Código: [ClosingPage](../../../../lib/ui/closing/closing_page.dart).
