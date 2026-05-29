import test from 'node:test';
import assert from 'node:assert/strict';
import {
  appendInstallLog,
  applyExecutionStatus,
  buildInstallStageList,
  createInitialExecutionState,
  createInstallLog,
  formatRuntimePhaseLabel,
  getInstallExecutionPhase,
  hydrateExecutionState,
  INSTALL_EXECUTION_PHASES,
} from '../utils/installExecution.js';

test('estado inicial do fluxo de instalacao e idle', () => {
  const state = createInitialExecutionState();

  assert.equal(state.phase, INSTALL_EXECUTION_PHASES.IDLE);
  assert.equal(state.streamConnected, false);
  assert.match(state.logTail, /Aguardando inicio da esteira de instalacao/);
});

test('reidratacao a partir do backend preserva logs e fase atual', () => {
  const state = hydrateExecutionState(
    {
      havePlan: true,
      running: true,
      exitCode: null,
      currentPhase: 'MOUNT',
      lastLogLine: '[2026-03-13 09:41:00] [MOUNT] Montando layout split em /mnt',
    },
    '[2026-03-13 09:41:00] [MOUNT] Montando layout split em /mnt\n',
  );

  assert.equal(state.phase, INSTALL_EXECUTION_PHASES.RUNNING);
  assert.equal(state.planSubmitted, true);
  assert.equal(state.streamConnected, true);
  assert.equal(state.status.currentPhase, 'MOUNT');
  assert.match(state.logTail, /\[MOUNT\] Montando layout split em \/mnt/);
});

test('appendInstallLog concatena chunks sem perder o banner novo', () => {
  const log = appendInstallLog(createInstallLog(), '[FS] mkfs.ext4 concluido\n');

  assert.match(log, /RAGOS Installer Console/);
  assert.match(log, /\[FS\] mkfs\.ext4 concluido/);
});

test('transicao de status running para completed funciona no modelo', () => {
  const initial = hydrateExecutionState(
    { havePlan: true, running: true, exitCode: null, currentPhase: 'INSTALL' },
    '[INSTALL] nixos-install em andamento\n',
  );
  const completed = applyExecutionStatus(initial, {
    havePlan: true,
    running: false,
    exitCode: 0,
    currentPhase: 'VERIFY',
  });

  assert.equal(getInstallExecutionPhase(completed.status), INSTALL_EXECUTION_PHASES.COMPLETED);
  assert.equal(completed.phase, INSTALL_EXECUTION_PHASES.COMPLETED);
  assert.equal(completed.status.exitCode, 0);
});

test('lista de fases marca falha na fase corrente e expande label', () => {
  const stages = buildInstallStageList({
    running: false,
    exitCode: 1,
    currentPhase: 'PARTITION',
    lastError: '[2026-03-13 09:42:00] [ERROR] Falha em PARTITION: sgdisk (exit code 2)',
  });

  assert.equal(formatRuntimePhaseLabel('PARTITION'), 'Particionamento');
  assert.equal(stages.find((item) => item.id === 'INPUT')?.state, 'done');
  assert.equal(stages.find((item) => item.id === 'PARTITION')?.state, 'failed');
});
