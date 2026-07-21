export default function TimezoneSelector({
  query,
  onQueryChange,
  selectedTimezone,
  selectedLocation,
  quickRegions,
  filtered,
  loading,
  error,
  groupCount,
  onPick,
  onPickUtc,
  manualMatch,
}) {
  return (
    <section className="section-panel flex min-h-0 flex-col overflow-y-auto p-4">
      <div>
        <label htmlFor="timezone-search" className="label-text">Timezone IANA</label>
        <input
          id="timezone-search"
          className="input-shell"
          value={query}
          onChange={(event) => onQueryChange(event.target.value)}
          placeholder="Ex.: America/Sao_Paulo"
        />
        <p className="mt-3 text-sm leading-6 text-slate-400">
          Pesquise por IANA, cidade ou região. A seleção real só muda quando você escolhe um resultado,
          evitando combinações contraditórias entre busca, mapa e resumo final.
        </p>
      </div>

      <div className="mt-4 flex flex-wrap items-center gap-2">
        <button type="button" className="btn-secondary !px-4 !py-2.5" onClick={onPickUtc}>
          Usar UTC
        </button>
        {manualMatch && manualMatch.timezone !== selectedTimezone ? (
          <button type="button" className="btn-primary !px-4 !py-2.5" onClick={() => onPick(manualMatch)}>
            Aplicar {manualMatch.timezone}
          </button>
        ) : null}
        <div className="metric-chip !text-[11px]">Selecionado: {selectedTimezone || '—'}</div>
      </div>

      <div className="mt-4 rounded-2xl border border-white/10 bg-white/[0.04] p-3.5">
        <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Região atual</div>
        <div className="mt-2 text-sm font-bold text-white">{selectedLocation?.label || 'Sem região mapeada'}</div>
        <div className="mt-1 text-sm text-slate-400">{selectedLocation?.group || 'Busca manual / UTC'}</div>
        {selectedLocation?.latitude !== undefined && selectedLocation?.longitude !== undefined ? (
          <div className="mt-2 text-xs text-slate-500">
            {Number(selectedLocation.latitude).toFixed(4)}, {Number(selectedLocation.longitude).toFixed(4)}
          </div>
        ) : null}
      </div>

      <div className="mt-4 max-h-[140px] overflow-y-auto rounded-2xl border border-white/10 bg-slate-950/60 p-3">
        <div className="mb-3 text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Atalhos úteis</div>
        <div className="grid grid-cols-1 gap-2">
          {quickRegions.map((region) => (
            <button
              key={region.timezone}
              type="button"
              className={region.timezone === selectedTimezone ? 'btn-primary !px-3 !py-2 text-xs !leading-5' : 'btn-secondary !px-3 !py-2 text-xs !leading-5'}
              onClick={() => onPick(region)}
            >
              {region.label}
            </button>
          ))}
        </div>
      </div>

      <div className="mt-4 min-h-[180px] flex-1 overflow-hidden rounded-2xl border border-white/10 bg-slate-950/70">
        <div className="border-b border-white/10 px-4 py-3 text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">
          Resultados {loading ? '• carregando' : `• ${filtered.length} itens`} • {groupCount} macro-regiões
        </div>
        <div className="h-[220px] overflow-y-auto px-2 py-2 lg:h-full">
          {error ? <div className="px-3 py-4 text-sm text-rose-300">{error}</div> : null}
          {!error && filtered.length === 0 && !loading ? (
            <div className="px-3 py-4 text-sm text-slate-400">Nenhum timezone encontrado.</div>
          ) : null}
          {filtered.map((item) => {
            const active = item.timezone === selectedTimezone;
            return (
              <button
                key={item.timezone}
                type="button"
                className={`mb-2 flex w-full items-center justify-between rounded-xl border px-3 py-3 text-left text-sm transition ${
                  active
                    ? 'border-accent-400/60 bg-accent-500/15 text-white'
                    : 'border-white/5 bg-white/[0.03] text-slate-300 hover:border-white/10 hover:bg-white/[0.05]'
                }`}
                onClick={() => onPick(item)}
              >
                <div className="min-w-0">
                  <div className="truncate">{item.timezone}</div>
                  <div className="truncate text-xs text-slate-500">{item.label} • {item.group}</div>
                </div>
                {active ? <span className="text-xs font-bold text-cyan-300">ATIVO</span> : null}
              </button>
            );
          })}
        </div>
      </div>
    </section>
  );
}
