export default function Welcome() {
  return (
    <div className="grid h-full min-h-0 gap-6 lg:grid-cols-[1.15fr_0.85fr]">
      <section className="section-panel flex min-h-0 flex-col justify-between overflow-y-auto">
        <div>
          <div className="metric-chip">Build focado em servidor</div>
          <h2 className="mt-5 text-2xl font-black tracking-tight text-white">Instalador redesenhado para estabilidade operacional</h2>
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
      </section>

      <section className="section-panel flex min-h-0 flex-col justify-center overflow-hidden">
        <div className="mx-auto flex h-full max-h-[420px] w-full max-w-[520px] items-center justify-center rounded-[28px] border border-white/10 bg-black/20 p-8">
          <img src="/imgs/ragton.png" alt="RAGos" className="max-h-full w-auto object-contain opacity-95" />
        </div>
      </section>
    </div>
  );
}
