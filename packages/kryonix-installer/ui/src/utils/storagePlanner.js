const KiB = 1024;
const MiB = KiB * 1024;
const GiB = MiB * 1024;
const TiB = GiB * 1024;

export const RAID_HOMOGENEITY_TOLERANCE_PERCENT = 5;
export const RAID_LEVEL_SPECS = [
  {
    id: 'raid0',
    label: 'RAID 0',
    shortLabel: 'Striping',
    minDisks: 2,
    requiresEvenDisks: false,
    requiresHomogeneousDisks: false,
    description: 'Striping puro. Maximo desempenho, sem redundancia.',
  },
  {
    id: 'raid1',
    label: 'RAID 1',
    shortLabel: 'Espelhamento',
    minDisks: 2,
    requiresEvenDisks: false,
    requiresHomogeneousDisks: true,
    description: 'Espelhamento com prioridade para redundancia.',
  },
  {
    id: 'raid5',
    label: 'RAID 5',
    shortLabel: 'Paridade simples',
    minDisks: 3,
    requiresEvenDisks: false,
    requiresHomogeneousDisks: true,
    description: 'Paridade distribuida. Tolera falha de um membro.',
  },
  {
    id: 'raid10',
    label: 'RAID 10',
    shortLabel: 'Espelhos em striping',
    minDisks: 4,
    requiresEvenDisks: true,
    requiresHomogeneousDisks: true,
    description: 'Pares espelhados com striping entre espelhos.',
  },
];

const INVALID_DEVICE_PATTERNS = [
  /^\/dev\/loop/i,
  /^\/dev\/zram/i,
  /^\/dev\/ram/i,
  /^\/dev\/sr/i,
  /^\/dev\/fd/i,
  /^\/dev\/md/i,
  /^\/dev\/dm-/i,
  /^\/dev\/mapper\//i,
  /^\/dev\/nbd/i,
];

function sanitizeString(value) {
  return String(value || '').trim();
}

function parseBool(value) {
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'number') {
    return value !== 0;
  }
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    return normalized === '1' || normalized === 'true' || normalized === 'yes';
  }
  return false;
}

function parseBytes(value) {
  if (typeof value === 'number') {
    return Number.isFinite(value) ? Math.max(value, 0) : 0;
  }
  if (typeof value === 'string') {
    const parsed = Number(value.trim());
    return Number.isFinite(parsed) ? Math.max(parsed, 0) : 0;
  }
  return 0;
}

function basename(path) {
  const normalized = sanitizeString(path);
  return normalized.split('/').pop() || normalized;
}

function uniqueByPath(disks) {
  const seen = new Set();
  const output = [];

  for (const disk of disks) {
    const path = sanitizeString(disk.path);
    if (!path || seen.has(path)) {
      continue;
    }
    seen.add(path);
    output.push(disk);
  }

  return output;
}

function compareDiskPath(a, b) {
  return a.path.localeCompare(b.path, undefined, { numeric: true, sensitivity: 'base' });
}

export function formatBytes(bytes) {
  const value = Number(bytes || 0);
  if (!Number.isFinite(value) || value <= 0) {
    return '0 B';
  }

  const units = [
    ['TiB', TiB],
    ['GiB', GiB],
    ['MiB', MiB],
    ['KiB', KiB],
  ];

  for (const [unit, size] of units) {
    if (value >= size) {
      const amount = value / size;
      const digits = amount >= 100 ? 0 : amount >= 10 ? 1 : 2;
      return `${amount.toFixed(digits)} ${unit}`;
    }
  }

  return `${value.toFixed(0)} B`;
}

export function normalizeDiskRecord(input, index = 0) {
  if (typeof input === 'string') {
    const path = sanitizeString(input);
    return {
      id: path || `disk-${index}`,
      path,
      name: basename(path),
      model: '',
      serial: '',
      transport: '',
      type: 'disk',
      sizeBytes: 0,
      readOnly: false,
      removable: false,
      hotplug: false,
    };
  }

  const path = sanitizeString(input?.path || input?.name || input?.device);
  return {
    id: sanitizeString(input?.id) || path || `disk-${index}`,
    path,
    name: sanitizeString(input?.name) || basename(path),
    model: sanitizeString(input?.model),
    serial: sanitizeString(input?.serial),
    transport: sanitizeString(input?.transport || input?.tran),
    type: sanitizeString(input?.type || input?.diskType || 'disk'),
    sizeBytes: parseBytes(input?.sizeBytes ?? input?.size),
    readOnly: parseBool(input?.readOnly ?? input?.readonly ?? input?.ro),
    removable: parseBool(input?.removable ?? input?.rm),
    hotplug: parseBool(input?.hotplug),
  };
}

