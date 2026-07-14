import { useRef, useState } from 'react';

export default function FooterFixed({
  progressLabel,
  progressValue,
  issues = [],
  canBack,
  canNext,
  onBack,
  onNext,
  nextLabel = 'Próximo',
  hintText = 'Pronto para avançar. Navegação rápida: Alt + ← / Alt + →',
}) {
  const lockRef = useRef(false);
  const [localBusy, setLocalBusy] = useState(false);

  // Anti double-click para impedir navegação repetida em sequência.
  async function runLocked(action, enabled) {
    if (!enabled || lockRef.current) {
      return;
    }
    lockRef.current = true;
    setLocalBusy(true);
    try {
      await action?.();
    } finally {
      window.setTimeout(() => {
        lockRef.current = false;
        setLocalBusy(false);
      }, 250);
    }
  }

  return (
    <footer className="pointer-events-none relative z-30 h-16 shrink-0 px-3 py-2 sm:px-4 lg:px-5">
      <div className="glass-panel pointer-events-auto mx-auto flex h-full w-full max-w-[1480px] items-center gap-3 px-4 py-2 sm:px-5">
        <div className="min-w-0 flex-1">
          <div className="flex items-center justify-between gap-4">
            <span className="truncate text-sm font-semibold text-slate-200">{progressLabel}</span>
            <span className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">{progressValue}%</span>
          </div>
          <div className="mt-1.5 h-1 overflow-hidden rounded-full bg-white/10">
            <div
              className="h-full rounded-full bg-gradient-to-r from-accent-400 to-cyan-300 transition-all duration-300"
              style={{ width: `${progressValue}%` }}
            />
          </div>
          <div className="mt-1 hidden min-h-[16px] text-xs text-slate-400 lg:block">
            {issues.length > 0 ? (
              <span className="text-amber-300">Ajuste pendente: {issues[0]}</span>
            ) : (
              <span>{hintText}</span>
            )}
          </div>
        </div>

        <div className="flex shrink-0 items-center justify-end gap-3">
          <button type="button" className="btn-secondary !px-5 !py-2.5" onClick={() => runLocked(onBack, canBack && !localBusy)} disabled={!canBack || localBusy}>
            Voltar
          </button>
          <button type="button" className="btn-primary !px-5 !py-2.5" onClick={() => runLocked(onNext, canNext && !localBusy)} disabled={!canNext || localBusy}>
            {nextLabel}
          </button>
        </div>
      </div>
    </footer>
  );
}
