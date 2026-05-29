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
  getCountries() { return Promise.resolve([{ id: 'BR', name: 'Brasil' }]); },
  getLocales() { return Promise.resolve([{ id: 'pt_BR.UTF-8', name: 'Portugues (Brasil)' }]); },
  getKeymaps() { return Promise.resolve([{ id: 'br-abnt2', name: 'Portugues (ABNT2)' }]); },
  getTimezones() { return Promise.resolve(['America/Cuiaba', 'America/Sao_Paulo']); },
  getTimezoneLocations() { return Promise.resolve({}); },
  getNetworkInterfaces() { return Promise.resolve(['eth0', 'enp1s0']); },
  
  getDisks() {
    return requestJson('/api/disks').then(disks => disks.map(d => ({
      name: d.name,
      model: d.model,
      size: d.size,
      logical_size: d.size,
      type: d.type_
    })));
  },
  
  getDiskLayout(disk) { return Promise.resolve({}); },
  
  savePlan(plan, secrets) {
    window.__kryonix_plan = {
      locale: plan.locale.locale,
      keyboard: plan.locale.keymap,
      network: {
        server_ip: plan.network.serverIp,
        gateway: plan.network.gateway,
        dns: plan.network.dns,
        interface: plan.network.interface,
      },
      user: {
        username: plan.admin.user,
        group: "wheel",
      }
    };
    
    // Also trigger partitioning as Kryonix requires partition step
    return requestJson('/api/partition', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ disk: plan.disk.sysDisk }),
    });
  },
  
  startInstall(confirmWipe) {
    const payload = window.__kryonix_plan || {
      locale: "pt_BR.UTF-8",
      keyboard: "br-abnt2",
      network: { server_ip: "10.0.0.2", gateway: "10.0.0.1", dns: ["8.8.8.8"], interface: "eth0" },
      user: { username: "admin", group: "wheel" }
    };
    return requestJson('/api/install', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(payload),
    });
  },
  
  getStatus() { return Promise.resolve({ running: window.__kryonix_running || false, exitCode: null, currentPhase: null }); },
  getLog() { return Promise.resolve({ tail: '' }); },
  reboot() { return Promise.resolve({}); },
  
  openInstallLogStream(handlers = {}) {
    window.__kryonix_running = true;
    const eventSource = new EventSource('/api/stream');

    eventSource.onmessage = (event) => {
      handlers.onLog?.(event.data + '\n');
      if (event.data.includes('Installation complete') || event.data.includes('FAILED')) {
        window.__kryonix_running = false;
        handlers.onDone?.(event.data.includes('FAILED') ? 1 : 0);
        eventSource.close();
      }
    };

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
