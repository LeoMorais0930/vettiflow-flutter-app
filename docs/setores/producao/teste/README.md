# Teste de produção

Rota: `/teste`.

1. Selecione a OP, inicie e confira o roteiro exibido.
2. Registre os tipos de defeito e as quantidades no encerramento.
3. Confirme a assinatura solicitada. O fluxo local avança para a próxima etapa planejada.

Os defeitos ficam associados à OP e aparecem também no suporte.
O roteiro mostrado inclui verificações gerais e, quando disponível, uma referência ao primeiro componente; ainda não é uma ficha de testes homologada por produto.

A conclusão usa `completeTesting`, que tem tratamento diferente das sessões múltiplas de `completeStage`. Não assumir a mesma regra de encerramento coletivo sem corrigir e testar essa diferença.

Não há baixa de perda, abertura de atendimento oficial nem bloqueio fiscal automático.
Falta definir segregação de itens reprovados, retrabalho e destino físico sem avançar quantidades defeituosas como boas.

Código: [TestingPage](../../../../lib/ui/testing/testing_page.dart).
