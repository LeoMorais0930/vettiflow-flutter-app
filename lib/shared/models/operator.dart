/// Etapa de trabalho do operador — define pra qual tela ele é direcionado.
enum WorkStage {
  dashboard('Dashboard', '/dashboard'),
  smd('SMD', '/smd'),
  firmware('Gravacao', '/firmware'),
  soldering('Soldagem', '/soldagem'),
  testing('Teste', '/teste'),
  closing('Fechamento', '/fechamento'),
  expedition('Expedicao', '/expedicao'),
  warehouse('Almoxarifado', '/almoxarifado'),
  support('Suporte', '/suporte'),
  tv('VettiFlow TV', '/tv');

  const WorkStage(this.label, this.route);

  final String label;
  final String route;
}

enum WorkArea {
  production('Producao'),
  smd('SMD'),
  warehouse('Almoxarifado'),
  support('Suporte'),
  system('Sistema');

  const WorkArea(this.label);

  final String label;
}

enum OperatorPermission {
  operation('Somente operação'),
  consultation('Operação e consultas'),
  manager('Gestor do setor');

  const OperatorPermission(this.label);
  final String label;
}

class Operator {
  const Operator({
    required this.name,
    required this.username,
    required this.password,
    required this.pin,
    required this.stage,
    this.role = 'Operador',
    this.usesAssignedStage = false,
    bool canManageAssignments = false,
    this.permission,
    this.area = WorkArea.production,
    this.managesArea,
    // Mantém o nome público do parâmetro usado pelo cadastro existente.
    // ignore: prefer_initializing_formals
  }) : _canManageAssignments = canManageAssignments;

  final String name;
  final String username;
  final String password;
  final String pin;
  final WorkStage stage;
  final String role;
  final bool usesAssignedStage;
  final bool _canManageAssignments;
  final OperatorPermission? permission;
  bool get canManageAssignments => permission == null
      ? _canManageAssignments
      : permission == OperatorPermission.manager;
  OperatorPermission get effectivePermission =>
      permission ??
      (canManageAssignments
          ? OperatorPermission.manager
          : OperatorPermission.operation);
  final WorkArea area;
  final WorkArea? managesArea;

  Operator copyWithStage(WorkStage stage, {OperatorPermission? permission}) {
    final access = permission ?? this.permission;
    return Operator(
      name: name,
      username: username,
      password: password,
      pin: pin,
      stage: stage,
      role: role,
      usesAssignedStage: usesAssignedStage,
      canManageAssignments: _canManageAssignments,
      permission: access,
      area: area,
      managesArea:
          access == OperatorPermission.manager && area != WorkArea.system
          ? area
          : access != null && access != OperatorPermission.manager
          ? null
          : managesArea,
    );
  }

