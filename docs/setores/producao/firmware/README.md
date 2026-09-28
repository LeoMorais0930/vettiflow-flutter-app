# Gravação de firmware

Rota: `/firmware`.

1. Selecione uma OP da fila de gravação.
2. Inicie a operação; pause com motivo e PIN quando necessário.
3. Na conclusão, informe defeitos, se houver, e confirme a assinatura.
4. O fluxo local avança para a próxima etapa planejada.

A tela registra a execução e o tempo; não programa fisicamente o dispositivo nem executa apontamento no Protheus.
OPs e produtos consultados no ERP não alimentam automaticamente toda a fila desta tela.

Falta ligar o acompanhamento local à OP oficial e definir o registro de defeitos/retrabalho sem confundir defeito com perda de estoque.

Código: [FirmwarePage](../../../../lib/ui/firmware/firmware_page.dart).
