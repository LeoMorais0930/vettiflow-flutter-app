# VettiFlow TV

Rota: `/tv`.

Mostra OPs ativas, etapas, prioridades, tempos e conclusões do fluxo local. Os painéis alternam automaticamente.
A TV é uma tela de acompanhamento e não aponta produção nem movimenta estoque. Armazenamento e despacho incluem os novos envios por quantidade; o despacho é líquido dos retornos de cliente. Esses totais ficam separados por unidade e continuam sendo dados locais.

No navegador, as abas da mesma origem podem compartilhar as atualizações pelo armazenamento local.
Outro computador ou outro perfil de navegador não recebe automaticamente esse mesmo fluxo.

Falta alimentar o painel com um serviço compartilhado e conciliar indicadores locais com os oficiais.
Uma tela vazia não prova ausência de OPs no Protheus: a fonte desta TV é `ProductionFlowStore`.

Código: [VettiFlowTvPage](../../../lib/ui/tv/vetti_flow_tv_page.dart).
