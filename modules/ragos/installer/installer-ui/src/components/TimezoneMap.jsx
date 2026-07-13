import { useEffect, useMemo, useRef, useState } from 'react';
import { timezoneRegions } from '../data/timezoneRegions.js';
import {
  CALAMARES_BG_IMAGE,
  CALAMARES_PIN_IMAGE,
  CALAMARES_ZONE_IMAGE_KEYS,
  getCalamaresZoneImagePath,
} from '../utils/calamaresTimezoneImages.js';
import {
  decorateTimezoneLocation,
  findNearestTimezoneByMapPoint,
} from '../utils/nearestTimezone.js';
import {
  CALAMARES_MAP_HEIGHT,
  CALAMARES_MAP_WIDTH,
  projectTimezoneCoordinate,
} from '../utils/timezoneProjection.js';

function findZoneOverlayKey(location, layers) {
  if (!location || !layers || layers.size === 0) return '';

  const projected = projectTimezoneCoordinate(
    location.longitude,
    location.latitude,
    CALAMARES_MAP_WIDTH,
    CALAMARES_MAP_HEIGHT,
  );
  const sampleX = Math.max(0, Math.min(CALAMARES_MAP_WIDTH - 1, Math.round(projected.x)));
  const sampleY = Math.max(0, Math.min(CALAMARES_MAP_HEIGHT - 1, Math.round(projected.y)));

  for (const zoneKey of CALAMARES_ZONE_IMAGE_KEYS) {
    const layer = layers.get(zoneKey);
    const ctx = layer?.canvas?.getContext?.('2d', { willReadFrequently: true });
    if (!ctx) continue;

    const pixel = ctx.getImageData(sampleX, sampleY, 1, 1).data;
    if (pixel[3] > 0) {
      return zoneKey;
    }
  }

  return '';
}

