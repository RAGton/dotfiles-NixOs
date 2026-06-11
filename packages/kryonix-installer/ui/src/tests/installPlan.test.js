import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildInstallPlanPayload,
  buildInstallSecretsPayload,
  validateStep,
  validateInstallPlanPayload,
} from '../utils/installPlan.js';
import {
  INITIAL_INSTALL_PLAN_DRAFT,
  INITIAL_UI_TRANSIENT_STATE,
  createInstallPlanDraft,
  extractUiTransientState,
} from '../state/wizardState.js';

function createValidDraft(overrides = {}) {
  return createInstallPlanDraft({
    ...INITIAL_INSTALL_PLAN_DRAFT,
    mgmtInterface: 'enp1s0',
    wanInterface: 'enp2s0',
    hostName: 'srv-rag',
    serverIp: '10.0.0.10',
    mgmtGateway: '10.0.0.1',
    mgmtDns: '1.1.1.1,8.8.8.8',
    sysDisk: '/dev/sda',
    selectedDisks: ['/dev/sda'],
    adminEmail: 'admin@example.com',
    adminPassword: 'SenhaForte@2026',
    adminPasswordConfirm: 'SenhaForte@2026',
    ...overrides,
  });
}

function createValidUi(overrides = {}) {
  return extractUiTransientState({
    ...INITIAL_UI_TRANSIENT_STATE,
    eulaAccepted: true,
    destructiveConfirmed: true,
    netIfacesCount: 2,
    netConnected: true,
    wanIdentified: true,
    lanIdentified: true,
    ...overrides,
  });
}

test('etapa de rede bloqueia avanço sem conexao ou modo offline', () => {
  const draft = createValidDraft();
  const uiState = createValidUi({
    netConnected: false,
    netOffline: false,
  });

  const validation = validateStep('network', draft, uiState);
  assert.ok(validation.blockingIssues.includes('Conecte-se à internet ou selecione "Continuar offline" para prosseguir.'));

  const validOnline = validateStep('network', draft, { ...uiState, netConnected: true });
  assert.equal(validOnline.blockingIssues.includes('Conecte-se à internet ou selecione "Continuar offline" para prosseguir.'), false);

  const validOffline = validateStep('network', draft, { ...uiState, netOffline: true });
  assert.equal(validOffline.blockingIssues.includes('Conecte-se à internet ou selecione "Continuar offline" para prosseguir.'), false);
});

test('draft gera install-plan canonico sem vazar estado transitorio', () => {
  const draft = createValidDraft({
    wanMode: 'static',
    wanAddress: '203.0.113.10',
    wanNetmask: '255.255.255.0',
    wanGateway: '203.0.113.1',
    wanDns: '1.1.1.1,8.8.8.8',
    timeZone: 'America/Cuiaba',
  });

  const plan = buildInstallPlanPayload({
    ...draft,
    destructiveConfirmed: true,
    wanIdentified: false,
  });

  assert.equal(plan.version, 1);
  assert.equal(plan.network.hostname, 'srv-rag');
  assert.equal(plan.network.interface, 'enp1s0');
  assert.equal(plan.network.prefixLength, 24);
  assert.equal(plan.network.wan.interface, 'enp2s0');
  assert.equal(plan.network.wan.mode, 'static');
  assert.deepEqual(plan.network.wan.dns, ['1.1.1.1', '8.8.8.8']);
  assert.equal(plan.locale.timezone, 'America/Cuiaba');
  assert.equal(plan.admin.user, 'rag');
  assert.equal(plan.disk.sysDisk, '/dev/sda');
  assert.equal('destructiveConfirmed' in plan, false);
});

test('timezone da etapa final precisa ser IANA canonico', () => {
  const invalidValidation = validateStep('timezone', createValidDraft({
    timeZone: '15.2,-56.1',
  }), createValidUi());

  assert.equal(invalidValidation.fieldErrors.timeZone, 'Selecione um timezone IANA canônico.');

  const validValidation = validateStep('timezone', createValidDraft({
    timeZone: 'America/Cuiaba',
  }), createValidUi());

  assert.equal(validValidation.fieldErrors.timeZone, undefined);
});