export function isDiskEligible(input) {
  const disk = normalizeDiskRecord(input);
  const reasons = [];

  if (!disk.path.startsWith('/dev/')) {
    reasons.push('Dispositivo invalido: caminho fora de /dev.');
  }

  if (disk.type && disk.type !== 'disk') {
    reasons.push(`Tipo ${disk.type} nao e elegivel para instalacao.`);
  }

  if (INVALID_DEVICE_PATTERNS.some((pattern) => pattern.test(disk.path))) {
    reasons.push('Loop devices, CD-ROMs, zram e ramdisks nao sao elegiveis.');
  }

  if (disk.removable || disk.hotplug || disk.transport === 'usb') {
    reasons.push('Discos removiveis/USB nao sao aceitos pelo instalador.');
  }

  if (disk.readOnly) {
    reasons.push('O disco esta readonly.');
  }

  if (disk.sizeBytes <= 0) {
    reasons.push('Nao foi possivel determinar o tamanho util do disco.');
  }

  return {
    eligible: reasons.length === 0,
    reasons,
  };
}

export function decorateDiskRecord(input, index = 0) {
  const disk = normalizeDiskRecord(input, index);
  const local = isDiskEligible(disk);

  // Backend é a fonte de verdade: se o payload trouxer eligible/eligibilityIssues
  // (camelCase ou snake_case), usa do backend; senão calcula localmente (fallback).
  const backendIssues = input?.eligibilityIssues ?? input?.eligibility_issues;
  const hasBackendEligibility =
    typeof input?.eligible === 'boolean' || Array.isArray(backendIssues);
  const eligible = hasBackendEligibility
    ? (typeof input?.eligible === 'boolean' ? input.eligible : (backendIssues?.length ?? 0) === 0)
    : local.eligible;
  const eligibilityIssues = hasBackendEligibility
    ? (Array.isArray(backendIssues) ? backendIssues : [])
    : local.reasons;

  return {
    ...disk,
    eligible,
    eligibilityIssues,
    sizeLabel: formatBytes(disk.sizeBytes),
  };
}

export function normalizeDiskInventory(payloadDisks) {
  if (!Array.isArray(payloadDisks)) {
    return [];
  }

  return uniqueByPath(payloadDisks.map((entry, index) => decorateDiskRecord(entry, index))).sort(compareDiskPath);
}

export function getSelectedDiskRecords(allDisks, selectedPaths) {
  const map = new Map(normalizeDiskInventory(allDisks).map((disk) => [disk.path, disk]));
  return uniqueByPath(
    (Array.isArray(selectedPaths) ? selectedPaths : [])
      .map((path) => map.get(sanitizeString(path)))
      .filter(Boolean),
  );
}

function getInventoryMap(allDisks) {
  return new Map(normalizeDiskInventory(allDisks).map((disk) => [disk.path, disk]));
}

export function getDiskRecordByPath(allDisks, path) {
  return getInventoryMap(allDisks).get(sanitizeString(path)) || null;
}

function pushEligibilityIssue(blockingReasons, label, disk) {
  if (!disk) {
    blockingReasons.push(`${label}: disco nao encontrado no inventario atual.`);
    return;
  }

  if (!disk.eligible) {
    blockingReasons.push(`${label}: ${disk.eligibilityIssues[0]}`);
  }
}

export function validateSingleDiskLayout(allDisks, systemDiskPath) {
  const blockingReasons = [];
  const warnings = [];
  const systemPath = sanitizeString(systemDiskPath);

  if (!systemPath) {
    blockingReasons.push('Selecione o disco que recebera o sistema.');
  } else {
    pushEligibilityIssue(blockingReasons, 'Disco raiz', getDiskRecordByPath(allDisks, systemPath));
  }

  if (blockingReasons.length === 0) {
    warnings.push('Layout valido: /, /srv e /srv/data ficarao no mesmo BTRFS com subvolumes.');
  }

  return {
    valid: blockingReasons.length === 0,
    blockingReasons,
    warnings,
  };
}

