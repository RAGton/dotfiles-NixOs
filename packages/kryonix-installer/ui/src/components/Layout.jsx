export default function Layout({
  title,
  subtitle,
  stepLabel,
  steps = [],
  currentStepIndex = 0,
  onStepJump,
  children,
  footer,
  navigationHint = 'Alt + ← / Alt + →',
}) {
  return (
    <div className="relative flex h-screen w-screen flex-col overflow-hidden bg-slate-950">
      <div
        className="absolute inset-0 bg-cover bg-center opacity-90"
        style={{ backgroundImage: "url('/imgs/logoterminal.png')" }}
      />
      <div className="absolute inset-0 bg-slate-950/70" />
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(96,165,250,0.22),transparent_30%),radial-gradient(circle_at_bottom_left,rgba(59,130,246,0.18),transparent_28%)]" />

      <div className="relative z-10 flex h-full w-full flex-col overflow-hidden">
        <header className="flex h-16 shrink-0 items-center justify-between gap-4 px-4 sm:px-5 lg:px-6">
          <div className="flex min-w-0 items-center gap-3">
            <div className="rounded-xl border border-white/10 bg-white/5 p-2.5 backdrop-blur-xl">
              <img src="/imgs/ragton.png" alt="RAGos" className="h-8 w-auto" />
            </div>
            <div className="min-w-0">
              <div className="text-xs font-semibold uppercase tracking-[0.28em] text-slate-300">RAGos Think</div>
              <div className="truncate text-xs text-slate-400 sm:text-sm">Installer UI • React + Vite + Tailwind</div>
            </div>
          </div>

          <div className="flex shrink-0 items-center gap-2">
            <div className="metric-chip hidden sm:inline-flex">{navigationHint}</div>
            <div className="metric-chip">{stepLabel}</div>
          </div>
        </header>

        <main className="min-h-0 flex-1 overflow-y-auto overflow-x-hidden px-4 pb-4 sm:px-5 lg:px-6 lg:pb-5">
          <section className="glass-panel flex min-h-full flex-col overflow-visible px-4 py-4 sm:px-5 sm:py-4 lg:px-6 lg:py-5">
            <div className="shrink-0">
              <div className="mb-3 overflow-x-auto pb-1">
                <div className="flex min-w-max items-center gap-2">
                  {steps.map((step, index) => {
                    const isCurrent = step.status === 'current';
                    const isDone = step.status === 'done';
                    return (
                      <button
                        key={step.id}
                        type="button"
                        onClick={() => onStepJump?.(index)}
                        disabled={!onStepJump}
                        className={`flex items-center gap-2.5 rounded-2xl border px-3 py-2 text-left transition ${
                          isCurrent
                            ? 'border-accent-400/50 bg-accent-500/15 text-white'
                            : isDone
                              ? 'border-emerald-400/30 bg-emerald-400/10 text-emerald-100 hover:bg-emerald-400/15'
                              : 'border-white/10 bg-white/[0.03] text-slate-400 hover:bg-white/[0.06]'
                        } disabled:cursor-not-allowed disabled:opacity-60 disabled:hover:bg-white/[0.03]`}
                      >
                        <span className={`flex h-7 w-7 items-center justify-center rounded-full text-xs font-black ${isCurrent ? 'bg-accent-400 text-slate-950' : isDone ? 'bg-emerald-400 text-slate-950' : 'bg-white/10 text-slate-200'}`}>
                          {isDone ? '✓' : index + 1}
                        </span>
                        <span className="max-w-[160px] truncate text-[11px] font-semibold uppercase tracking-[0.18em] lg:max-w-[180px]">
                          {step.title}
                        </span>
                      </button>
                    );
                  })}
                </div>
              </div>

              <h1 className="text-2xl font-black tracking-tight text-white sm:text-3xl">{title}</h1>
              {subtitle ? <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-300">{subtitle}</p> : null}
            </div>
            <div className="mt-4 min-h-0 flex-1 overflow-visible">{children}</div>
          </section>
        </main>

        {footer}
      </div>
    </div>
  );
}