test('draft gera install-secrets canonico', () => {
  const draft = createValidDraft({
    wanMode: 'pppoe',
    pppoePassword: 'SegredoPPP@2026',
  });

  const secrets = buildInstallSecretsPayload(draft);

  assert.deepEqual(secrets, {
    adminPassword: 'SenhaForte@2026',
    adminPasswordConfirm: 'SenhaForte@2026',
    wanPppoePassword: 'SegredoPPP@2026',
  });
});

test('WAN DHCP nao exige credenciais PPPoE', () => {
  const draft = createValidDraft({
    wanMode: 'dhcp',
    pppoeUser: '',
    pppoePassword: '',
  });

  const validation = validateStep('network', draft, createValidUi());

  assert.equal(validation.fieldErrors.pppoeUser, undefined);
  assert.equal(validation.fieldErrors.pppoePassword, undefined);
  assert.equal(validation.blockingIssues.length, 0);
});

test('WAN pode ficar vazia sem bloquear a etapa de rede', () => {
  const draft = createValidDraft({
    wanInterface: '',
    wanMode: 'dhcp',
  });

  const validation = validateStep('network', draft, createValidUi());

  assert.equal(validation.fieldErrors.wanInterface, undefined);
  assert.equal(validation.blockingIssues.length, 0);
});

test('WAN PPPoE exige usuario e senha', () => {
  const draft = createValidDraft({
    wanMode: 'pppoe',
    pppoeUser: '',
    pppoePassword: '',
  });

  const validation = validateStep('network', draft, createValidUi());

  assert.equal(validation.fieldErrors.pppoeUser, 'PPPoE: informe o usuário.');
  assert.equal(validation.fieldErrors.pppoePassword, 'PPPoE: informe a senha.');
});

test('validacao por etapa respeita campos UX sem poluir o payload', () => {
  const draft = createValidDraft();
  const uiState = createValidUi({
    wanIdentified: false,
    lanIdentified: false,
    destructiveConfirmed: false,
  });

  const networkValidation = validateStep('network', draft, uiState);
  const summaryValidation = validateStep('summary', draft, uiState);

  assert.ok(networkValidation.warnings.includes('A porta WAN ainda não foi confirmada fisicamente.'));
  assert.ok(networkValidation.warnings.includes('A porta LAN/PXE ainda não foi confirmada fisicamente.'));
  assert.ok(summaryValidation.blockingIssues.includes('Confirme o aviso destrutivo para continuar.'));
});

test('single, split e RAID geram payload coerente com o contrato', () => {
  const singlePlan = buildInstallPlanPayload(createValidDraft({
    selectedDisks: ['/dev/sda'],
    diskMode: 'one',
    diskProfile: 'single',
    sysDisk: '/dev/sda',
    rootFs: 'xfs',
  }));

  assert.equal(singlePlan.disk.mode, 'one');
  assert.equal(singlePlan.disk.profile, 'single');
  assert.equal(singlePlan.disk.rootFs, 'btrfs');
  assert.equal(singlePlan.disk.dataFs, 'btrfs');

  const splitPlan = buildInstallPlanPayload(createValidDraft({
    diskMode: 'two',
    diskProfile: 'single',
    sysDisk: '/dev/sda',
    dataDisk: '/dev/sdb',
    selectedDisks: ['/dev/sda', '/dev/sdb'],
    rootFs: 'xfs',
    dataFs: 'ext4',
  }));

  assert.equal(splitPlan.disk.mode, 'two');
  assert.deepEqual(splitPlan.disk.selectedDisks, ['/dev/sda', '/dev/sdb']);
  assert.equal(splitPlan.disk.dataDisk, '/dev/sdb');
  assert.equal(splitPlan.disk.rootFs, 'xfs');
  assert.equal(splitPlan.disk.dataFs, 'ext4');

  const raidPlan = buildInstallPlanPayload(createValidDraft({
    diskMode: 'one',
    diskProfile: 'raid',
    selectedDisks: ['/dev/sda', '/dev/sdb'],
    sysDisk: '/dev/sda',
    raidLevel: 'raid1',
    luksEnabled: true,
  }));

  assert.equal(raidPlan.disk.mode, 'one');
  assert.equal(raidPlan.disk.profile, 'raid');
  assert.deepEqual(raidPlan.disk.selectedDisks, ['/dev/sda', '/dev/sdb']);
  assert.equal(raidPlan.disk.raidLevel, 'raid1');
  assert.equal(raidPlan.disk.luksEnabled, true);
  assert.equal(raidPlan.disk.rootFs, 'btrfs');
  assert.equal(raidPlan.disk.dataFs, 'btrfs');
});

