export class InstallerApiError extends Error {
  constructor(message, details = {}) {
    super(message);
    this.name = 'InstallerApiError';
    this.status = details.status ?? null;
    this.body = details.body;
  }
}

async function parseResponseBody(response) {
  const raw = await response.text();
  if (!raw) {
    return null;
  }

  try {
    return JSON.parse(raw);
  } catch {
    return raw;
  }
}

function resolveApiErrorMessage(body, fallbackMessage) {
  if (typeof body === 'string' && body.trim()) {
    return body;
  }
  if (body && typeof body === 'object' && typeof body.error === 'string' && body.error.trim()) {
    return body.error;
  }
  return fallbackMessage;
}

async function requestJson(path, options = {}) {
  const response = await fetch(path, {
    cache: 'no-store',
    ...options,
  });
  const body = await parseResponseBody(response);

  if (!response.ok) {
    throw new InstallerApiError(
      resolveApiErrorMessage(body, `Falha ao acessar ${path}.`),
      {
        status: response.status,
        body,
      },
    );
  }

  return body;
}

export const installerApi = {
  getCountries() {
    return requestJson('/api/v1/countries');
  },
  getLocales() {
    return requestJson('/api/v1/locales');
  },
  getKeymaps() {
    return requestJson('/api/v1/keymaps');
  },
  getTimezones() {
    return requestJson('/api/v1/timezones');
  },
  getTimezoneLocations() {
    return requestJson('/api/v1/timezone-locations');
  },
  getNetworkInterfaces() {
    return requestJson('/api/v1/netifs');
  },
  getDisks() {
    return requestJson('/api/v1/disks');
  },
  getDiskLayout(disk) {
    return requestJson(`/api/v1/disk-layout?disk=${encodeURIComponent(disk)}`);
  },
  savePlan(plan, secrets) {
    return requestJson('/api/v1/plan', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ plan, secrets }),
    });
  },
  startInstall(confirmWipe) {
    return requestJson('/api/v1/install', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ confirmWipe }),
    });
  },
  getStatus() {
    return requestJson('/api/v1/status');
  },
  getLog() {
    return requestJson('/api/v1/log');
  },
  reboot() {
    return requestJson('/api/v1/reboot', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({}),
    });
  },
  openInstallLogStream(handlers = {}) {
    const eventSource = new EventSource('/api/v1/install-log');

    eventSource.addEventListener('log', (event) => {
      handlers.onLog?.(event.data || '');
    });

    eventSource.addEventListener('status', (event) => {
      try {
        handlers.onStatus?.(JSON.parse(event.data));
      } catch {
        handlers.onStatusParseError?.(event.data);
      }
    });

    eventSource.addEventListener('done', (event) => {
      handlers.onDone?.(Number(event.data || '1'));
    });

    eventSource.onerror = () => {
      handlers.onError?.();
    };

    return () => {
      eventSource.close();
    };
  },
};

export function getInstallerApiErrorMessage(error, fallbackMessage = 'Falha ao comunicar com o backend do instalador.') {
  if (error instanceof InstallerApiError) {
    return error.message;
  }
  if (error instanceof Error && error.message) {
    return error.message;
  }
  return fallbackMessage;
}