export function validateSplitDiskLayout(allDisks, systemDiskPath, dataDiskPath) {
  const blockingReasons = [];
  const warnings = [];
  const systemPath = sanitizeString(systemDiskPath);
  const dataPath = sanitizeString(dataDiskPath);

  if (!systemPath) {
    blockingReasons.push('Selecione o disco que recebera /.');
  } else {
    pushEligibilityIssue(blockingReasons, 'Disco raiz', getDiskRecordByPath(allDisks, systemPath));
  }

  if (!dataPath) {
    blockingReasons.push('Selecione o disco que recebera /srv/data.');
  } else {
    pushEligibilityIssue(blockingReasons, 'Disco de dados', getDiskRecordByPath(allDisks, dataPath));
  }

  if (systemPath && dataPath && systemPath === dataPath) {
    blockingReasons.push('O mesmo disco nao pode ocupar os papeis de raiz e dados.');
  }

  if (blockingReasons.length === 0) {
    warnings.push('Layout valido: o disco de dados sera montado em /srv/data.');
  }

  return {
    valid: blockingReasons.length === 0,
    blockingReasons,
    warnings,
  };
}

export function buildSplitPlanSummary(allDisks, systemDiskPath, dataDiskPath) {
  const systemDisk = getDiskRecordByPath(allDisks, systemDiskPath);
  const dataDisk = getDiskRecordByPath(allDisks, dataDiskPath);
  const disks = [systemDisk, dataDisk].filter(Boolean);

  return {
    memberCount: disks.length,
    systemDisk: systemDisk?.path || '',
    dataDisk: dataDisk?.path || '',
    rawBytes: disks.reduce((total, disk) => total + disk.sizeBytes, 0),
    rawLabel: formatBytes(disks.reduce((total, disk) => total + disk.sizeBytes, 0)),
  };
}

export function isHomogeneousEnough(disks, tolerancePercent = RAID_HOMOGENEITY_TOLERANCE_PERCENT) {
  const sizes = disks.map((disk) => parseBytes(disk.sizeBytes)).filter((size) => size > 0);
  if (sizes.length === 0) {
    return false;
  }

  const smallest = Math.min(...sizes);
  const largest = Math.max(...sizes);
  const deviationPercent = largest > 0 ? ((largest - smallest) / largest) * 100 : 0;

  return deviationPercent <= tolerancePercent;
}

function getSizeStats(disks) {
  const sizes = disks.map((disk) => parseBytes(disk.sizeBytes)).filter((size) => size > 0);
  const rawBytes = sizes.reduce((total, size) => total + size, 0);
  const smallestDiskBytes = sizes.length > 0 ? Math.min(...sizes) : 0;
  const largestDiskBytes = sizes.length > 0 ? Math.max(...sizes) : 0;
  const mismatchWasteBytes = sizes.reduce((total, size) => total + Math.max(size - smallestDiskBytes, 0), 0);
  const homogeneityDeviationPercent = largestDiskBytes > 0
    ? ((largestDiskBytes - smallestDiskBytes) / largestDiskBytes) * 100
    : 0;

  return {
    rawBytes,
    smallestDiskBytes,
    largestDiskBytes,
    mismatchWasteBytes,
    homogeneityDeviationPercent,
  };
}

export function calculateRaidUsableCapacity(disks, raidLevel) {
  const members = uniqueByPath(disks.map((disk) => decorateDiskRecord(disk)));
  const stats = getSizeStats(members);
  const count = members.length;

  let usableBytes = 0;
  switch (raidLevel) {
    case 'raid0':
      usableBytes = count * stats.smallestDiskBytes;
      break;
    case 'raid1':
      usableBytes = stats.smallestDiskBytes;
      break;
    case 'raid5':
      usableBytes = Math.max(count - 1, 0) * stats.smallestDiskBytes;
      break;
    case 'raid10':
      usableBytes = Math.floor(count / 2) * stats.smallestDiskBytes;
      break;
    default:
      usableBytes = 0;
      break;
  }

  return {
    ...stats,
    memberCount: count,
    usableBytes,
    capacityLabel: formatBytes(usableBytes),
  };
}

