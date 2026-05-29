import { useEffect, useMemo, useRef, useState } from 'react';
import FieldError from '../components/FieldError.jsx';
import {
  allCountryCodes,
  countryCodeToFlag,
  countryPresets,
  fallbackKeymaps,
  fallbackLocales,
  getRegionName,
  parseLocaleLabel,
  scoreKeymapForCountry,
  scoreLocaleForCountry,
} from '../data/localizationMeta.js';
import { installerApi } from '../utils/installerApi.js';
import {
  fetchCanonicalCatalog,
  normalizeCountryCanonicalKey,
  normalizeCountryDisplayValue,
  normalizeKeymapCanonicalKey,
  normalizeKeymapDisplayValue,
  normalizeLocaleCanonicalKey,
  normalizeLocaleDisplayValue,
} from '../utils/localizationCatalog.js';
import { sanitizeShellInput } from '../utils/security.js';

function scoreByQuery(text, query) {
  const q = String(query || '').trim().toLowerCase();
  const t = String(text || '').toLowerCase();
  if (!q) return 0;
  if (t === q) return 400;
  if (t.startsWith(q)) return 240;
  if (t.includes(q)) return 120;
  return 0;
}

function SearchableList({ title, items, selectedValue, query, onQueryChange, onPick, emptyText, errorMessage }) {
  const [open, setOpen] = useState(false);
  const containerRef = useRef(null);
  const selectedItem = items.find((item) => item.value === selectedValue) || null;
  const previewItems = items.slice(0, 4);
  const normalizedQuery = String(query || '').trim();

  useEffect(() => {
    if (!open) return undefined;

    function handlePointerDown(event) {
      if (!containerRef.current?.contains(event.target)) {
        setOpen(false);
      }
    }

    function handleKeyDown(event) {
      if (event.key === 'Escape') {
        setOpen(false);
      }
    }

    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [open]);

  function handlePick(value) {
    onPick(value);
    setOpen(false);
  }

  return (
    <section ref={containerRef} className="section-panel relative flex h-full min-h-0 flex-col overflow-visible p-4">
      <div className="mb-4">
        <div className="text-sm font-bold text-white">{title}</div>
        <div className="mt-1 text-sm text-slate-400">Busca ativa com autocomplete seguro e lista resumida.</div>
      </div>

      <div className="relative">
        <input
          className="input-shell"
          value={query}
          onFocus={() => {
            if (normalizedQuery) {
              setOpen(true);
            }
          }}
          onChange={(event) => {
            const nextValue = sanitizeShellInput(event.target.value);
            onQueryChange(nextValue);
            setOpen(Boolean(String(nextValue || '').trim()));
          }}
          placeholder={`Buscar em ${title.toLowerCase()}...`}
        />
        <FieldError message={errorMessage} />

        {open ? (
          <div className="absolute left-0 right-0 top-full z-50 mt-2 rounded-2xl border border-white/10 bg-slate-950/95 p-3 shadow-2xl backdrop-blur-xl">
            <div className="mb-3 flex items-center justify-between gap-3 rounded-2xl border border-white/10 bg-white/[0.03] px-3 py-2.5">
              <span className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400">
                {items.length} resultados priorizados
              </span>
              <button type="button" className="btn-secondary !px-3 !py-1.5 text-xs" onClick={() => setOpen(false)}>
                Fechar
              </button>
            </div>

            <div className="max-h-56 overflow-y-auto rounded-2xl border border-white/10 bg-slate-950/70 p-2">
              {items.length === 0 ? <div className="px-3 py-4 text-sm text-slate-500">{emptyText}</div> : null}
              {items.map((item) => {
                const active = item.value === selectedValue;
                return (
                  <button
                    key={item.value}
                    type="button"
                    className={`mb-2 flex w-full items-center justify-between gap-3 rounded-xl border px-3 py-3 text-left text-sm transition last:mb-0 ${
                      active
                        ? 'border-accent-400/60 bg-accent-500/15 text-white'
                        : 'border-white/5 bg-white/[0.03] text-slate-300 hover:border-white/10 hover:bg-white/[0.05]'
                    }`}
                    onClick={() => handlePick(item.value)}
                  >
                    <div className="min-w-0 flex items-center gap-3">
                      {item.leading ? <span className="text-lg leading-none">{item.leading}</span> : null}
                      <div className="min-w-0">
                        <div className="truncate font-semibold text-white">{item.label}</div>
                        {item.secondary ? <div className="truncate text-xs text-slate-400">{item.secondary}</div> : null}
                      </div>
                    </div>
                    <div className="flex shrink-0 items-center gap-2">
                      {item.badge ? <span className="rounded-full border border-white/10 bg-white/5 px-2 py-1 text-[10px] font-bold uppercase tracking-[0.14em] text-slate-300">{item.badge}</span> : null}
                      {active ? <span className="text-xs font-bold text-cyan-300">ATIVO</span> : null}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        ) : null}
      </div>

      <div className="mt-3 rounded-2xl border border-white/10 bg-slate-950/60 p-3.5">
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Selecionado</div>
            <div className="mt-2 flex items-center gap-3">
              {selectedItem?.leading ? <span className="text-xl leading-none">{selectedItem.leading}</span> : null}
              <div className="min-w-0">
                <div className="truncate font-semibold text-white">{selectedItem?.label || 'Nenhum item selecionado'}</div>
                <div className="truncate text-xs text-slate-400">{selectedItem?.secondary || 'Use a busca para ver a lista completa.'}</div>
              </div>
            </div>
          </div>
          <span className="rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-[10px] font-bold uppercase tracking-[0.14em] text-slate-300">
            {items.length} itens
          </span>
        </div>

        <div className="mt-4 space-y-2">
          {previewItems.length === 0 ? (
            <div className="text-sm text-slate-500">{emptyText}</div>
          ) : (
            previewItems.map((item) => {
              const active = item.value === selectedValue;
              return (
                <button
                  key={item.value}
                  type="button"
                  className={`flex w-full items-center justify-between gap-3 rounded-xl border px-3 py-2.5 text-left text-sm transition ${
                    active
                      ? 'border-accent-400/60 bg-accent-500/15 text-white'
                      : 'border-white/5 bg-white/[0.03] text-slate-300 hover:border-white/10 hover:bg-white/[0.05]'
                  }`}
                  onClick={() => handlePick(item.value)}
                >
                  <div className="min-w-0 flex items-center gap-3">
                    {item.leading ? <span className="text-lg leading-none">{item.leading}</span> : null}
                    <div className="min-w-0">
                      <div className="truncate font-semibold text-white">{item.label}</div>
                      {item.secondary ? <div className="truncate text-xs text-slate-400">{item.secondary}</div> : null}
                    </div>
                  </div>
                  {active ? <span className="text-xs font-bold text-cyan-300">ATIVO</span> : null}
                </button>
              );
            })
          )}
        </div>

        <button type="button" className="mt-3 btn-primary w-full !py-2.5 text-sm" onClick={() => setOpen((value) => !value)}>
          {open ? 'Ocultar resultados' : 'Ver resultados da busca'}
        </button>
      </div>
    </section>
  );
}

export default function Localization({ wizard, onChange, validation }) {
  const [countries, setCountries] = useState([]);
  const [locales, setLocales] = useState([]);
  const [keymaps, setKeymaps] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [degradedMode, setDegradedMode] = useState(false);

  const [countryQuery, setCountryQuery] = useState('');
  const [localeQuery, setLocaleQuery] = useState('');
  const [keymapQuery, setKeymapQuery] = useState('');
  const fieldErrors = validation?.fieldErrors || {};

  useEffect(() => {
    let cancelled = false;

    async function loadAll() {
      try {
        setLoading(true);
        setError('');
        const [countriesData, localesData, keymapsData] = await Promise.all([
          fetchCanonicalCatalog(installerApi.getCountries, allCountryCodes, {
            normalizeDisplayValue: normalizeCountryDisplayValue,
            toCanonicalKey: normalizeCountryCanonicalKey,
          }),
          fetchCanonicalCatalog(installerApi.getLocales, fallbackLocales, {
            normalizeDisplayValue: normalizeLocaleDisplayValue,
            toCanonicalKey: normalizeLocaleCanonicalKey,
          }),
          fetchCanonicalCatalog(installerApi.getKeymaps, fallbackKeymaps, {
            normalizeDisplayValue: normalizeKeymapDisplayValue,
            toCanonicalKey: normalizeKeymapCanonicalKey,
          }),
        ]);

        if (!cancelled) {
          setCountries(countriesData.items);
          setLocales(localesData.items);
          setKeymaps(keymapsData.items);
          setDegradedMode(Boolean(countriesData.usedFallback || localesData.usedFallback || keymapsData.usedFallback));
        }
      } catch {
        if (!cancelled) {
          setError('Falha ao carregar catálogos de localização.');
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    loadAll();
    return () => {
      cancelled = true;
    };
  }, []);

  const selectedPreset = countryPresets[wizard.country] || null;
  const selectedCountryValue = useMemo(() => normalizeCountryDisplayValue(wizard.country), [wizard.country]);
  const selectedLocaleValue = useMemo(() => normalizeLocaleDisplayValue(wizard.locale), [wizard.locale]);
  const selectedKeymapValue = useMemo(() => normalizeKeymapDisplayValue(wizard.keyMap), [wizard.keyMap]);
  const availableCountries = useMemo(
    () => countries.filter(Boolean).sort((a, b) => a.localeCompare(b)),
    [countries],
  );

  const countryItems = useMemo(() => {
    return availableCountries
      .map((code) => {
        const label = getRegionName(code);
        const score = scoreByQuery(`${code} ${label}`, countryQuery) + (code === selectedCountryValue ? 1000 : 0);
        return {
          value: code,
          label,
          secondary: code,
          leading: countryCodeToFlag(code),
          score,
          badge: selectedPreset && code === selectedCountryValue ? 'preset' : '',
        };
      })
      .filter((item) => !countryQuery || item.score > 0)
      .sort((a, b) => b.score - a.score || a.label.localeCompare(b.label))
      .slice(0, 500);
  }, [availableCountries, countryQuery, selectedCountryValue, selectedPreset]);

  const localeItems = useMemo(() => {
    return locales
      .map((locale) => {
        const label = parseLocaleLabel(locale);
        const countryScore = scoreLocaleForCountry(locale, wizard.country);
        const presetScore = normalizeLocaleCanonicalKey(selectedPreset?.locale) === normalizeLocaleCanonicalKey(locale) ? 140 : 0;
        const activeScore = selectedLocaleValue === locale ? 1000 : 0;
        const queryScore = scoreByQuery(`${locale} ${label}`, localeQuery);
        return {
          value: locale,
          label,
          secondary: locale,
          score: activeScore + presetScore + countryScore + queryScore,
          badge: presetScore ? 'sugerido' : countryScore ? 'compatível' : '',
        };
      })
      .filter((item) => !localeQuery || item.score > 0)
      .sort((a, b) => b.score - a.score || a.secondary.localeCompare(b.secondary))
      .slice(0, 500);
  }, [locales, localeQuery, selectedLocaleValue, selectedPreset, wizard.country]);

  const keymapItems = useMemo(() => {
    return keymaps
      .map((keymap) => {
        const compatScore = scoreKeymapForCountry(keymap, wizard.country);
        const presetScore = normalizeKeymapCanonicalKey(selectedPreset?.keyMap) === normalizeKeymapCanonicalKey(keymap) ? 140 : 0;
        const activeScore = selectedKeymapValue === keymap ? 1000 : 0;
        const queryScore = scoreByQuery(keymap, keymapQuery);
        return {
          value: keymap,
          label: keymap,
          secondary: compatScore ? `Compatível com ${wizard.country}` : 'Layout disponível no sistema',
          score: activeScore + presetScore + compatScore + queryScore,
          badge: presetScore ? 'sugerido' : compatScore ? 'compatível' : '',
        };
      })
      .filter((item) => !keymapQuery || item.score > 0)
      .sort((a, b) => b.score - a.score || a.label.localeCompare(b.label))
      .slice(0, 500);
  }, [keymaps, keymapQuery, selectedKeymapValue, selectedPreset, wizard.country]);

  function applyCountry(value) {
    const preset = countryPresets[value] || null;
    onChange((previous) => ({
      country: value,
      locale: preset?.locale || previous.locale,
      keyMap: preset?.keyMap || previous.keyMap,
      timeZone: preset?.timeZone || previous.timeZone,
      timeZonePin: null,
      timeZoneLatitude: null,
      timeZoneLongitude: null,
      timeZoneCountryCode: '',
    }));
  }

  const localeLabel = useMemo(() => parseLocaleLabel(wizard.locale), [wizard.locale]);
  const countryLabel = useMemo(() => getRegionName(wizard.country), [wizard.country]);

  return (
    <div className="grid h-full min-h-0 gap-4 overflow-y-auto pb-2 pr-1 lg:grid-cols-3 lg:grid-rows-[minmax(0,1fr)_auto]">
      <SearchableList
        title="Países"
        items={countryItems}
        selectedValue={selectedCountryValue}
        query={countryQuery}
        onQueryChange={setCountryQuery}
        onPick={applyCountry}
        emptyText={loading ? 'Carregando países...' : 'Nenhum país encontrado. A lista interna do instalador já foi carregada.'}
        errorMessage={fieldErrors.country}
      />

      <SearchableList
        title="Idiomas / Locales"
        items={localeItems}
        selectedValue={selectedLocaleValue}
        query={localeQuery}
        onQueryChange={setLocaleQuery}
        onPick={(item) => onChange({ locale: item })}
        emptyText={loading ? 'Carregando locales...' : 'Nenhum idioma encontrado.'}
        errorMessage={fieldErrors.locale}
      />

      <SearchableList
        title="Layout de teclado"
        items={keymapItems}
        selectedValue={selectedKeymapValue}
        query={keymapQuery}
        onQueryChange={setKeymapQuery}
        onPick={(item) => onChange({ keyMap: normalizeKeymapDisplayValue(item) })}
        emptyText={loading ? 'Carregando keymaps...' : 'Nenhum layout encontrado.'}
        errorMessage={fieldErrors.keyMap}
      />

      {error ? (
        <div className="lg:col-span-3 rounded-2xl border border-rose-400/20 bg-rose-400/10 p-4 text-sm text-rose-200">
          {error}
        </div>
      ) : null}

      {degradedMode ? (
        <div className="lg:col-span-3 rounded-2xl border border-amber-400/20 bg-amber-400/10 p-4 text-sm text-amber-100">
          O catálogo interno complementou a resposta do backend para manter a lista de idiomas e layouts completa durante a instalação.
        </div>
      ) : null}

      <div className="lg:col-span-3 grid gap-4 lg:grid-cols-4">
        <div className="rounded-2xl border border-white/10 bg-white/[0.04] p-4">
          <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">País atual</div>
          <div className="mt-2 flex items-center gap-3 text-lg font-bold text-white">
            <span className="text-2xl">{countryCodeToFlag(wizard.country)}</span>
            <span>{countryLabel || '—'}</span>
          </div>
          <div className="mt-1 text-sm text-slate-400">{wizard.country || '—'}</div>
        </div>
        <div className="rounded-2xl border border-white/10 bg-white/[0.04] p-4">
          <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Locale atual</div>
          <div className="mt-2 break-words text-lg font-bold text-white">{localeLabel || '—'}</div>
          <div className="mt-1 break-all text-sm text-slate-400">{wizard.locale || '—'}</div>
        </div>
        <div className="rounded-2xl border border-white/10 bg-white/[0.04] p-4">
          <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Teclado atual</div>
          <div className="mt-2 text-lg font-bold text-white">{wizard.keyMap || '—'}</div>
          <div className="mt-1 text-sm text-slate-400">Layout do console/TTY</div>
        </div>
        <div className="rounded-2xl border border-cyan-400/20 bg-cyan-400/10 p-4">
          <div className="text-xs font-semibold uppercase tracking-[0.24em] text-cyan-200">Sugestão automática</div>
          <div className="mt-2 text-sm text-cyan-50">
            {selectedPreset ? (
              <>
                <div>Locale: <b>{selectedPreset.locale}</b></div>
                <div className="mt-1">Timezone: <b>{selectedPreset.timeZone}</b></div>
                <div className="mt-1">Teclado: <b>{selectedPreset.keyMap}</b></div>
              </>
            ) : 'Sem preset específico para este país; mantendo escolhas atuais.'}
          </div>
        </div>
      </div>
    </div>
  );
}