export default function TimezoneMap({ locations = [], selectedLocation, value, onChange }) {
  const mapPlaneRef = useRef(null);
  const [layerState, setLayerState] = useState({ loading: true, layers: new Map(), error: '' });

  useEffect(() => {
    let cancelled = false;

    async function loadLayers() {
      try {
        const results = await Promise.all(
          CALAMARES_ZONE_IMAGE_KEYS.map((zoneKey) => new Promise((resolve, reject) => {
            const img = new Image();
            img.onload = () => {
              const canvas = document.createElement('canvas');
              canvas.width = CALAMARES_MAP_WIDTH;
              canvas.height = CALAMARES_MAP_HEIGHT;
              const ctx = canvas.getContext('2d', { willReadFrequently: true });
              if (!ctx) {
                reject(new Error(`Canvas indisponível para ${zoneKey}`));
                return;
              }
              ctx.clearRect(0, 0, canvas.width, canvas.height);
              ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
              resolve({ zoneKey, canvas });
            };
            img.onerror = () => reject(new Error(`Falha ao carregar ${zoneKey}`));
            img.src = getCalamaresZoneImagePath(zoneKey);
          })),
        );

        if (cancelled) return;

        const layers = new Map();
        for (const result of results) {
          layers.set(result.zoneKey, result);
        }
        setLayerState({ loading: false, layers, error: '' });
      } catch (err) {
        if (!cancelled) {
          setLayerState({
            loading: false,
            layers: new Map(),
            error: err instanceof Error ? err.message : 'Falha ao carregar as máscaras de timezone.',
          });
        }
      }
    }

    loadLayers();
    return () => {
      cancelled = true;
    };
  }, []);

  const projectedLocations = useMemo(() => {
    const source = locations.length > 0 ? locations : timezoneRegions;
    return source.map((item) => ({
      ...decorateTimezoneLocation(item),
      ...projectTimezoneCoordinate(item.longitude, item.latitude, CALAMARES_MAP_WIDTH, CALAMARES_MAP_HEIGHT),
    }));
  }, [locations]);

  const activeLocation = useMemo(
    () => projectedLocations.find((item) => item.timezone === selectedLocation?.timezone)
      || projectedLocations.find((item) => item.timezone === value)
      || null,
    [projectedLocations, selectedLocation, value],
  );

  const activeOverlayKey = useMemo(
    () => findZoneOverlayKey(activeLocation, layerState.layers),
    [activeLocation, layerState.layers],
  );

  const activeOverlaySrc = activeOverlayKey ? getCalamaresZoneImagePath(activeOverlayKey) : '';

  function handleMapClick(event) {
    const rect = mapPlaneRef.current?.getBoundingClientRect();
    if (!rect || projectedLocations.length === 0) return;

    const clickX = ((event.clientX - rect.left) / rect.width) * CALAMARES_MAP_WIDTH;
    const clickY = ((event.clientY - rect.top) / rect.height) * CALAMARES_MAP_HEIGHT;

    const { match } = findNearestTimezoneByMapPoint(
      clickX,
      clickY,
      projectedLocations,
      CALAMARES_MAP_WIDTH,
      CALAMARES_MAP_HEIGHT,
    );

    if (match) {
      onChange?.({ location: match });
    }
  }

  return (
    <div className="section-panel relative flex h-full min-h-0 w-full flex-col overflow-hidden p-2 lg:p-3">
      <div className="mb-2 flex items-start justify-between gap-3">
        <div>
          <h3 className="text-xl font-bold text-white">Mapa global</h3>
          <p className="mt-1 text-sm text-slate-400">
            Visual inspirado diretamente no Calamares: mapa base, máscara ativa por faixa e pino posicional.
          </p>
        </div>
        <div className="metric-chip border-amber-200/60 bg-amber-300/25 text-amber-50">
          {activeLocation?.label || value || 'Nenhum fuso selecionado'}
        </div>
      </div>

      <div className="relative flex min-h-0 flex-1 items-center justify-center overflow-hidden rounded-[24px] border border-cyan-400/20 bg-[radial-gradient(circle_at_top,rgba(15,23,42,0.96),rgba(2,6,23,0.9))] shadow-[inset_0_0_0_1px_rgba(34,211,238,0.06)]">
        <div
          ref={mapPlaneRef}
          className="relative w-full max-w-full cursor-pointer overflow-hidden rounded-[20px]"
          style={{ aspectRatio: `${CALAMARES_MAP_WIDTH} / ${CALAMARES_MAP_HEIGHT}` }}
          onClick={handleMapClick}
        >
          <img
            src={CALAMARES_BG_IMAGE}
            alt="Mapa de fusos horários inspirado no Calamares"
            className="absolute inset-0 h-full w-full object-fill select-none"
            draggable="false"
          />

          {activeOverlaySrc ? (
            <img
              src={activeOverlaySrc}
              alt="Faixa de timezone selecionada"
              className="absolute inset-0 h-full w-full object-fill opacity-95 mix-blend-screen select-none"
              draggable="false"
            />
          ) : null}

          {activeLocation ? (
            <>
              <img
                src={CALAMARES_PIN_IMAGE}
                alt="Marcador de timezone"
                className="pointer-events-none absolute z-10 h-8 w-8 -translate-x-1/2 -translate-y-1/2 drop-shadow-[0_10px_18px_rgba(0,0,0,0.45)] select-none"
                style={{
                  left: `${(activeLocation.x / CALAMARES_MAP_WIDTH) * 100}%`,
                  top: `${(activeLocation.y / CALAMARES_MAP_HEIGHT) * 100}%`,
                }}
                draggable="false"
              />
              <div
                className="pointer-events-none absolute z-10 -translate-x-1/2 -translate-y-[185%] rounded-full border border-amber-100/90 bg-amber-300/95 px-3 py-1.5 text-xs font-black text-slate-950 shadow-xl"
                style={{
                  left: `${(activeLocation.x / CALAMARES_MAP_WIDTH) * 100}%`,
                  top: `${(activeLocation.y / CALAMARES_MAP_HEIGHT) * 100}%`,
                }}
              >
                {activeLocation.label || activeLocation.timezone}
              </div>
            </>
          ) : null}

          <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_center,transparent_34%,rgba(2,6,23,0.10)_72%,rgba(2,6,23,0.30)_100%)]" />
        </div>

        {activeLocation ? (
          <div className="pointer-events-none absolute left-4 top-4 max-w-[260px] rounded-2xl border border-amber-200/70 bg-slate-950/96 px-3 py-2.5 text-xs text-amber-50 shadow-2xl backdrop-blur-xl">
            <div className="font-black text-amber-200">{activeLocation.label}</div>
            <div className="mt-1 text-amber-50">{activeLocation.timezone}</div>
            <div className="mt-1 text-amber-100">{activeLocation.group}</div>
            <div className="mt-1 text-[11px] text-amber-200/90">
              {Number(activeLocation.latitude).toFixed(4)}, {Number(activeLocation.longitude).toFixed(4)}
            </div>
            {activeOverlayKey ? (
              <div className="mt-1 text-[11px] text-amber-100/80">Faixa visual: UTC {activeOverlayKey}</div>
            ) : null}
          </div>
        ) : null}

        {(layerState.loading || layerState.error) ? (
          <div className="pointer-events-none absolute bottom-4 right-4 rounded-2xl border border-white/10 bg-slate-950/88 px-3 py-2 text-xs text-slate-300 backdrop-blur-xl">
            {layerState.loading ? 'Carregando máscaras de timezone do Calamares…' : layerState.error}
          </div>
        ) : null}
      </div>
    </div>
  );
}