export function getRaidFaultTolerance(disks, raidLevel) {
  const count = uniqueByPath(disks.map((disk) => decorateDiskRecord(disk))).length;

  switch (raidLevel) {
    case 'raid0':
      return '0 discos';
    case 'raid1':
      return count <= 2
        ? '1 disco'
        : `ate ${Math.max(count - 1, 1)} discos, desde que um membro permaneça integro`;
    case 'raid5':
      return '1 disco';
    case 'raid10':
      return '1 disco por espelho, sem perder o par inteiro';
    default:
      return 'nao definido';
  }
}

function getRaidSpec(raidLevel) {
  return RAID_LEVEL_SPECS.find((level) => level.id === raidLevel) || null;
}

function getDuplicatePaths(disks) {
  const seen = new Set();
  const duplicates = new Set();

  for (const disk of disks) {
    const path = sanitizeString(disk.path);
    if (!path) {
      continue;
    }
    if (seen.has(path)) {
      duplicates.add(path);
    }
    seen.add(path);
  }

  return Array.from(duplicates);
}

export function getRaidBlockingReasons(disks, raidLevel) {
  const members = disks.map((disk) => decorateDiskRecord(disk));
  const spec = getRaidSpec(raidLevel);
  const reasons = [];

  if (!spec) {
    return ['Nivel RAID invalido.'];
  }

  const duplicates = getDuplicatePaths(members);
  if (duplicates.length > 0) {
    reasons.push(`A selecao contem discos duplicados: ${duplicates.join(', ')}.`);
  }

  const ineligible = members.filter((disk) => !disk.eligible);
  for (const disk of ineligible) {
    reasons.push(`${disk.path}: ${disk.eligibilityIssues[0]}`);
  }

  if (members.length < spec.minDisks) {
    reasons.push(`${spec.label} exige no minimo ${spec.minDisks} discos fisicos elegiveis.`);
  }

  if (spec.requiresEvenDisks && members.length % 2 !== 0) {
    reasons.push(`${spec.label} exige quantidade par de discos.`);
  }

  if (spec.requiresHomogeneousDisks && members.length >= spec.minDisks) {
    const stats = getSizeStats(members);
    if (stats.smallestDiskBytes <= 0) {
      reasons.push('Nao foi possivel determinar o tamanho dos discos selecionados.');
    } else if (stats.homogeneityDeviationPercent > RAID_HOMOGENEITY_TOLERANCE_PERCENT) {
      reasons.push(
        `Os discos selecionados nao sao suficientemente homogeneos para ${spec.label}. ` +
        `Desvio maximo atual: ${stats.homogeneityDeviationPercent.toFixed(1)}%; tolerancia: ${RAID_HOMOGENEITY_TOLERANCE_PERCENT}%.`,
      );
    }
  }

  return reasons;
}

export function getRaidBlockingReason(disks, raidLevel) {
  return getRaidBlockingReasons(disks, raidLevel)[0] || '';
}

export function buildRaidPlanSummary(disks, raidLevel) {
  const members = uniqueByPath(disks.map((disk) => decorateDiskRecord(disk)));
  const blockingReasons = getRaidBlockingReasons(members, raidLevel);
  const capacity = calculateRaidUsableCapacity(members, raidLevel);
  const warnings = [];

  if (capacity.mismatchWasteBytes > 0) {
    warnings.push(
      `Capacidade acima do menor disco sera desperdicada: ${formatBytes(capacity.mismatchWasteBytes)}.`,
    );
  }

  if (raidLevel === 'raid0' && capacity.mismatchWasteBytes > 0) {
    warnings.push('RAID 0 aceita discos diferentes, mas a capacidade util fica limitada pelo menor disco.');
  }

  return {
    raidLevel,
    members: members.map((disk) => disk.path),
    memberCount: members.length,
    smallestDiskBytes: capacity.smallestDiskBytes,
    smallestDiskLabel: formatBytes(capacity.smallestDiskBytes),
    rawBytes: capacity.rawBytes,
    rawLabel: formatBytes(capacity.rawBytes),
    usableBytes: capacity.usableBytes,
    usableLabel: formatBytes(capacity.usableBytes),
    mismatchWasteBytes: capacity.mismatchWasteBytes,
    mismatchWasteLabel: formatBytes(capacity.mismatchWasteBytes),
    faultTolerance: getRaidFaultTolerance(members, raidLevel),
    blockingReasons,
    warnings,
  };
}

