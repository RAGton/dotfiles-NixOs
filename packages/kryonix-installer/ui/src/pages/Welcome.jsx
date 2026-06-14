import { useEffect, useState } from 'react';

export default function Welcome() {
  const [version, setVersion] = useState(null);
  const [detections, setDetections] = useState([]);

  useEffect(() => {
    fetch('/version')
      .then(r => r.ok ? r.json() : null)
      .then(data => setVersion(data))
      .catch(() => {});

    fetch('/api/detection')
      .then(r => r.ok ? r.json() : [])
      .then(data => setDetections(data))
      .catch(() => {});
  }, []);

  const hasKryonix = detections.some(d => d.is_kryonix);

  return (
    <div className="grid h-full min-h-0 gap-6 lg:grid-cols-[1.15fr_0.85fr]">
      <section className="section-panel flex min-h-0 flex-col justify-between overflow-y-auto">
        <div>
          <div className="metric-chip">Build focado em servidor</div>
          <h2 className="mt-5 text-2xl font-black tracking-tight text-white">Instalador redesenhado para estabilidade operacional</h2>

          {hasKryonix && (
            <div className="mt-6 rounded-xl border border-cyan-500/30 bg-cyan-500/5 p-4 animate-pulse">
              <div className="flex items-center gap-2 text-cyan-400 font-bold">
                <span className="h-2 w-2 rounded-full bg-cyan-400"></span>
                Instalação Kryonix detectada
              </div>
              <p className="mt-2 text-sm text-cyan-100/70">
                Detectamos o host <span className="text-white font-mono">{detections[0].hostname}</span> em <span className="text-white font-mono">{detections[0].device}</span>.
                Recomendamos o <strong>Modo Restore</strong> no passo de particionamento.
              </p>
            </div>
          )}

          <p className="mt-4 max-w-2xl text-base leading-7 text-slate-300">
            Esta refatoração elimina o arquivo monolítico, separa layout, footer, mapa e páginas críticas, e prepara a UI para evoluir sem travamentos.
          </p>
        </div>

        <div className="grid gap-4 md:grid-cols-3">
          <div className="section-panel bg-white/5">
            <div className="text-sm font-bold text-white">Layout imersivo</div>
            <p className="mt-2 text-sm text-slate-400">100vh/100vw, sem rolagem global e com glassmorphism controlado.</p>
          </div>
          <div className="section-panel bg-white/5">
            <div className="text-sm font-bold text-white">Mapa refinado</div>
            <p className="mt-2 text-sm text-slate-400">Timezone com regiões úteis, menos ruído visual e seleção mais clara.</p>
          </div>
          <div className="section-panel bg-white/5">
            <div className="text-sm font-bold text-white">Discos sem freeze</div>
            <p className="mt-2 text-sm text-slate-400">Cálculos pesados de partições saem do render e passam a usar memoização explícita.</p>
          </div>
        </div>

        {version && (
          <div className="mt-6 text-[10px] text-slate-500 font-mono">
            {version.KRYONIX_PRETTY_NAME} | {version.KRYONIX_REV?.substring(0, 8)} | {version.KRYONIX_BUILD_TIME}
          </div>
        )}
      </section>

      <section className="section-panel flex min-h-0 flex-col justify-center overflow-hidden">
        <div className="mx-auto flex h-full max-h-[420px] w-full max-w-[520px] items-center justify-center">
          <div className="w-full max-w-xl text-center">
            <svg viewBox="0 0 200 80" className="w-full h-auto mx-auto" fill="none" xmlns="http://www.w3.org/2000/svg">
              <defs>
                <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" stop-color="#22d3ee" stop-opacity="1"/>
                  <stop offset="100%" stop-color="#a855f7" stop-opacity="1"/>
                </linearGradient>
              </defs>
              <text x="50%" y="55%" dominant-baseline="middle" text-anchor="middle"
                    font-family="system-ui, sans-serif" font-size="42" font-weight="800"
                    fill="url(#grad)" letter-spacing="-0.02em">Kryonix</text>
              <text x="50%" y="75%" dominant-baseline="middle" text-anchor="middle"
                    font-family="system-ui, sans-serif" font-size="11" font-weight="500"
                    fill="#64748b" letter-spacing="0.08em" text-transform="uppercase">Installer</text>
              <circle cx="35" cy="25" r="12" fill="url(#grad)" opacity="0.3"/>
              <circle cx="165" cy="55" r="8" fill="#22d3ee" opacity="0.4"/>
              <circle cx="25" cy="65" r="6" fill="#a855f7" opacity="0.3"/>
            </svg>
            <p className="mt-6 text-slate-400 text-sm leading-relaxed max-w-md mx-auto">
              Instalador redesenhado para estabilidade operacional. Fluxo imersivo,
              validações em tempo real e geração declarativa de configuração NixOS.
            </p>
          </div>
        </div>
      </section>
    </div>
  );
}
