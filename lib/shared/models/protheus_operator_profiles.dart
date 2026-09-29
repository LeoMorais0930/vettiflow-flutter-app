import 'operator.dart';

/// Vínculos de interface confirmados com o cadastro exportado em 29/09/2026.
/// A autenticação e as permissões da API continuam independentes deste cadastro.
abstract final class ProtheusOperatorProfiles {
  static final List<Operator> operators = List.unmodifiable([
    _profile(
      'tatiane',
      'Tatiane',
      WorkArea.production,
      WorkStage.firmware,
      manager: true,
    ),
    _profile(
      'andressa.camargo',
      'Andressa Camargo',
      WorkArea.production,
      WorkStage.firmware,
      manager: true,
    ),
    _profile(
      'paulad',
      'Paula Daniela Soares Moraes',
      WorkArea.smd,
      WorkStage.smd,
      manager: true,
    ),
    _profile('leandro', 'Leandro Marin', WorkArea.smd, WorkStage.smd),
    _profile(
      'vera',
      'Vera Pezzota',
      WorkArea.warehouse,
      WorkStage.warehouse,
      manager: true,
    ),
    _profile(
      'luis',
      'Luis Fernando Saez Angelini',
      WorkArea.warehouse,
      WorkStage.warehouse,
    ),
    _profile(
      'silvania.teixeira',
      'Silvania Teixeira da Silva',
      WorkArea.warehouse,
      WorkStage.warehouse,
    ),
    _profile(
      'rosangela.prestes',
      'Rosangela Prestes',
      WorkArea.warehouse,
      WorkStage.warehouse,
    ),
    _profile(
      'bruno',
      'Bruno',
      WorkArea.support,
      WorkStage.support,
      manager: true,
    ),
    _profile(
      'vinicius',
      'Vinicius Queiroz',
      WorkArea.support,
      WorkStage.support,
      manager: true,
    ),
    _profile(
      'douglas',
      'Douglas Lopes Miguel',
      WorkArea.support,
      WorkStage.support,
    ),
    _profile(
      'matheus',
      'Matheus Goncalves',
      WorkArea.support,
      WorkStage.support,
    ),
    _profile(
      'natalina.rosimeire',
      'Natalina Rosimeire Bozzi Baptista',
      WorkArea.support,
      WorkStage.support,
    ),
    _profile(
      'gabriel.fontes',
      'Gabriel Fontes',
      WorkArea.support,
      WorkStage.support,
    ),
    // Conta compartilhada confirmada; a identidade permanece sendo expedicao.
    _profile(
      'expedicao',
      'Bruna e Tamara',
      WorkArea.production,
      WorkStage.expedition,
    ),
    const Operator(
      name: 'Artur Augusto',
      username: 'artur',
      password: '',
      pin: '',
      stage: WorkStage.dashboard,
      role: 'Administrador VettiFlow',
      area: WorkArea.system,
      canManageAssignments: true,
    ),
    const Operator(
      name: 'Vitor Vasconcelos',
      username: 'vitor.vasconcelos',
      password: '',
      pin: '',
      stage: WorkStage.dashboard,
      role: 'Administrador VettiFlow',
      area: WorkArea.system,
      canManageAssignments: true,
    ),
    const Operator(
      name: 'Leonardo Morais',
      username: 'leonardo.morais',
      password: '',
      pin: '',
      stage: WorkStage.dashboard,
      role: 'Administrador VettiFlow',
      area: WorkArea.system,
      canManageAssignments: true,
    ),
  ]);

  static Operator _profile(
    String username,
    String name,
    WorkArea area,
    WorkStage stage, {
    bool manager = false,
  }) => Operator(
    username: username,
    name: name,
    password: '',
    pin: '',
    stage: stage,
    area: area,
    usesAssignedStage: true,
    canManageAssignments: manager,
    managesArea: manager ? area : null,
    role: manager ? 'Gestor do setor' : 'Operador',
  );

  static Operator? find(String username) => operators
      .where((actor) => actor.username == username.trim().toLowerCase())
      .firstOrNull;
}
