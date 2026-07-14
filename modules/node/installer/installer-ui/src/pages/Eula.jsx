export default function Eula({ uiState, onChange, validation }) {
  return (
    <div className="grid h-full min-h-0 gap-6 lg:grid-cols-[1.2fr_0.8fr]">
      <section className="section-panel flex min-h-0 flex-col overflow-hidden">
        <div className="mb-4">
          <h2 className="text-xl font-black text-white">Termos de uso e aviso operacional</h2>
          <p className="mt-2 text-sm leading-6 text-slate-300">
            Este instalador pode apagar discos, reconfigurar rede e alterar permanentemente a máquina alvo.
            Prossiga apenas se você compreende o impacto e tem autorização para operar este equipamento.
          </p>
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto rounded-2xl border border-white/10 bg-slate-950/60 p-5 text-sm leading-6 text-slate-300">
          <p><b>1.</b> O sistema será instalado com foco em uso de servidor.</p>
          <p className="mt-3"><b>2.</b> A etapa de particionamento pode destruir dados existentes.</p>
          <p className="mt-3"><b>3.</b> Configurações incorretas de rede podem tornar o servidor inacessível.</p>
          <p className="mt-3"><b>4.</b> O operador é responsável por confirmar discos, interface de rede, timezone, locale e layouts de teclado.</p>
          <p className="mt-3"><b>5.</b> Esta UI foi desenhada para reduzir erros, mas não elimina a necessidade de revisão final.</p>
          <p className="mt-3"><b>6.</b> A navegação por atalho e salto direto fica bloqueada nesta etapa. O avanço só ocorre pelo botão Próximo após aceite explícito.</p>
        </div>
      </section>

      <section className="section-panel flex min-h-0 flex-col justify-between">
        <div>
          <div className="rounded-2xl border border-amber-400/20 bg-amber-400/10 p-4 text-sm text-amber-100">
            <div className="font-bold">Aviso destrutivo</div>
            <p className="mt-2">Ao seguir até as etapas finais, você poderá sobrescrever partições e arquivos existentes.</p>
          </div>

          <label className="mt-6 flex cursor-pointer items-start gap-3 rounded-2xl border border-white/10 bg-white/[0.03] p-4">
            <input
              type="checkbox"
              className="mt-1 h-5 w-5 rounded border-white/20 bg-slate-950 text-accent-500"
              checked={uiState.eulaAccepted}
              onChange={(event) => onChange({ eulaAccepted: event.target.checked })}
            />
            <div>
              <div className="font-semibold text-white">Eu li e aceito os termos acima</div>
              <div className="mt-1 text-sm text-slate-400">Também confirmo que entendo o risco de perda de dados durante a instalação.</div>
            </div>
          </label>
        </div>

        <div className="rounded-2xl border border-white/10 bg-white/[0.04] p-4 text-sm text-slate-300">
          <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Status</div>
          <div className="mt-2 font-bold text-white">{uiState.eulaAccepted ? 'Aceite confirmado' : 'Aceite pendente'}</div>
          <div className="mt-2 text-slate-400">Somente o botão Próximo libera a continuação, e apenas quando o aceite estiver ativo.</div>
          {validation?.blockingIssues?.length > 0 ? (
            <div className="mt-3 rounded-xl border border-rose-400/20 bg-rose-400/10 px-3 py-2 text-rose-200">
              {validation.blockingIssues[0]}
            </div>
          ) : null}
        </div>
      </section>
    </div>
  );
}
