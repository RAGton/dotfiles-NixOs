function normalizeStringValue(value) {
  return String(value || '').trim();
}

export function normalizeLocaleDisplayValue(value) {
  const raw = normalizeStringValue(value);
  if (!raw) return '';

  const [basePart, encodingPart] = raw.split('.', 2);
  const normalizedBase = basePart
    .replace(/-/g, '_')
    .split('_')
    .filter(Boolean)
    .map((part, index) => (index === 0 ? part.toLowerCase() : part.toUpperCase()))
    .join('_');

  if (!normalizedBase) {
    return '';
  }

  if (!encodingPart) {
    return normalizedBase;
  }

  const normalizedEncoding = /^utf-?8$/i.test(encodingPart)
    ? 'UTF-8'
    : encodingPart.toUpperCase();

  return `${normalizedBase}.${normalizedEncoding}`;
}

export function normalizeLocaleCanonicalKey(value) {
  const normalized = normalizeLocaleDisplayValue(value);
  if (!normalized) return '';

  return normalized.replace(/\.UTF-8$/i, '').toLowerCase();
}

export function normalizeCountryDisplayValue(value) {
  const raw = normalizeStringValue(value);
  if (!raw) return '';

  const localeKey = normalizeLocaleCanonicalKey(raw);
  if (localeKey.includes('_')) {
    const [, regionPart] = localeKey.split('_', 2);
    return String(regionPart || '').slice(0, 2).toUpperCase();
  }

  return raw.toUpperCase();
}

export function normalizeCountryCanonicalKey(value) {
  const normalized = normalizeCountryDisplayValue(value);
  return /^[A-Z]{2}$/.test(normalized) ? normalized : '';
}

export function normalizeKeymapDisplayValue(value) {
  const raw = normalizeStringValue(value);
  if (!raw) return '';

  return raw
    .toLowerCase()
    .replace(/[\s_]+/g, '-')
    .replace(/-+/g, '-');
}

export function normalizeKeymapCanonicalKey(value) {
  return normalizeKeymapDisplayValue(value);
}

function createCanonicalMap(items, { normalizeDisplayValue, toCanonicalKey }) {
  const map = new Map();

  for (const item of Array.isArray(items) ? items : []) {
    const key = toCanonicalKey(item);
    if (!key || map.has(key)) {
      continue;
    }

    const displayValue = normalizeDisplayValue(item);
    if (!displayValue) {
      continue;
    }

    map.set(key, displayValue);
  }

  return map;
}

export function mergeCanonicalCatalog(apiItems, fallbackItems, options) {
  const fallbackMap = createCanonicalMap(fallbackItems, options);
  const apiMap = createCanonicalMap(apiItems, options);
  const mergedMap = new Map(fallbackMap);

  for (const [key, displayValue] of apiMap.entries()) {
    if (!mergedMap.has(key)) {
      mergedMap.set(key, displayValue);
    }
  }

  return {
    items: Array.from(mergedMap.values()),
    usedFallback: mergedMap.size > apiMap.size,
  };
}

export async function fetchCanonicalCatalog(loader, fallbackItems, options) {
  try {
    const payload = await loader();
    const apiItems = Array.isArray(payload?.items) ? payload.items : [];
    return mergeCanonicalCatalog(apiItems, fallbackItems, options);
  } catch {
    return mergeCanonicalCatalog([], fallbackItems, options);
  }
}
