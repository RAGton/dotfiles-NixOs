import { useEffect, useMemo, useRef, useState } from 'react';
import { useInstallExecution } from '../hooks/useInstallExecution.js';
import {
  buildInstallStageList,
  formatRuntimePhaseLabel,
  INSTALL_EXECUTION_PHASES,
} from '../utils/installExecution.js';

function stageTone(state) {
  switch (state) {
    case 'done':
      return 'border-emerald-400/20 bg-emerald-400/10 text-emerald-100';
    case 'active':
      return 'border-cyan-400/30 bg-cyan-400/10 text-cyan-50';
    case 'failed':
      return 'border-rose-400/30 bg-rose-400/10 text-rose-100';
    default:
      return 'border-white/10 bg-white/[0.03] text-slate-400';
  }
}

export default function Install({ draft, uiState, validation }) {
  const logRef = useRef(null);
  const [rebootBusy, setRebootBusy] = useState(false);
  const {
    executionState,
    planPayload,
    installValidation,
    startInstallation,
    requestReboot,
  } = useInstallExecution({ draft, uiState });

  useEffect(() => {
    if (!logRef.current) return;
    logRef.current.scrollTop = logRef.current.scrollHeight;
  }, [executionState.logTail]);

  const phase = executionState.phase;
  const runtimePhase = executionState.status.currentPhase;
  const finalExit = executionState.status.exitCode;
  const installSucceeded = phase === INSTALL_EXECUTION_PHASES.COMPLETED;
  const installFailed = phase === INSTALL_EXECUTION_PHASES.FAILED;
  const installRunning = phase === INSTALL_EXECUTION_PHASES.RUNNING || phase === INSTALL_EXECUTION_PHASES.VALIDATING;
  const stages = useMemo(() => buildInstallStageList(executionState.status), [executionState.status]);

  const visibleIssues = useMemo(() => {
    const fromInstall = installValidation.blockingIssues.length > 0
      ? installValidation.blockingIssues
      : installValidation.warnings;
    return fromInstall.length > 0 ? fromInstall : (validation?.warnings || []);
  }, [installValidation.blockingIssues, installValidation.warnings, validation?.warnings]);

  const targetSummary = useMemo(() => {
    const dataTarget = planPayload.disk.profile === 'raid'
      ? `array ${String(planPayload.disk.raidLevel || '').toUpperCase()}`
      : planPayload.disk.dataDisk || '/srv/data no mesmo BTRFS da raiz';

    return [
      ['Hostname', planPayload.network.hostname || '-'],
      ['Timezone', planPayload.locale.timezone || '-'],
      ['Interface', planPayload.network.interface || '-'],
      ['Sistema', planPayload.disk.sysDisk || '-'],
      ['Dados', dataTarget],
      ['Root FS', planPayload.disk.rootFs || '-'],
      ['Data FS', planPayload.disk.dataFs || '-'],
    ];
  }, [planPayload]);

  const finalFailure = executionState.status.lastError
    || executionState.globalError
    || (installFailed ? `Falha na fase ${runtimePhase || 'desconhecida'} com exit code ${finalExit ?? 1}.` : '');

  async function handleReboot() {
    try {
      setRebootBusy(true);
      await requestReboot();
    } finally {
      setRebootBusy(false);
    }
  }

  return (
    <div className="grid h-full min-h-0 gap-5 lg:grid-cols-[0.4fr_1fr]">
      <section className="section-panel flex min-h-0 flex-col border border-emerald-400/10 bg-slate-950/95">
        <div>
          <div className="text-xs font-semibold uppercase tracking-[0.32em] text-emerald-400/80">Kryonix installer</div>
          <h2 className="mt-3 text-2xl font-black text-white">Execucao operacional</h2>
          <p className="mt-2 text-sm text-slate-400">
            Esta tela acompanha o que o backend e o shell realmente executam no alvo. Sem confirmacao destrutiva, o wipe nao inicia.
          </p>
        </div>

        <div className="mt-5 space-y-4 overflow-y-auto pr-1">
          <button
            type="button"
            className="btn-primary"
            disabled={installRunning || !uiState.destructiveConfirmed || installValidation.blockingIssues.length > 0}
            onClick={startInstallation}
          >
            {phase === INSTALL_EXECUTION_PHASES.VALIDATING
              ? 'Validando pipeline...'
              : phase === INSTALL_EXECUTION_PHASES.RUNNING
                ? 'Instalacao em execucao'
                : 'Instalar agora'}
          </button>

          <button type="button" className="btn-secondary" disabled={!installSucceeded || rebootBusy} onClick={handleReboot}>
            {rebootBusy ? 'Reiniciando...' : 'Reiniciar sistema'}
          </button>

          <div className="rounded-2xl border border-rose-400/20 bg-rose-400/10 p-4 text-sm text-rose-200">
            <div className="font-semibold text-rose-50">Gate destrutivo</div>
            <div className="mt-1">
              {uiState.destructiveConfirmed
                ? 'confirmado: o backend recebeu permissao para apagar os discos selecionados.'
                : 'bloqueado: volte ao resumo e confirme o wipe antes de iniciar.'}
            </div>
          </div>

          {visibleIssues.length > 0 ? (
            <div className="rounded-2xl border border-amber-400/20 bg-amber-400/10 p-4 text-sm text-amber-100">
              <div className="font-semibold text-amber-50">Bloqueios e alertas</div>
              <ul className="mt-2 list-disc space-y-1 pl-5">
                {visibleIssues.map((issue) => <li key={issue}>{issue}</li>)}
              </ul>
            </div>
          ) : null}

          {(executionState.globalError && !executionState.status.lastError) ? (
            <div className="rounded-2xl border border-rose-400/20 bg-rose-400/10 p-4 text-sm text-rose-200">
              {executionState.globalError}
            </div>
          ) : null}

          <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-4 text-sm text-slate-300">
            <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-500">Estado atual</div>
            <div className="mt-3 space-y-1">
              <div>Status geral: <b className="text-white">{phase}</b></div>
              <div>Fase atual: <b className="text-white">{formatRuntimePhaseLabel(runtimePhase)}</b></div>
              <div>Plano salvo: <b className="text-white">{executionState.planSubmitted ? 'sim' : 'nao'}</b></div>
              <div>Streaming: <b className="text-white">{executionState.streamConnected ? 'ativo' : 'inativo'}</b></div>
              <div>Exit code: <b className="text-white">{finalExit ?? '-'}</b></div>
            </div>
          </div>

          <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-4 text-sm text-slate-300">
            <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-500">Resumo do alvo</div>
            <div className="mt-3 space-y-2">
              {targetSummary.map(([label, value]) => (
                <div key={label} className="flex items-center justify-between gap-3 rounded-xl border border-white/10 bg-black/20 px-3 py-2">
                  <span className="text-slate-400">{label}</span>
                  <span className="text-right font-semibold text-white">{value}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-4 text-sm text-slate-300">
            <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-500">Fases</div>
            <div className="mt-3 space-y-2">
              {stages.map((stage) => (
                <div key={stage.id} className={`rounded-xl border px-3 py-2 ${stageTone(stage.state)}`}>
                  <div className="flex items-center justify-between gap-3">
                    <span className="font-semibold">{stage.label}</span>
                    <span className="text-[11px] uppercase tracking-[0.2em]">{stage.state}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className={`rounded-2xl border p-4 text-sm ${installSucceeded ? 'border-emerald-400/20 bg-emerald-400/10 text-emerald-100' : installFailed ? 'border-rose-400/20 bg-rose-400/10 text-rose-100' : 'border-cyan-400/20 bg-cyan-400/10 text-cyan-50'}`}>
            {installSucceeded
              ? 'Instalacao concluida com sucesso. O reinicio foi liberado.'
              : installFailed
                ? finalFailure
                : 'O terminal ao lado transmite o log do shell em tempo real, com fase, verificacao e erro concreto.'}
          </div>
        </div>
      </section>

      <section className="flex min-h-0 flex-col overflow-hidden rounded-3xl border border-emerald-400/20 bg-[#050b06] shadow-[0_0_0_1px_rgba(16,185,129,0.08)]">
        <div className="flex items-center justify-between gap-4 border-b border-emerald-400/10 px-5 py-4">
          <div>
            <div className="text-xs font-semibold uppercase tracking-[0.28em] text-emerald-400/80">Terminal de instalacao</div>
            <h3 className="mt-1 text-lg font-bold text-emerald-100">Fase: {formatRuntimePhaseLabel(runtimePhase)}</h3>
            <div className="mt-1 text-xs text-slate-500">
              Ultima linha util: {executionState.status.lastLogLine || '-'}
            </div>
          </div>
          <div className="rounded-full border border-emerald-400/20 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-emerald-300">
            {phase}
          </div>
        </div>

        {finalFailure ? (
          <div className="border-b border-rose-400/10 bg-rose-400/10 px-5 py-3 text-sm text-rose-100">
            <span className="font-semibold text-rose-50">Causa concreta:</span> {finalFailure}
          </div>
        ) : null}

        <pre
          ref={logRef}
          className="min-h-0 flex-1 overflow-auto bg-[#020703] px-5 py-4 text-xs leading-6 text-[#9ef7bd]"
        >
          {executionState.logTail}
        </pre>
      </section>
    </div>
  );
}