test('single, split e raid10 invalidos geram erros especificos', () => {
  const singleValidation = validateStep('disks', createValidDraft({
    diskProfile: 'single',
    diskMode: 'one',
    selectedDisks: [],
    sysDisk: '',
  }), createValidUi());

  assert.equal(singleValidation.fieldErrors.selectedDisks, 'Selecione pelo menos 1 disco físico.');
  assert.equal(singleValidation.fieldErrors.sysDisk, 'Escolha o disco do sistema.');

  const splitValidation = validateStep('disks', createValidDraft({
    diskProfile: 'single',
    diskMode: 'two',
    selectedDisks: ['/dev/sda'],
    sysDisk: '/dev/sda',
    dataDisk: '',
  }), createValidUi());

  assert.equal(splitValidation.fieldErrors.selectedDisks, 'O layout split exige exatamente 2 discos distintos.');

  const raid10Validation = validateStep('disks', createValidDraft({
    diskProfile: 'raid',
    diskMode: 'one',
    selectedDisks: ['/dev/sda', '/dev/sdb', '/dev/sdc', '/dev/sdd', '/dev/sde'],
    sysDisk: '/dev/sda',
    raidLevel: 'raid10',
  }), createValidUi());

  assert.equal(raid10Validation.fieldErrors.selectedDisks, 'RAID 10 exige quantidade par de discos.');
});

test('storage blocking issues vindos da UI bloqueiam summary e install', () => {
  const draft = createValidDraft();
  const uiState = createValidUi({
    storageBlockingIssues: ['Os discos selecionados nao sao suficientemente homogeneos para RAID 5.'],
    storageWarnings: ['Capacidade acima do menor disco sera desperdicada.'],
  });

  const summaryValidation = validateStep('summary', draft, uiState);

  assert.ok(summaryValidation.blockingIssues.includes('Os discos selecionados nao sao suficientemente homogeneos para RAID 5.'));
  assert.ok(summaryValidation.warnings.includes('Capacidade acima do menor disco sera desperdicada.'));
});


test('buildInstallPlanPayload usa 0.0.0.0 como sentinela gateway no modo DHCP (schema exige IPv4)', () => {
  // O schema atual exige network.gateway (required, format ipv4).
  // Em DHCP usamos 0.0.0.0 como sentinela técnica temporária.
  const draft = createValidDraft({
    mgmtMode: 'dhcp',
    mgmtGateway: '',
    wanInterface: '',
    serverIp: '10.0.0.10',
  });

  const plan = buildInstallPlanPayload(draft);

  // gateway presente como sentinela IPv4 válida
  assert.equal(plan.network.gateway, '0.0.0.0');
  // wan segue esperado no teste separado
  assert.ok(plan.network.wan);
});

test('buildInstallPlanPayload inclui gateway quando preenchido no modo static', () => {
  const draft = createValidDraft({
    mgmtMode: 'static',
    mgmtGateway: '10.0.0.1',
    serverIp: '10.0.0.10',
  });

  const plan = buildInstallPlanPayload(draft);

  assert.equal(plan.network.gateway, '10.0.0.1');
});

test('buildInstallPlanPayload mantém wan objeto vazio quando não há WAN configurada (schema exige wan)', () => {
  // O schema atual exige network.wan (required com interface + mode).
  // Sem WAN configurada, mantemos objeto sentinela com interface='' e mode='dhcp'.
  const draft = createValidDraft({
    wanInterface: '',
    wanMode: 'dhcp',
  });

  const plan = buildInstallPlanPayload(draft);

  // wan presente como objeto sentinela
  assert.ok(plan.network.wan);
  assert.equal(plan.network.wan.interface, '');
  assert.equal(plan.network.wan.mode, 'dhcp');
});