  static const all = [
    Operator(
      name: 'Tatiane',
      username: 'tatiane',
      password: '1001',
      pin: '1001',
      stage: WorkStage.dashboard,
      role: 'Coordenadora da producao',
      canManageAssignments: true,
      area: WorkArea.production,
      managesArea: WorkArea.production,
    ),
    Operator(
      name: 'Tatiane',
      username: 'tatiane',
      password: '2001',
      pin: '2001',
      stage: WorkStage.firmware,
      role: 'Coordenadora na producao',
      usesAssignedStage: true,
      canManageAssignments: true,
      area: WorkArea.production,
      managesArea: WorkArea.production,
    ),
    Operator(
      name: 'Andressa',
      username: 'andressa',
      password: '1002',
      pin: '1002',
      stage: WorkStage.dashboard,
      role: 'Ajudante da coordenadora',
      canManageAssignments: true,
      area: WorkArea.production,
      managesArea: WorkArea.production,
    ),
    Operator(
      name: 'Andressa',
      username: 'andressa',
      password: '2002',
      pin: '2002',
      stage: WorkStage.firmware,
      role: 'Ajudante na producao',
      usesAssignedStage: true,
      canManageAssignments: true,
      area: WorkArea.production,
      managesArea: WorkArea.production,
    ),
    Operator(
      name: 'Paula',
      username: 'paula',
      password: '1003',
      pin: '1003',
      stage: WorkStage.dashboard,
      role: 'Gestora do SMD',
      canManageAssignments: true,
      area: WorkArea.smd,
      managesArea: WorkArea.smd,
    ),
    Operator(
      name: 'Bruno',
      username: 'bruno',
      password: '1004',
      pin: '1004',
      stage: WorkStage.dashboard,
      role: 'Gestor do suporte',
      canManageAssignments: true,
      area: WorkArea.support,
      managesArea: WorkArea.support,
    ),
    Operator(
      name: 'Vinicius',
      username: 'vinicius',
      password: '1006',
      pin: '1006',
      stage: WorkStage.dashboard,
      role: 'Gestor do suporte',
      canManageAssignments: true,
      area: WorkArea.support,
      managesArea: WorkArea.support,
    ),
    Operator(
      name: 'Vera',
      username: 'vera',
      password: '1005',
      pin: '1005',
      stage: WorkStage.dashboard,
      role: 'Gestora do almoxarifado',
      canManageAssignments: true,
      area: WorkArea.warehouse,
      managesArea: WorkArea.warehouse,
    ),
    Operator(
      name: 'Juliana',
      username: 'juliana',
      password: '3001',
      pin: '3001',
      stage: WorkStage.firmware,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Sabrina',
      username: 'sabrina',
      password: '3002',
      pin: '3002',
      stage: WorkStage.testing,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Pedro H',
      username: 'pedro h',
      password: '3022',
      pin: '3022',
      stage: WorkStage.firmware,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Bryan',
      username: 'bryan',
      password: '3003',
      pin: '3003',
      stage: WorkStage.soldering,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Giovana',
      username: 'giovana',
      password: '3004',
      pin: '3004',
      stage: WorkStage.testing,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Miriam',
      username: 'miriam',
      password: '3005',
      pin: '3005',
      stage: WorkStage.closing,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Rafaela',
      username: 'rafaela',
      password: '3006',
      pin: '3006',
      stage: WorkStage.expedition,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Katlyn',
      username: 'katlyn',
      password: '3007',
      pin: '3007',
      stage: WorkStage.soldering,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Lohana',
      username: 'lohana',
      password: '3008',
      pin: '3008',
      stage: WorkStage.firmware,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Silvania',
      username: 'silvania',
      password: '3009',
      pin: '3009',
      stage: WorkStage.testing,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Diego',
      username: 'diego',
      password: '3010',
      pin: '3010',
      stage: WorkStage.firmware,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Ilza',
      username: 'ilza',
      password: '3011',
      pin: '3011',
      stage: WorkStage.closing,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Gisele',
      username: 'gisele',
      password: '3012',
      pin: '3012',
      stage: WorkStage.expedition,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Bruna',
      username: 'bruna',
      password: '3013',
      pin: '3013',
      stage: WorkStage.firmware,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Tamara',
      username: 'tamara',
      password: '3014',
      pin: '3014',
      stage: WorkStage.testing,
      area: WorkArea.production,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Paula',
      username: 'paula',
      password: '4001',
      pin: '4001',
      stage: WorkStage.smd,
      role: 'SMD',
      area: WorkArea.smd,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Leandro',
      username: 'leandro',
      password: '4002',
      pin: '4002',
      stage: WorkStage.smd,
      role: 'SMD',
      area: WorkArea.smd,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Vera',
      username: 'vera',
      password: '4003',
      pin: '4003',
      stage: WorkStage.warehouse,
      role: 'Almoxarifado',
      area: WorkArea.warehouse,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Luis',
      username: 'luis',
      password: '4004',
      pin: '4004',
      stage: WorkStage.warehouse,
      role: 'Almoxarifado',
      area: WorkArea.warehouse,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Rose',
      username: 'rose',
      password: '4005',
      pin: '4005',
      stage: WorkStage.warehouse,
      role: 'Almoxarifado',
      area: WorkArea.warehouse,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Bruno',
      username: 'bruno',
      password: '5001',
      pin: '5001',
      stage: WorkStage.support,
      role: 'Suporte',
      area: WorkArea.support,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Douglas',
      username: 'douglas',
      password: '5002',
      pin: '5002',
      stage: WorkStage.support,
      role: 'Suporte',
      area: WorkArea.support,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'David',
      username: 'david',
      password: '5003',
      pin: '5003',
      stage: WorkStage.support,
      role: 'Suporte',
      area: WorkArea.support,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Vinicius',
      username: 'vinicius',
      password: '5004',
      pin: '5004',
      stage: WorkStage.support,
      role: 'Suporte',
      area: WorkArea.support,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Matheus',
      username: 'matheus',
      password: '5005',
      pin: '5005',
      stage: WorkStage.support,
      role: 'Suporte',
      area: WorkArea.support,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Gabriel',
      username: 'gabriel',
      password: '5006',
      pin: '5006',
      stage: WorkStage.support,
      role: 'Suporte',
      area: WorkArea.support,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Guilherme',
      username: 'guilherme',
      password: '5007',
      pin: '5007',
      stage: WorkStage.support,
      role: 'Suporte',
      area: WorkArea.support,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'Pedro',
      username: 'pedro',
      password: '5008',
      pin: '5008',
      stage: WorkStage.support,
      role: 'Suporte',
      area: WorkArea.support,
      usesAssignedStage: true,
    ),
    Operator(
      name: 'VettiFlow TV',
      username: 'tv',
      password: '2026',
      pin: '2026',
      stage: WorkStage.tv,
      role: 'Painel de TV',
      area: WorkArea.system,
    ),
    Operator(
      name: 'Admin Master',
      username: 'admin',
      password: '9999',
      pin: '9999',
      stage: WorkStage.dashboard,
      role: 'Admin master',
      canManageAssignments: true,
      area: WorkArea.system,
    ),
  ];

  /// Busca por username + password. Retorna null se nao encontrar.
  static Operator? authenticate(String username, String password) {
    final u = username.trim().toLowerCase();
    final p = password.trim();
    for (final op in all) {
      if (op.username == u && op.password == p) return op;
    }
    return null;
  }

  /// Busca operador pelo PIN (4 digitos).
  static Operator? findByPin(String pin) {
    for (final op in all) {
      if (op.pin == pin) return op;
    }
    return null;
  }
}
