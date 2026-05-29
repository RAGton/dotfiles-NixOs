export default function Layout({
  title,
  subtitle,
  steps = [],
  currentStepIndex = 0,
  onStepJump,
  children,
  footer,
}) {
  return (
    <div className="shell">
      <header className="hdr">
        <div className="logo">⟡ KRYONIX <span>installer</span></div>

        <nav className="breadcrumb" aria-label="Etapas">
          {steps.map((step, index) => {
            const isDone    = step.status === 'done';
            const isCurrent = step.status === 'current';
            const canJump   = isDone || index <= currentStepIndex;

            return (
              <button
                key={step.id}
                type="button"
                className={`crumb ${step.status}`}
                onClick={() => canJump && onStepJump?.(index)}
                disabled={!canJump || !onStepJump}
                title={step.title}
                aria-current={isCurrent ? 'step' : undefined}
              >
                <span className="crumb-num">{isDone ? '✓' : index + 1}</span>
                <span>{step.title}</span>
              </button>
            );
          })}
        </nav>
      </header>

      {/* Área principal scrollável — mesmo modelo do original (glass-panel) */}
      <main className="content">
        <section className="page-shell">
          {(title || subtitle) && (
            <div className="page-header">
              {title    && <h1 className="page-title">{title}</h1>}
              {subtitle && <p className="page-subtitle">{subtitle}</p>}
            </div>
          )}
          {/* flex-1 + min-h-0 → h-full dos filhos funciona corretamente */}
          <div className="page-body">
            {children}
          </div>
        </section>
      </main>

      {footer}
    </div>
  );
}
