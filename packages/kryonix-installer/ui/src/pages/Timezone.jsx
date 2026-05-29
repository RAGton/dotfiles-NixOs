import { useEffect, useMemo, useState } from 'react';
import FieldError from '../components/FieldError.jsx';
import TimezoneMap from '../components/TimezoneMap.jsx';
import TimezoneSelector from '../components/TimezoneSelector.jsx';
import { timezoneRegions } from '../data/timezoneRegions.js';
import { installerApi } from '../utils/installerApi.js';
import {
  decorateTimezoneLocation,
  isMappableTimezone,
  normalizeTimezoneLabel,
  timezoneRegionKey,
} from '../utils/nearestTimezone.js';

function resolveSelectionPatch(location) {
  if (!location) {
    return {
      timeZone: '',
      timeZonePin: null,
      timeZoneLatitude: null,
      timeZoneLongitude: null,
      timeZoneCountryCode: '',
    };
  }

  return {
    timeZone: location.timezone,
    timeZonePin: {
      label: location.label,
      latitude: location.latitude,
      longitude: location.longitude,
      countryCode: location.countryCode || '',
    },
    timeZoneLatitude: location.latitude,
    timeZoneLongitude: location.longitude,
    timeZoneCountryCode: location.countryCode || '',
  };
}

function mergeTimezoneLocations(timezones, locations) {
  const map = new Map();

  for (const raw of timezoneRegions) {
    const item = decorateTimezoneLocation(raw);
    map.set(item.timezone, item);
  }

  for (const raw of locations) {
    const item = decorateTimezoneLocation(raw);
    if (!item.timezone) continue;
    map.set(item.timezone, {
      ...map.get(item.timezone),
      ...item,
      label: item.label || map.get(item.timezone)?.label || normalizeTimezoneLabel(item.timezone),
      group: item.group || map.get(item.timezone)?.group || timezoneRegionKey(item.timezone),
    });
  }

  for (const timezone of timezones) {
    if (!map.has(timezone)) {
      map.set(timezone, decorateTimezoneLocation({ timezone }));
    }
  }

  return Array.from(map.values()).sort((a, b) => a.timezone.localeCompare(b.timezone));
}

export default function Timezone({ wizard, onChange, validation }) {
  const [timezones, setTimezones] = useState([]);
  const [timezoneLocations, setTimezoneLocations] = useState([]);
  const [query, setQuery] = useState(wizard.timeZone || '');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const fieldErrors = validation?.fieldErrors || {};

  useEffect(() => {
    setQuery(wizard.timeZone || '');
  }, [wizard.timeZone]);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      let nextError = '';

      try {
        setLoading(true);
        setError('');

        const [listResult, locationsResult] = await Promise.allSettled([
          installerApi.getTimezones(),
          installerApi.getTimezoneLocations(),
        ]);

        if (cancelled) {
          return;
        }

        const items = listResult.status === 'fulfilled' && Array.isArray(listResult.value?.items)
          ? listResult.value.items
          : [];
        const locations = locationsResult.status === 'fulfilled' && Array.isArray(locationsResult.value?.items)
          ? locationsResult.value.items
          : [];

        setTimezones(items.length > 0 ? items : timezoneRegions.map((item) => item.timezone));
        setTimezoneLocations(locations.length > 0 ? locations : timezoneRegions);

        if (listResult.status !== 'fulfilled' && locationsResult.status !== 'fulfilled') {
          nextError = 'Backend indisponível para timezones. Usando catálogo interno do instalador.';
        } else if (locationsResult.status !== 'fulfilled') {
          nextError = 'Coordenadas de timezone indisponíveis no backend. Usando mapa interno do instalador.';
        } else if (listResult.status !== 'fulfilled') {
          nextError = 'Lista canônica de timezones indisponível no backend. Usando catálogo interno do instalador.';
        }
      } finally {
        if (!cancelled) {
          setError(nextError);
          setLoading(false);
        }
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, []);

  const mergedLocations = useMemo(
    () => mergeTimezoneLocations(timezones, timezoneLocations),
    [timezones, timezoneLocations],
  );

  const mappableLocations = useMemo(
    () => mergedLocations.filter(isMappableTimezone),
    [mergedLocations],
  );

  const selectedLocation = useMemo(
    () => mergedLocations.find((item) => item.timezone === wizard.timeZone) || null,
    [mergedLocations, wizard.timeZone],
  );

  useEffect(() => {
    if (!wizard.timeZone || !selectedLocation) return;

    if (
      wizard.timeZoneLatitude !== selectedLocation.latitude
      || wizard.timeZoneLongitude !== selectedLocation.longitude
      || wizard.timeZoneCountryCode !== (selectedLocation.countryCode || '')
      || wizard.timeZonePin?.label !== selectedLocation.label
    ) {
      onChange(resolveSelectionPatch(selectedLocation));
    }
  }, [
    onChange,
    selectedLocation,
    wizard.timeZone,
    wizard.timeZoneCountryCode,
    wizard.timeZoneLatitude,
    wizard.timeZoneLongitude,
    wizard.timeZonePin?.label,
  ]);

  const filtered = useMemo(() => {
    const lower = query.trim().toLowerCase();
    const pool = mergedLocations;
    if (!lower) return pool.slice(0, 250);

    return pool
      .filter((item) => `${item.timezone} ${item.label} ${item.group} ${item.countryCode}`.toLowerCase().includes(lower))
      .slice(0, 250);
  }, [mergedLocations, query]);

  const quickRegions = useMemo(() => {
    const preferred = mergedLocations.filter((item) => item.countryCode === wizard.country && isMappableTimezone(item));
    const fallback = mergedLocations.filter((item) => isMappableTimezone(item));
    const merged = [...preferred, ...fallback];
    const seen = new Set();
    const next = [];
    for (const item of merged) {
      if (seen.has(item.timezone)) continue;
      seen.add(item.timezone);
      next.push(item);
      if (next.length >= 16) break;
    }
    return next;
  }, [mergedLocations, wizard.country]);

  const timezoneGroups = useMemo(
    () => Array.from(new Set(mergedLocations.map((item) => item.group))),
    [mergedLocations],
  );

  const manualMatch = useMemo(() => {
    const normalized = query.trim();
    if (!normalized) return null;
    return mergedLocations.find((item) => item.timezone === normalized) || null;
  }, [mergedLocations, query]);

  function applyLocation(location) {
    onChange(resolveSelectionPatch(location));
    setQuery(location?.timezone || '');
  }

  return (
    <div className="grid h-full min-h-0 gap-5 overflow-hidden lg:grid-cols-[2.55fr_0.62fr]">
      <div className="flex h-full min-h-0 w-full flex-1 flex-col">
        <TimezoneMap
          locations={mappableLocations}
          selectedLocation={selectedLocation}
          value={wizard.timeZone}
          onChange={({ location }) => applyLocation(location)}
        />
      </div>

      <div className="flex min-h-0 flex-col gap-3">
        <TimezoneSelector
          query={query}
          onQueryChange={setQuery}
          selectedTimezone={wizard.timeZone}
          selectedLocation={selectedLocation}
          quickRegions={quickRegions}
          filtered={filtered}
          loading={loading}
          error={error}
          groupCount={timezoneGroups.length}
          onPick={applyLocation}
          onPickUtc={() => applyLocation(decorateTimezoneLocation({
            timezone: 'Etc/UTC',
            label: 'UTC',
            group: 'UTC',
            latitude: 0,
            longitude: 0,
            countryCode: '',
          }))}
          manualMatch={manualMatch}
        />
        <FieldError message={fieldErrors.timeZone} />
      </div>
    </div>
  );
}
