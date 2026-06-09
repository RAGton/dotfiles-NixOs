import Ajv2020 from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';
import installPlanSchema from '../install-plan.schema.json' with { type: 'json' };
import {
  createInstallPlanDraft,
  extractUiTransientState,
} from '../state/wizardState.js';
import { FEATURE_CATALOG } from '../data/featureCatalog.js';
import { PROFILE_CATALOG } from '../data/profileCatalog.js';

export const INSTALL_PLAN_VERSION = 1;

const ajv = new Ajv2020({ allErrors: true, strict: false });
addFormats(ajv);
const validateSchema = ajv.compile(installPlanSchema);

const ipv4Pattern = /^((25[0-5]|2[0-4]\d|[01]?\d?\d)\.){3}(25[0-5]|2[0-4]\d|[01]?\d?\d)$/;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const timezonePattern = /^(?:[A-Za-z_+-]+(?:\/[A-Za-z0-9_+-]+)+|Etc\/UTC)$/;

function sanitizeString(value) {
  return String(value || '').trim();
}

function csvToArray(value) {
  return String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function parseAuthorizedKeys(value) {
  return String(value || '')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
}

function sanitizeDnsList(value) {
  return Array.from(
    new Set(
      csvToArray(value).filter((item) => ipv4Pattern.test(item)),
    ),
  );
}

function hasOnlyValidDnsItems(value) {
  const items = csvToArray(value);
  return items.length > 0 && items.every((item) => ipv4Pattern.test(item));
}

function netmaskToPrefix(netmask) {
  const normalized = sanitizeString(netmask);
  if (!normalized) {
    return null;
  }

  const parts = normalized.split('.');
  if (parts.length !== 4) {
    return null;
  }

  let bits = 0;
  let seenZero = false;

  for (const part of parts) {
    const octet = Number(part);
    if (!Number.isInteger(octet) || octet < 0 || octet > 255) {
      return null;
    }

    for (let bit = 7; bit >= 0; bit -= 1) {
      const current = (octet >> bit) & 1;
      if (current === 1) {
        if (seenZero) {
          return null;
        }
        bits += 1;
      } else {
        seenZero = true;
      }
    }
  }

  return bits;
}

function isValidIpv4(value) {
  return ipv4Pattern.test(sanitizeString(value));
}

function isValidHostname(value) {
  const host = sanitizeString(value);
  if (!host || host.length > 63) {
    return false;
  }
  return /^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/.test(host);
}

export function isStrongPassword(value) {
  const password = String(value || '');
  if (password.length < 12) {
    return false;
  }

  let classes = 0;
  if (/[a-z]/.test(password)) classes += 1;
  if (/[A-Z]/.test(password)) classes += 1;
  if (/[0-9]/.test(password)) classes += 1;
  if (/[^A-Za-z0-9\s]/.test(password)) classes += 1;
  return classes >= 3;
}

function isCanonicalTimezone(value) {
  return timezonePattern.test(sanitizeString(value));
}

function uniqueStrings(items) {
  return Array.from(new Set((Array.isArray(items) ? items : []).map((item) => sanitizeString(item)).filter(Boolean)));
}

function formatAjvErrors(errors) {
  if (!errors || errors.length === 0) {
    return 'plano inválido';
  }

  return errors
    .map((error) => {
      const path = error.instancePath || 'plano';
      const message = error.message || 'valor inválido';
      return `${path} ${message}`.trim();
    })
    .join('; ');
}

export function buildInstallPlanPayload(draftInput) {
  const draft = createInstallPlanDraft(draftInput);
  const diskProfile = sanitizeString(draft.diskProfile);
  const requestedDiskMode = sanitizeString(draft.diskMode) === 'two' ? 'two' : 'one';
  const sysDisk = sanitizeString(draft.sysDisk);
  const dataDiskCandidate = sanitizeString(draft.dataDisk);
  const raidMembers = uniqueStrings(draft.selectedDisks);
  const diskMode = (diskProfile === 'raid' || diskProfile === 'manual') ? 'one' : requestedDiskMode;

  const selectedDisks = diskProfile === 'raid'
    ? uniqueStrings([sysDisk, ...raidMembers].filter(Boolean))
    : diskProfile === 'manual'
      ? uniqueStrings([sysDisk, ...(draft.manualPartitions || []).map(p => p.device)].filter(Boolean))
      : uniqueStrings([sysDisk, ...(diskMode === 'two' ? [dataDiskCandidate] : [])].filter(Boolean));

  const dataDisk = diskProfile === 'single' && diskMode === 'two' ? dataDiskCandidate || undefined : undefined;
  const mgmtPrefix = netmaskToPrefix(draft.mgmtNetmask) ?? 0;
  const wanPrefix = netmaskToPrefix(draft.wanNetmask);
  const wanInterface = sanitizeString(draft.wanInterface);
  const wanEnabled = wanInterface !== '';
  const wanMode = wanEnabled ? sanitizeString(draft.wanMode) || 'dhcp' : 'dhcp';

  const profileObj = PROFILE_CATALOG.find(p => p.id === draft.profileId) || PROFILE_CATALOG.find(p => p.id === 'desktop-plasma');
  const selectedFeatures = Array.isArray(draft.selectedFeatures) ? draft.selectedFeatures : [];

  const features = {
    system: {},
    user: {},
    storage: {},
    security: {},
    remote: {},
    ai: {},
    server: {},
    desktop: {},
    dev: {},
    mcp: {},
    virtualization: {},
    network: {},
    observability: {},
    shell: {},
    terminal: {},
    editor: {},
    obsidian: {}
  };

  for (const featId of selectedFeatures) {
    const feat = FEATURE_CATALOG.find(f => f.id === featId);
    if (feat) {
      if (features[feat.level]) {
        features[feat.level][featId] = true;
      }
      if (features[feat.domain]) {
        features[feat.domain][featId] = true;
      }
    }
  }

  // /srv/data ativa para: features de IA que exigem volume persistente,
  // storage.srv-data explicito, e perfis ai-local/kryonix-full.
  // Profile "server" exige selecao manual de storage.srv-data (nao auto-ativa).
  const enableSrvData =
    features.system['storage.srv-data'] === true ||
    features.system['ai.ollama'] === true ||
    features.system['ai.kryonix-brain'] === true ||
    features.system['ai.neo4j'] === true ||
    features.system['ai.lightrag'] === true ||
    features.system['ai.open-webui'] === true ||
    draft.profileId === 'ai-local' ||
    draft.profileId === 'kryonix-full';

  return {
    version: INSTALL_PLAN_VERSION,
    source: {
      kind: 'offline-defaults',
      repo: null,
      branch: null,
      commit: null,
      host: sanitizeString(draft.hostName),
      profile: profileObj.id,
    },
    profile: {
      id: profileObj.id,
      name: profileObj.name,
      mode: profileObj.mode,
    },
    features,
    storage: {
      layout: (diskProfile === 'raid' || diskProfile === 'manual' || diskMode === 'one') ? 'btrfs-simple' : 'btrfs-split',
      target: selectedDisks[0] || '',
      enableSrvData,
      srvDataMode: enableSrvData ? 'btrfs-subvolume' : 'disabled',
      enableAiModels: features.system['storage.ai-models'] === true,
    },
    security: {
      allowWeakPassword: Boolean(draft.allowWeakPassword),
    },
    remoteAccess: {
      enabled: Boolean(draft.remoteAccessEnabled),
      port: 8080,
    },
    disk: {
      mode: diskMode,
      profile: (diskProfile === 'raid' || diskProfile === 'manual') ? diskProfile : 'single',
      selectedDisks,
      raidLevel: diskProfile === 'raid' ? sanitizeString(draft.raidLevel) || 'raid1' : undefined,
      luksEnabled: Boolean(draft.luksEnabled),
      sysDisk,
      dataDisk: diskMode === 'two' && diskProfile !== 'raid' && diskProfile !== 'manual' ? dataDisk : undefined,
      manualPartitions: diskProfile === 'manual' ? (draft.manualPartitions || []) : undefined,
      rootFs: (diskProfile === 'raid' || diskProfile === 'manual' || diskMode === 'one')
        ? 'btrfs'
        : sanitizeString(draft.rootFs) || 'btrfs',
      dataFs: (diskProfile === 'raid' || diskProfile === 'manual')
        ? 'btrfs'
        : diskMode === 'two'
          ? sanitizeString(draft.dataFs) || 'btrfs'
          : 'btrfs',
    },
    network: {
      hostname: sanitizeString(draft.hostName),
      interface: sanitizeString(draft.mgmtInterface),
      mode: draft.mgmtMode === 'static' ? 'static' : 'dhcp',
      serverIp: sanitizeString(draft.serverIp),
      prefixLength: mgmtPrefix,
      gateway: sanitizeString(draft.mgmtGateway),
      dns: sanitizeDnsList(draft.mgmtDns),
      httpPort: Number.isFinite(Number(draft.httpPort)) ? Number(draft.httpPort) : 0,
      wan: {
        interface: wanInterface,
        mode: wanMode,
        address: wanEnabled ? sanitizeString(draft.wanAddress) || undefined : undefined,
        prefixLength: wanEnabled ? wanPrefix ?? undefined : undefined,
        gateway: wanEnabled ? sanitizeString(draft.wanGateway) || undefined : undefined,
        dns: wanEnabled ? sanitizeDnsList(draft.wanDns) : [],
        pppoeUser: wanEnabled ? sanitizeString(draft.pppoeUser) || undefined : undefined,
      },
    },
    locale: {
      country: sanitizeString(draft.country).toUpperCase(),
      timezone: sanitizeString(draft.timeZone),
      locale: sanitizeString(draft.locale),
      keymap: sanitizeString(draft.keyMap),
    },
    admin: {
      user: sanitizeString(draft.adminUser),
      uid: Number.isFinite(Number(draft.adminUid)) ? Number(draft.adminUid) : 0,
      email: sanitizeString(draft.adminEmail),
      authorizedKeys: uniqueStrings(parseAuthorizedKeys(draft.adminAuthorizedKeys)),
    },
  };
}

export function buildInstallSecretsPayload(draftInput) {
  const draft = createInstallPlanDraft(draftInput);
  const wanMode = sanitizeString(draft.wanMode) || 'dhcp';

  return {
    adminPassword: String(draft.adminPassword || ''),
    adminPasswordConfirm: String(draft.adminPasswordConfirm || ''),
    wanPppoePassword: wanMode === 'pppoe' ? String(draft.pppoePassword || '') : undefined,
  };
}

export { extractUiTransientState };

export function validateInstallPlanPayload(payload) {
  const valid = validateSchema(payload);
  if (!valid) {
    throw new Error(formatAjvErrors(validateSchema.errors));
  }
  return payload;
}

export function getInstallPlanCompatibilityIssues(payload) {
  const issues = [];

  if (payload?.disk?.profile === 'raid' && payload?.disk?.rootFs !== 'btrfs') {
    issues.push('No modo RAID, o filesystem raiz suportado pelo backend atual é btrfs.');
  }

  return issues;
}

function createValidationResult() {
  return {
    fieldErrors: {},
    blockingIssues: [],
    warnings: [],
  };
}

function addMessage(list, message) {
  if (message && !list.includes(message)) {
    list.push(message);
  }
}

function addFieldError(result, field, message, { blocking = true } = {}) {
  if (!result.fieldErrors[field]) {
    result.fieldErrors[field] = message;
  }
  if (blocking) {
    addMessage(result.blockingIssues, message);
  } else {
    addMessage(result.warnings, message);
  }
}

function addBlockingIssue(result, message) {
  addMessage(result.blockingIssues, message);
}

function addWarning(result, message) {
  addMessage(result.warnings, message);
}

function appendStorageUiValidation(result, uiState) {
  const blockingIssues = Array.isArray(uiState?.storageBlockingIssues) ? uiState.storageBlockingIssues : [];
  const warnings = Array.isArray(uiState?.storageWarnings) ? uiState.storageWarnings : [];

  for (const issue of blockingIssues) {
    addBlockingIssue(result, issue);
  }

  for (const warning of warnings) {
    addWarning(result, warning);
  }
}

// Regra de senha unica: vazia nunca aceita; confirmacao sempre obrigatoria;
// regra de FORCA so cai sob allowWeakPassword (modo laboratorio).
function validatePasswordRules(secrets, allowWeak, result) {
  if (!secrets.adminPassword) {
    addFieldError(result, 'adminPassword', 'Informe a senha do administrador.');
  } else if (!allowWeak && !isStrongPassword(secrets.adminPassword)) {
    addFieldError(result, 'adminPassword', 'Use uma senha forte com 12+ caracteres e 3 classes de caracteres.');
  }

  if (secrets.adminPassword !== secrets.adminPasswordConfirm) {
    addFieldError(result, 'adminPasswordConfirm', 'Senha e confirmação não conferem.');
  }
}

function validateFinalDraft(draft, payload, secrets, result) {
  try {
    validateInstallPlanPayload(payload);
  } catch (error) {
    addBlockingIssue(result, error instanceof Error ? error.message : 'Plano inválido.');
  }

  for (const compatibilityIssue of getInstallPlanCompatibilityIssues(payload)) {
    addBlockingIssue(result, compatibilityIssue);
  }

  if (!isCanonicalTimezone(payload.locale.timezone)) {
    addFieldError(result, 'timeZone', 'Selecione um timezone IANA canônico.');
  }

  validatePasswordRules(secrets, Boolean(draft.allowWeakPassword), result);

  if (draft.allowWeakPassword) {
    addWarning(result, 'Senha forte ignorada por modo laboratório (allowWeakPassword).');
  }

  if (payload.admin.uid < 1000) {
    addFieldError(result, 'adminUid', 'UID do administrador deve ser 1000 ou maior.');
  }

  if (!emailPattern.test(payload.admin.email)) {
    addFieldError(result, 'adminEmail', 'Informe um e-mail válido.');
  }
}

function validateAdminStep(payload, secrets, result, draft) {
  if (!payload.admin.user) addFieldError(result, 'adminUser', 'Informe o usuário administrador.');
  if (payload.admin.uid < 1000) addFieldError(result, 'adminUid', 'UID do administrador deve ser 1000 ou maior.');
  if (!payload.admin.email) {
    addFieldError(result, 'adminEmail', 'Informe o e-mail do administrador.');
  } else if (!emailPattern.test(payload.admin.email)) {
    addFieldError(result, 'adminEmail', 'Informe um e-mail válido.');
  }

  validatePasswordRules(secrets, Boolean(draft?.allowWeakPassword), result);
}

export function validateStep(stepId, draftInput, uiInput = {}) {
  const draft = createInstallPlanDraft(draftInput);
  const uiState = extractUiTransientState(uiInput);
  const payload = buildInstallPlanPayload(draft);
  const secrets = buildInstallSecretsPayload(draft);
  const result = createValidationResult();

  switch (stepId) {
    case 'welcome':
      return result;
    case 'eula':
      if (!uiState.eulaAccepted) {
        addBlockingIssue(result, 'É necessário aceitar os termos e o aviso de destruição de dados.');
      }
      return result;
    case 'source':
      // Em P1, source é sempre offline-defaults
      return result;
    case 'localization':
      if (!payload.locale.country) addFieldError(result, 'country', 'Selecione um país/região.');
      if (!payload.locale.locale) addFieldError(result, 'locale', 'Selecione um idioma/locale.');
      if (!payload.locale.keymap) addFieldError(result, 'keyMap', 'Selecione um layout de teclado.');
      return result;
    case 'timezone':
      if (!payload.locale.timezone) {
        addFieldError(result, 'timeZone', 'Selecione um timezone válido.');
      } else if (!isCanonicalTimezone(payload.locale.timezone)) {
        addFieldError(result, 'timeZone', 'Selecione um timezone IANA canônico.');
      }
      return result;
    case 'network':
      // Requisito de avanço: estar online OU ter escolhido modo offline explicitamente.
      if (!uiState.netConnected && !uiState.netOffline) {
        addBlockingIssue(result, 'Conecte-se à internet ou selecione "Continuar offline" para prosseguir.');
      }

      if (!payload.network.interface) addFieldError(result, 'mgmtInterface', 'Selecione a interface LAN/PXE.');
      if (payload.network.interface && payload.network.wan.interface && payload.network.interface === payload.network.wan.interface) {
        addBlockingIssue(result, 'LAN/PXE e WAN devem usar placas distintas.');
      }
      if (!isValidHostname(draft.hostName)) addFieldError(result, 'hostName', 'Hostname inválido para um servidor Linux.');
      // IP/máscara/gateway/DNS só são exigidos no modo manual (estático).
      // Em DHCP esses valores vêm automaticamente da rede.
      if (payload.network.mode === 'static') {
        if (!isValidIpv4(draft.serverIp)) addFieldError(result, 'serverIp', 'IP do servidor inválido.');
        if (!isValidIpv4(draft.mgmtNetmask)) addFieldError(result, 'mgmtNetmask', 'Máscara de gerenciamento inválida.');
        if (!isValidIpv4(draft.mgmtGateway)) addFieldError(result, 'mgmtGateway', 'Gateway inválido.');
        if (!hasOnlyValidDnsItems(draft.mgmtDns)) addFieldError(result, 'mgmtDns', 'DNS deve conter IPv4 válidos separados por vírgula.');
      }
      if (!(Number(payload.network.httpPort) >= 1 && Number(payload.network.httpPort) <= 65535)) {
        addFieldError(result, 'httpPort', 'Porta HTTP deve ficar entre 1 e 65535.');
      }

      if (payload.network.wan.interface && payload.network.wan.mode === 'static') {
        if (!isValidIpv4(draft.wanAddress)) addFieldError(result, 'wanAddress', 'IP WAN inválido.');
        if (!isValidIpv4(draft.wanNetmask)) addFieldError(result, 'wanNetmask', 'Máscara WAN inválida.');
        if (!isValidIpv4(draft.wanGateway)) addFieldError(result, 'wanGateway', 'Gateway WAN inválido.');
        if (!hasOnlyValidDnsItems(draft.wanDns)) addFieldError(result, 'wanDns', 'DNS WAN deve conter IPv4 válidos separados por vírgula.');
      }

      if (payload.network.wan.interface && payload.network.wan.mode === 'pppoe') {
        if (!payload.network.wan.pppoeUser) addFieldError(result, 'pppoeUser', 'PPPoE: informe o usuário.');
        if (!secrets.wanPppoePassword) addFieldError(result, 'pppoePassword', 'PPPoE: informe a senha.');
      }

      if (payload.network.wan.interface && !uiState.wanIdentified) {
        addWarning(result, 'A porta WAN ainda não foi confirmada fisicamente.');
      }
      if (!uiState.lanIdentified) {
        addWarning(result, 'A porta LAN/PXE ainda não foi confirmada fisicamente.');
      }
      return result;
    case 'disks': {
      const selectedDisks = payload.disk.selectedDisks;
      const rawSelection = Array.isArray(draft.selectedDisks) ? draft.selectedDisks : [];
      const uniqueSelection = uniqueStrings(rawSelection);
      if (uniqueSelection.length !== rawSelection.length) addFieldError(result, 'selectedDisks', 'A selecao contem discos duplicados.');
      if (selectedDisks.length === 0) addFieldError(result, 'selectedDisks', 'Selecione pelo menos 1 disco físico.');
      if (!payload.disk.sysDisk) addFieldError(result, 'sysDisk', 'Escolha o disco do sistema.');
      if (payload.disk.sysDisk && selectedDisks.length > 0 && !selectedDisks.includes(payload.disk.sysDisk)) {
        addFieldError(result, 'sysDisk', 'O disco do sistema precisa fazer parte da selecao atual.');
      }

      if (payload.disk.profile === 'raid') {
        const minByLevel = {
          raid0: 2,
          raid1: 2,
          raid5: 3,
          raid10: 4,
        };
        const minRequired = minByLevel[payload.disk.raidLevel] || 2;
        if (selectedDisks.length < minRequired) {
          addFieldError(result, 'selectedDisks', `${String(payload.disk.raidLevel || 'RAID').toUpperCase()} exige pelo menos ${minRequired} discos físicos.`);
        }
        if (payload.disk.raidLevel === 'raid10' && selectedDisks.length % 2 !== 0) {
          addFieldError(result, 'selectedDisks', 'RAID 10 exige quantidade par de discos.');
        }
        if (payload.disk.dataDisk) {
          addFieldError(result, 'dataDisk', 'RAID não usa disk.dataDisk no contrato atual.');
        }
      } else if (payload.disk.profile === 'manual') {
        const manual = payload.disk.manualPartitions || [];
        const hasRoot = manual.some(p => p.mountpoint === '/');
        const hasEfi = manual.some(p => p.mountpoint === '/boot/efi' || p.mountpoint === '/efi');
        if (!hasRoot) addBlockingIssue(result, 'Partição raiz (/) é obrigatória no modo manual.');
        if (!hasEfi) addBlockingIssue(result, 'Partição EFI (/boot/efi ou /efi) é obrigatória.');
      } else if (payload.disk.mode === 'two') {
        if (selectedDisks.length !== 2) {
          addFieldError(result, 'selectedDisks', 'O layout split exige exatamente 2 discos distintos.');
        }
      } else if (selectedDisks.length !== 1) {
        addFieldError(result, 'selectedDisks', 'O layout single disk exige exatamente 1 disco.');
      }

      if (payload.disk.mode === 'two' && payload.disk.profile !== 'raid') {
        if (!payload.disk.dataDisk) addFieldError(result, 'dataDisk', 'Escolha o disco de dados.');
        if (payload.disk.dataDisk && payload.disk.dataDisk === payload.disk.sysDisk) {
          addFieldError(result, 'dataDisk', 'Disco de dados não pode ser igual ao disco do sistema.');
        }
      } else if (payload.disk.profile !== 'raid' && payload.disk.dataDisk) {
        addFieldError(result, 'dataDisk', 'Single disk não usa disk.dataDisk.');
      }

      appendStorageUiValidation(result, uiState);
      return result;
    }
    case 'users':
      validateAdminStep(payload, secrets, result, draft);
      return result;
    case 'summary':
      validateFinalDraft(draft, payload, secrets, result);
      appendStorageUiValidation(result, uiState);
      if (!uiState.destructiveConfirmed) {
        addBlockingIssue(result, 'Confirme o aviso destrutivo para continuar.');
      }
      return result;
    case 'install':
      validateFinalDraft(draft, payload, secrets, result);
      appendStorageUiValidation(result, uiState);
      if (!uiState.destructiveConfirmed) {
        addBlockingIssue(result, 'Confirme o wipe de discos antes de iniciar.');
      }
      return result;
    default:
      return result;
  }
}