export function validateRaidSelection(disks, raidLevel) {
  const summary = buildRaidPlanSummary(disks, raidLevel);
  return {
    valid: summary.blockingReasons.length === 0,
    blockingReasons: summary.blockingReasons,
    warnings: summary.warnings,
    summary,
  };
}

export function getRaidOptionsForSelection(disks) {
  return RAID_LEVEL_SPECS.map((spec) => {
    const validation = validateRaidSelection(disks, spec.id);
    return {
      ...spec,
      enabled: validation.valid,
      blockingReasons: validation.blockingReasons,
      warnings: validation.warnings,
      summary: validation.summary,
      faultTolerance: validation.summary.faultTolerance,
    };
  });
}

export function validateSingleProfileSelection(disks) {
  const members = uniqueByPath(disks.map((disk) => decorateDiskRecord(disk)));
  const blockingReasons = [];
  const warnings = [];
  const ineligible = members.filter((disk) => !disk.eligible);

  for (const disk of ineligible) {
    blockingReasons.push(`${disk.path}: ${disk.eligibilityIssues[0]}`);
  }

  if (members.length === 0) {
    blockingReasons.push('Selecione pelo menos 1 disco fisico elegivel.');
  }

  if (members.length > 2) {
    blockingReasons.push('O perfil Single usa no maximo 2 discos. Reduza a selecao ou habilite RAID.');
  }

  if (members.length === 2) {
    warnings.push('No perfil Single, o primeiro disco sera usado para sistema e o segundo para dados.');
  }

  return {
    valid: blockingReasons.length === 0,
    blockingReasons,
    warnings,
  };
}

export function buildSinglePlanSummary(disks) {
  const members = uniqueByPath(disks.map((disk) => decorateDiskRecord(disk)));
  const systemDisk = members[0] || null;
  const dataDisk = members[1] || null;

  return {
    memberCount: members.length,
    systemDisk: systemDisk?.path || '',
    dataDisk: dataDisk?.path || '',
    rawBytes: members.reduce((total, disk) => total + disk.sizeBytes, 0),
    rawLabel: formatBytes(members.reduce((total, disk) => total + disk.sizeBytes, 0)),
  };
}

export function getStorageRecommendation(disks) {
  const members = uniqueByPath(disks.map((disk) => decorateDiskRecord(disk)));
  const count = members.length;

  if (count <= 1) {
    return {
      profile: 'single',
      raidLevel: null,
      title: 'Single BTRFS',
      rationale: 'Com apenas um disco elegivel, o caminho conservador e Single com BTRFS.',
    };
  }

  const preferredOrder = count >= 4 && count % 2 === 0
    ? ['raid10', 'raid5', 'raid1']
    : count >= 3
      ? ['raid5', 'raid1', 'raid10']
      : ['raid1'];

  for (const raidLevel of preferredOrder) {
    const validation = validateRaidSelection(members, raidLevel);
    if (validation.valid) {
      return {
        profile: 'raid',
        raidLevel,
        title: `Recomendado: ${getRaidSpec(raidLevel)?.label || raidLevel.toUpperCase()}`,
        rationale: validation.summary.memberCount >= 4 && raidLevel === 'raid10'
          ? 'Melhor equilibrio entre redundancia e desempenho para um conjunto homogeneo e par.'
          : raidLevel === 'raid5'
            ? 'Aproveita melhor 3+ discos homogeneos mantendo redundancia simples.'
            : 'Espelhamento conservador para priorizar disponibilidade.',
      };
    }
  }

  const raid0 = validateRaidSelection(members, 'raid0');
  if (raid0.valid) {
    return {
      profile: 'single',
      raidLevel: null,
      title: 'Recomendacao conservadora: Single',
      rationale: 'Os discos atuais nao passam nas regras conservadoras de RAID redundante. RAID 0 ate funciona, mas nao oferece tolerancia a falhas.',
      alternativeRaidLevel: 'raid0',
    };
  }

  return {
    profile: 'single',
    raidLevel: null,
    title: 'Ajuste os discos selecionados',
    rationale: 'Nenhum perfil seguro esta apto com a selecao atual. Revise elegibilidade e homogeneidade.',
  };
}