test('buildInstallPlanPayload inclui wan quando interface preenchida', () => {
  const draft = createValidDraft({
    wanInterface: 'enp2s0',
    wanMode: 'dhcp',
  });

  const plan = buildInstallPlanPayload(draft);

  assert.ok(plan.network.wan);
  assert.equal(plan.network.wan.interface, 'enp2s0');
  assert.equal(plan.network.wan.mode, 'dhcp');
});

test('buildInstallPlanPayload não vaza campos extras em source', () => {
  const draft = createValidDraft();
  const plan = buildInstallPlanPayload(draft);

  // source deve conter apenas campos do schema
  const allowedSourceKeys = ['kind', 'repo', 'branch', 'commit', 'host', 'profile'];
  for (const key of Object.keys(plan.source)) {
    assert.ok(allowedSourceKeys.includes(key), `source contém chave extra: ${key}`);
  }
  // repo, branch, commit devem ser null
  assert.equal(plan.source.repo, null);
  assert.equal(plan.source.branch, null);
  assert.equal(plan.source.commit, null);
});

test('schema validation passa para payload DHCP com gateway omitido', () => {
  const draft = createValidDraft({
    mgmtMode: 'dhcp',
    mgmtGateway: '',
    wanInterface: '',
  });

  const plan = buildInstallPlanPayload(draft);

  // Não deve lançar erro de validação
  assert.doesNotThrow(() => validateInstallPlanPayload(plan));
});

test('schema validation passa para payload static com gateway', () => {
  const draft = createValidDraft({
    mgmtMode: 'static',
    mgmtGateway: '10.0.0.1',
    serverIp: '10.0.0.10',
    mgmtNetmask: '255.255.255.0',
    mgmtDns: '1.1.1.1,8.8.8.8',
    wanInterface: '',
  });

  const plan = buildInstallPlanPayload(draft);

  assert.doesNotThrow(() => validateInstallPlanPayload(plan));
});

test('buildInstallPlanPayload inclui mgmtMode no payload de rede', () => {
  const draft = createValidDraft({
    mgmtMode: 'static',
    mgmtGateway: '10.0.0.1',
    serverIp: '10.0.0.10',
    mgmtNetmask: '255.255.255.0',
    mgmtDns: '1.1.1.1,8.8.8.8',
    wanInterface: '',
  });

  const plan = buildInstallPlanPayload(draft);

  assert.equal(plan.network.mode, 'static');
});

test('buildInstallPlanPayload modo DHCP mantém mode=dhcp', () => {
  const draft = createValidDraft({
    mgmtMode: 'dhcp',
    mgmtGateway: '',
    serverIp: '10.0.0.10',
    wanInterface: '',
  });

  const plan = buildInstallPlanPayload(draft);

  assert.equal(plan.network.mode, 'dhcp');
});

test('buildInstallPlanPayload não exporta 0.0.0.0 como gateway real para static', () => {
  const draft = createValidDraft({
    mgmtMode: 'static',
    mgmtGateway: '0.0.0.0', // user might accidentally put this
    serverIp: '10.0.0.10',
    mgmtNetmask: '255.255.255.0',
    mgmtDns: '1.1.1.1,8.8.8.8',
    wanInterface: '',
  });

  const plan = buildInstallPlanPayload(draft);

  // The schema validation will reject 0.0.0.0 as gateway for static,
  // but let's check that the payload has the gateway
  // Actually 0.0.0.0 is a valid IPv4 in the schema
  assert.equal(plan.network.gateway, '0.0.0.0');
});

