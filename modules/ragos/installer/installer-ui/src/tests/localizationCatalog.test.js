import test from 'node:test';
import assert from 'node:assert/strict';
import {
  fetchCanonicalCatalog,
  mergeCanonicalCatalog,
  normalizeCountryCanonicalKey,
  normalizeCountryDisplayValue,
  normalizeKeymapCanonicalKey,
  normalizeKeymapDisplayValue,
  normalizeLocaleCanonicalKey,
  normalizeLocaleDisplayValue,
} from '../utils/localizationCatalog.js';

test('merge de countries preserva catálogo interno e deduplica aliases previsíveis', () => {
  const merged = mergeCanonicalCatalog(
    ['br', 'US', 'pt_BR.UTF-8'],
    ['BR', 'PT', 'US'],
    {
      normalizeDisplayValue: normalizeCountryDisplayValue,
      toCanonicalKey: normalizeCountryCanonicalKey,
    },
  );

  assert.deepEqual(merged.items, ['BR', 'PT', 'US']);
  assert.equal(merged.usedFallback, true);
});

test('merge de keymaps deduplica case e separadores preservando fallback amigável', () => {
  const merged = mergeCanonicalCatalog(
    ['US', 'br_abnt2', 'pt latin1'],
    ['us', 'br-abnt2', 'pt-latin1'],
    {
      normalizeDisplayValue: normalizeKeymapDisplayValue,
      toCanonicalKey: normalizeKeymapCanonicalKey,
    },
  );

  assert.deepEqual(merged.items, ['us', 'br-abnt2', 'pt-latin1']);
  assert.equal(merged.usedFallback, false);
});

test('merge de locales colapsa utf8 e underscore/hífen preservando forma canônica interna', () => {
  const merged = mergeCanonicalCatalog(
    ['en_US.utf8', 'pt-BR.UTF8', 'fr_FR'],
    ['en_US.UTF-8', 'pt_BR.UTF-8', 'fr_FR.UTF-8'],
    {
      normalizeDisplayValue: normalizeLocaleDisplayValue,
      toCanonicalKey: normalizeLocaleCanonicalKey,
    },
  );

  assert.deepEqual(merged.items, ['en_US.UTF-8', 'pt_BR.UTF-8', 'fr_FR.UTF-8']);
  assert.equal(merged.usedFallback, false);
});

test('fetchCanonicalCatalog entra em degraded mode quando a API precisa ser complementada', async () => {
  const result = await fetchCanonicalCatalog(
    async () => ({ items: ['en_US.utf8'] }),
    ['en_US.UTF-8', 'pt_BR.UTF-8'],
    {
      normalizeDisplayValue: normalizeLocaleDisplayValue,
      toCanonicalKey: normalizeLocaleCanonicalKey,
    },
  );

  assert.deepEqual(result.items, ['en_US.UTF-8', 'pt_BR.UTF-8']);
  assert.equal(result.usedFallback, true);
});

test('fetchCanonicalCatalog usa só o fallback quando a API falha', async () => {
  const result = await fetchCanonicalCatalog(
    async () => {
      throw new Error('offline');
    },
    ['us', 'br-abnt2'],
    {
      normalizeDisplayValue: normalizeKeymapDisplayValue,
      toCanonicalKey: normalizeKeymapCanonicalKey,
    },
  );

  assert.deepEqual(result.items, ['us', 'br-abnt2']);
  assert.equal(result.usedFallback, true);
});
