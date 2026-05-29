export const INSTALL_EXECUTION_PHASES = {
  IDLE: 'idle',
  VALIDATING: 'validating',
  RUNNING: 'running',
  FAILED: 'failed',
  COMPLETED: 'completed',
};

export const INSTALL_RUNTIME_PHASES = ['PRECHECK', 'INPUT', 'DISK', 'PARTITION', 'FS', 'MOUNT', 'CONFIG', 'INSTALL', 'VERIFY'];

export const INSTALL_RUNTIME_PHASE_LABELS = {
  PRECHECK: 'Precheck',
  INPUT: 'Entrada e contrato',
  DISK: 'Selecao do alvo',
  PARTITION: 'Particionamento',
  FS: 'Formatacao',
  MOUNT: 'Montagem',
  CONFIG: 'Geracao de configuracao',
  INSTALL: 'nixos-install',
  VERIFY: 'Verificacao final',
  ERROR: 'Falha',
};

export const INSTALL_LOG_BANNER = 'Kryonix Installer Console\n\n';

export function createInstallLog(message = 'Aguardando inicio da esteira de instalacao...\n') {
  return `${INSTALL_LOG_BANNER}${message}`;
}

export function formatRuntimePhaseLabel(phase) {
  return INSTALL_RUNTIME_PHASE_LABELS[phase] || phase || 'Aguardando';
}

export function normalizeInstallStatus(status = {}) {
  const exitCode = status.exitCode ?? status.lastExit ?? status.lastInstallExit ?? null;
  const running = Boolean(status.running ?? status.installRunning);

  return {
    havePlan: Boolean(status.havePlan),
    canInstall: Boolean(status.canInstall),
    running,
    exitCode: exitCode === null || exitCode === undefined ? null : Number(exitCode),
    startedAt: status.startedAt ?? status.installStartedAtUnix ?? null,
    finishedAt: status.finishedAt ?? null,
    currentPhase: status.currentPhase || null,
    lastError: status.lastError || '',
    lastLogLine: status.lastLogLine || '',
  };
}

export function getInstallExecutionPhase(status, { validating = false } = {}) {
  const normalized = normalizeInstallStatus(status);

  if (validating) {
    return INSTALL_EXECUTION_PHASES.VALIDATING;
  }
  if (normalized.running) {
    return INSTALL_EXECUTION_PHASES.RUNNING;
  }
  if (normalized.exitCode === 0) {
    return INSTALL_EXECUTION_PHASES.COMPLETED;
  }
  if (normalized.exitCode !== null) {
    return INSTALL_EXECUTION_PHASES.FAILED;
  }
  return INSTALL_EXECUTION_PHASES.IDLE;
}

export function appendInstallLog(previousLog, chunk) {
  if (!chunk) {
    return previousLog || createInstallLog();
  }

  const base = previousLog || createInstallLog();
  return `${base}${chunk}`;
}

export function buildInstallStageList(status = {}) {
  const normalized = normalizeInstallStatus(status);
  const currentIndex = INSTALL_RUNTIME_PHASES.indexOf(normalized.currentPhase);
  const failed = normalized.exitCode !== null && normalized.exitCode !== 0;
  const completed = normalized.exitCode === 0;

  return INSTALL_RUNTIME_PHASES.map((phase, index) => {
    let state = 'pending';
    if (completed || (currentIndex > index)) {
      state = 'done';
    } else if (normalized.running && currentIndex === index) {
      state = 'active';
    } else if (failed && currentIndex === index) {
      state = 'failed';
    }

    if (failed && phase === 'VERIFY' && currentIndex === -1) {
      state = 'failed';
    }

    return {
      id: phase,
      label: formatRuntimePhaseLabel(phase),
      state,
    };
  });
}

export function createInitialExecutionState() {
  const status = normalizeInstallStatus({});
  return {
    phase: INSTALL_EXECUTION_PHASES.IDLE,
    status,
    logTail: createInstallLog(),
    streamConnected: false,
    globalError: '',
    planSubmitted: false,
  };
}

export function hydrateExecutionState(statusPayload, logTail) {
  const status = normalizeInstallStatus(statusPayload);
  return {
    phase: getInstallExecutionPhase(status),
    status,
    logTail: logTail ? createInstallLog(logTail) : createInstallLog(),
    streamConnected: status.running,
    globalError: '',
    planSubmitted: status.havePlan,
  };
}

export function applyExecutionStatus(state, statusPayload, { streamConnected } = {}) {
  const status = normalizeInstallStatus(statusPayload);
  return {
    ...state,
    phase: getInstallExecutionPhase(status),
    status,
    streamConnected: streamConnected ?? state.streamConnected,
    planSubmitted: state.planSubmitted || status.havePlan,
  };
}