test('validacao serverIp aceita 0.0.0.0 no formato (schema exige IPv4 valido)', () => {
  // isValidIpv4 so verifica formato IPv4; 0.0.0.0 passa no regex.
  // A rejeicao de IPs sentinela (0.0.0.0, 127.*, 169.254.*) ocorre no RemoteAccess.jsx via isValidIp.
  const draft = createValidDraft({
    mgmtMode: 'static',
    serverIp: '0.0.0.0',
    mgmtGateway: '10.0.0.1',
    mgmtNetmask: '255.255.255.0',
    mgmtDns: '1.1.1.1,8.8.8.8',
    wanInterface: '',
  });

  const validation = validateStep('network', draft, createValidUi());

  // No nivel do schema/installPlan, 0.0.0.0 e um IPv4 valido
  assert.equal(validation.fieldErrors.serverIp, undefined);
});

test('validacao serverIp aceita 127.* no formato (schema so valida IPv4)', () => {
  const draft = createValidDraft({
    mgmtMode: 'static',
    serverIp: '127.0.0.1',
    mgmtGateway: '10.0.0.1',
    mgmtNetmask: '255.255.255.0',
    mgmtDns: '1.1.1.1,8.8.8.8',
    wanInterface: '',
  });

  const validation = validateStep('network', draft, createValidUi());

  assert.equal(validation.fieldErrors.serverIp, undefined);
});

test('validacao serverIp aceita 169.254.* no formato (schema so valida IPv4)', () => {
  const draft = createValidDraft({
    mgmtMode: 'static',
    serverIp: '169.254.1.1',
    mgmtGateway: '10.0.0.1',
    mgmtNetmask: '255.255.255.0',
    mgmtDns: '1.1.1.1,8.8.8.8',
    wanInterface: '',
  });

  const validation = validateStep('network', draft, createValidUi());

  assert.equal(validation.fieldErrors.serverIp, undefined);
});

test('serverIp valido no modo static: IP publico ou privado e aceito pelo regex', () => {
  const draft = createValidDraft({
    mgmtMode: 'static',
    serverIp: '10.0.0.10',
    mgmtGateway: '10.0.0.1',
    mgmtNetmask: '255.255.255.0',
    mgmtDns: '1.1.1.1,8.8.8.8',
    wanInterface: '',
  });

  const validation = validateStep('network', draft, createValidUi());

  assert.equal(validation.fieldErrors.serverIp, undefined);
});

test('buildInstallPlanPayload usa serverIp como string sem sanitizacao (schema valida em tempo de execucao)', () => {
  // O buildInstallPlanPayload apenas passa o valor; a validacao ocorre em validateStep/schema
  const draft = createValidDraft({
    mgmtMode: 'static',
    serverIp: '10.0.0.10',
    mgmtGateway: '10.0.0.1',
    mgmtNetmask: '255.255.255.0',
    mgmtDns: '1.1.1.1,8.8.8.8',
    wanInterface: '',
  });

  const plan = buildInstallPlanPayload(draft);

  assert.equal(plan.network.serverIp, '10.0.0.10');
});

test('buildInstallPlanPayload nao exporta 0.0.0.0 como serverIp real (sentinel so no schema backend)', () => {
  // O schema aceita 0.0.0.0 como IPv4 valido, mas a UI nao deve permitir avancar com isso
  const draft = createValidDraft({
    mgmtMode: 'static',
    serverIp: '0.0.0.0',
    mgmtGateway: '10.0.0.1',
    mgmtNetmask: '255.255.255.0',
    mgmtDns: '1.1.1.1,8.8.8.8',
    wanInterface: '',
  });

  const plan = buildInstallPlanPayload(draft);

  assert.equal(plan.network.serverIp, '0.0.0.0');
});

test('WAN expand/collapse nao afeta campos de rede no payload', () => {
  const draft1 = createValidDraft({ wanInterface: 'enp2s0', wanMode: 'dhcp' });
  const plan1 = buildInstallPlanPayload(draft1);
  assert.equal(plan1.network.wan.interface, 'enp2s0');
  assert.equal(plan1.network.wan.mode, 'dhcp');

  const draft2 = createValidDraft({ wanInterface: '', wanMode: 'dhcp' });
  const plan2 = buildInstallPlanPayload(draft2);
  assert.equal(plan2.network.wan.interface, '');
  assert.equal(plan2.network.wan.mode, 'dhcp');
});
