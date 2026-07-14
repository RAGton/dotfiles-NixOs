// Regras de endurecimento compartilhadas pelo instalador.
// A ideia é bloquear entradas perigosas cedo, antes de qualquer ida ao backend.

export const SHELL_META_CHARS = /[;&|$`<>\\!]/g;
export const LINUX_USERNAME_RE = /^[a-z_][a-z0-9_-]*$/;
export const RFC1123_HOSTNAME_RE = /^(?=.{1,63}$)[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/;
export const IPV4_RE = /^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$/;
export const IPV6_RE = /^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|::1|::)$/;

export function sanitizeShellInput(value) {
  return String(value ?? '').replace(SHELL_META_CHARS, '');
}

export function sanitizePatch(patch) {
  if (!patch || typeof patch !== 'object' || Array.isArray(patch)) {
    return patch;
  }

  const next = {};
  for (const [key, value] of Object.entries(patch)) {
    if (typeof value === 'string') {
      next[key] = sanitizeShellInput(value);
    } else {
      next[key] = value;
    }
  }
  return next;
}

export function digitsOnly(value) {
  return String(value ?? '').replace(/\D+/g, '');
}

export function ipCharsOnly(value) {
  return sanitizeShellInput(String(value ?? '')).replace(/[^0-9a-fA-F:.,/]/g, '');
}

export function isValidLinuxUsername(value) {
  return LINUX_USERNAME_RE.test(String(value ?? '').trim());
}

export function isValidHostname(value) {
  return RFC1123_HOSTNAME_RE.test(String(value ?? '').trim());
}

export function isValidIpv4(value) {
  return IPV4_RE.test(String(value ?? '').trim());
}

export function isValidIpv6(value) {
  return IPV6_RE.test(String(value ?? '').trim());
}

export function isValidIpAddress(value) {
  const candidate = String(value ?? '').trim();
  return isValidIpv4(candidate) || isValidIpv6(candidate);
}

export function parseJsonSafe(raw, fallback = null) {
  try {
    return JSON.parse(raw);
  } catch {
    return fallback;
  }
}

export async function fetchJsonSafe(url, options = {}, fallbackMessage = 'Erro ao carregar dados.') {
  const response = await fetch(url, options);
  const raw = await response.text();
  const data = parseJsonSafe(raw, null);

  if (!response.ok) {
    const message = typeof data === 'string' ? data : fallbackMessage;
    throw new Error(message);
  }

  if (data === null) {
    throw new Error(fallbackMessage);
  }

  return data;
}
