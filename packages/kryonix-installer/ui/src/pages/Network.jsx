import { useCallback, useEffect, useState } from 'react';
import FieldError from '../components/FieldError.jsx';
import { installerApi, getInstallerApiErrorMessage } from '../utils/installerApi.js';

function sanitizeIp(value) {
  return String(value || '').split('/')[0].trim();
}

function isUsableRemoteIp(value) {
  const ip = sanitizeIp(value);
  if (!ip) return false;
  if (ip === '0.0.0.0') return false;
  if (ip.startsWith('127.')) return false;
  if (ip.startsWith('169.254.')) return false;
  return /^\d{1,3}(\.\d{1,3}){3}$/.test(ip);
}

function formatIpv4Input(nextValue, previousValue = '') {
  const raw = String(nextValue || '');
  const previous = String(previousValue || '');
  const isDeleting = raw.length < previous.length;
  const cleaned = raw.replace(/[^\d.]/g, '');

  const parts = cleaned
    .split('.')
    .slice(0, 4)
    .map((part) => part.replace(/\D/g, '').slice(0, 3));

  let formatted = parts
    .filter((part, index) => part !== '' || index < parts.length - 1)
    .join('.');

  if (!isDeleting) {
    const visibleParts = formatted.split('.');
    const lastPart = visibleParts[visibleParts.length - 1] || '';
    const endedWithDot = cleaned.endsWith('.');

    if (endedWithDot && visibleParts.length < 4 && !formatted.endsWith('.')) {
      formatted += '.';
    } else if (!cleaned.includes('.') && lastPart.length === 3 && visibleParts.length < 4) {
      formatted += '.';
    } else if (cleaned.includes('.') && lastPart.length === 3 && visibleParts.length < 4 && !formatted.endsWith('.')) {
      formatted += '.';
    }
  }

  return formatted;
}

function HelpBlock() {
  return (
    <div className="rounded-2xl border border-cyan-400/20 bg-cyan-400/10 p-4 text-sm text-cyan-50">
      <div className="text-xs font-semibold uppercase tracking-[0.22em] text-cyan-200">Ajuda tecnica</div>
      <div className="mt-3 space-y-3 text-cyan-100">
        <p><b className="text-white">IP do servidor</b>: endereco IPv4 fixo do Kryonix na interface LAN/PXE. E esse IP que o backend grava em `network.serverIp`.</p>
        <p><b className="text-white">Gateway</b>: rota padrao usada pelo servidor. Se nao houver WAN dedicada, o gateway continua sendo o da LAN configurada.</p>
        <p><b className="text-white">DNS</b>: lista de resolvedores IPv4. Valores errados quebram update, fetch do repositorio e resolucao de nomes depois da instalacao.</p>
        <p><b className="text-white">Interface</b>: nome da placa detectada pelo backend. O preenchimento automatico so sugere a primeira interface valida para LAN/PXE; IP, gateway, DNS e porta HTTP continuam revisados manualmente.</p>
        <p><b className="text-white">WAN opcional</b>: use apenas quando existir uma segunda interface dedicada para uplink, NAT ou PPPoE. Deixar vazio nao desabilita a instalacao.</p>
        <p><b className="text-white">Consequencias de erro</b>: interface trocada, gateway incorreto ou DNS invalido podem deixar o servidor sem acesso remoto, sem internet ou sem entregar PXE corretamente.</p>
        <p><b className="text-white">Exemplo simples</b>: `enp1s0` -&gt; `192.168.100.2/24`, gateway `192.168.100.1`, DNS `1.1.1.1,8.8.8.8`, sem WAN dedicada.</p>
        <p><b className="text-white">Exemplo laboratorio</b>: `enp1s0` -&gt; LAN/PXE `192.168.100.2/24`; `enp2s0` -&gt; WAN por DHCP ou PPPoE quando o servidor tambem faz saida para a internet.</p>
      </div>
    </div>
  );
}

function SummaryRow({ label, value }) {
  return (
    <div className="flex items-center justify-between gap-3 rounded-xl border border-white/10 bg-white/[0.03] px-3 py-2 text-sm text-slate-300">
      <span className="text-slate-400">{label}</span>
      <span className="font-semibold text-white">{value}</span>
    </div>
  );
}

export default function Network({ wizard, onChange, validation }) {
  const [interfaces, setInterfaces] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showHelp, setShowHelp] = useState(false);
  const [showPppoePassword, setShowPppoePassword] = useState(false);
  const [showWanAdvanced, setShowWanAdvanced] = useState(false);

  // Conectividade (Wi-Fi + status). 
  // SECURITY: Senha só em estado local — nunca persistida no wizardState/localStorage.
  const [netStatus, setNetStatus] = useState(null);
  const [wifiList, setWifiList] = useState([]);
  const [wifiScanning, setWifiScanning] = useState(false);
  const [selectedWifiIface, setSelectedWifiIface] = useState('');
  const [wifiSsid, setWifiSsid] = useState('');
  const [wifiPassword, setWifiPassword] = useState('');
  const [showWifiPassword, setShowWifiPassword] = useState(false);
  const [connecting, setConnecting] = useState(false);
  const [connectMsg, setConnectMsg] = useState('');

  const fieldErrors = validation?.fieldErrors || {};
  const warnings = validation?.warnings || [];
  
  const ifaceNames = interfaces.map((i) => i.name).filter(Boolean);
  const ethIfaces = interfaces.filter((i) => i.type === 'ethernet');
  const wifiIfaces = interfaces.filter((i) => i.type === 'wifi');
  const otherIfaces = interfaces.filter((i) => i.type !== 'ethernet' && i.type !== 'wifi');
  
  const hasWifi = wifiIfaces.length > 0;
  const wanEnabled = Boolean(wizard.wanInterface);
  const sameNicSelected = wizard.mgmtInterface && wizard.wanInterface && wizard.mgmtInterface === wizard.wanInterface;

  const refreshStatus = useCallback(async () => {
    try { 
      const status = await installerApi.getNetworkStatus();
      setNetStatus(status);
      if (status.connected) {
        onChange({ netConnected: true, netOffline: false });
        // Propagar IP detectado via DHCP para wizard.serverIp
        if (status.ip && isUsableRemoteIp(status.ip)) {
          onChange({ serverIp: sanitizeIp(status.ip) });
        }
      } else {
        onChange({ netConnected: false });
      }
    } catch { /* ignora */ }
  }, [onChange]);

  const loadInterfaces = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const payload = await installerApi.getNetworkInterfaces();
      const list = Array.isArray(payload?.interfaces) ? payload.interfaces : [];
      setInterfaces(list);
      
      const wifi = list.find(i => i.type === 'wifi');
      if (wifi && !selectedWifiIface) {
        setSelectedWifiIface(wifi.name);
      }

      const names = list.map((i) => i.name).filter(Boolean);
      const patch = { netIfacesCount: names.length };
      if (!wizard.mgmtInterface || !names.includes(wizard.mgmtInterface)) {
        patch.mgmtInterface = names[0] || '';
      }
      onChange(patch);
    } catch (nextError) {
      setError(getInstallerApiErrorMessage(nextError, 'Falha ao carregar interfaces.'));
    } finally {
      setLoading(false);
    }
  }, [onChange, wizard.mgmtInterface, selectedWifiIface]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      await loadInterfaces();
      if (!cancelled) await refreshStatus();
    })();
    return () => { cancelled = true; };
  }, [loadInterfaces, refreshStatus]);

  const scanWifi = useCallback(async () => {
    if (!selectedWifiIface) return;
    setWifiScanning(true);
    setConnectMsg('');
    try {
      const response = await installerApi.scanWifi(selectedWifiIface);
      setWifiList(Array.isArray(response?.networks) ? response.networks : []);
      if (response?.warning) {
        setConnectMsg(response.warning);
      }
    } catch (nextError) {
      setConnectMsg(getInstallerApiErrorMessage(nextError, 'Falha ao escanear redes Wi-Fi.'));
    } finally {
      setWifiScanning(false);
    }
  }, [selectedWifiIface]);

  const connectWifi = useCallback(async () => {
    if (!selectedWifiIface || !wifiSsid) return;
    setConnecting(true);
    setConnectMsg('');
    try {
      const result = await installerApi.connectWifi(selectedWifiIface, wifiSsid, wifiPassword);
      setConnectMsg(result?.message || 'Conectado.');
      
      // SECURITY: limpa a senha da memória local após a tentativa
      setWifiPassword(''); 
      
      await refreshStatus();
    } catch (nextError) {
      setConnectMsg(getInstallerApiErrorMessage(nextError, 'Falha ao conectar.'));
    } finally {
      setConnecting(false);
    }
  }, [selectedWifiIface, wifiSsid, wifiPassword, refreshStatus]);

  const continueOffline = () => {
    // SECURITY: Limpa qualquer dado sensível local
    setWifiSsid('');
    setWifiPassword('');
    onChange({ netOffline: true, netConnected: false });
  };

  const handleIpv4Change = (field) => (event) => {
    onChange({
      [field]: formatIpv4Input(event.target.value, wizard[field]),
    });
  };

  function handleWanInterfaceChange(nextValue) {
    if (!nextValue) {
      onChange({
        wanInterface: '',
        wanMode: 'dhcp',
        wanAddress: '',
        wanGateway: '',
        wanDns: '',
        pppoeUser: '',
        pppoePassword: '',
        wanIdentified: false,
      });
      return;
    }

    onChange({
      wanInterface: nextValue,
      wanIdentified: false,
    });
  }

  return (
    <div className="grid h-full min-h-0 gap-4 lg:grid-cols-[1.08fr_0.92fr]">
      <section className="section-panel min-h-0 overflow-y-auto p-4">
        <div className="mb-4 flex items-start justify-between gap-4">
          <div>
            <h3 className="text-xl font-bold text-white">Conectividade e Redes</h3>
            <p className="mt-1 text-sm text-slate-400">Configure o acesso à internet para o instalador e os parâmetros de rede do servidor.</p>
          </div>
          <button type="button" className="btn-secondary !px-3 !py-2" onClick={() => setShowHelp((previous) => !previous)}>
            {showHelp ? 'Ocultar ajuda' : 'Ajuda técnica'}
          </button>
        </div>

        {showHelp ? <HelpBlock /> : null}

        {/* ── Conectividade Live ─────────────────────────────────────────── */}
        <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-4 mt-4">
          <div className="flex items-center justify-between gap-3">
            <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Status do Instalador</div>
            <div className="flex gap-2">
               <button type="button" className="btn-secondary !px-2 !py-1 text-xs" onClick={loadInterfaces} disabled={loading}>
                 {loading ? '↻' : '↻ Atualizar'}
               </button>
               <span className={`metric-chip ${wizard.netConnected ? 'text-emerald-300' : wizard.netOffline ? 'text-amber-300' : 'text-slate-400'}`}>
                {wizard.netConnected
                  ? `Online${netStatus?.ssid ? ` · ${netStatus.ssid}` : ''}`
                  : wizard.netOffline ? 'Modo Offline' : 'Desconectado'}
              </span>
            </div>
          </div>

          {/* Listagem de Interfaces Ethernet */}
          <div className="mt-4">
            <div className="text-sm font-semibold text-white mb-2">Interfaces Ethernet</div>
            <div className="grid gap-2 sm:grid-cols-2">
              {ethIfaces.length === 0 ? (
                <div className="text-xs text-slate-500 italic">Nenhuma interface Ethernet detectada.</div>
              ) : (
                ethIfaces.map((it) => (
                  <div key={it.name} className="flex items-center justify-between rounded-xl border border-white/10 bg-slate-950/60 px-3 py-2 text-sm">
                    <span className="text-white">󰈀 {it.name}</span>
                    <span className={it.state === 'connected' ? 'text-emerald-300' : 'text-slate-400'}>{it.state}</span>
                  </div>
                ))
              )}
            </div>
          </div>

          {/* Gestão de Wi-Fi */}
          <div className="mt-6">
            <div className="flex items-center justify-between gap-3 mb-2">
              <div className="text-sm font-semibold text-white">Redes Wi-Fi</div>
              {hasWifi && (
                <div className="flex gap-2">
                  <select 
                    className="bg-slate-900 border border-white/10 text-xs rounded px-2 py-1 text-slate-300"
                    value={selectedWifiIface}
                    onChange={(e) => setSelectedWifiIface(e.target.value)}
                  >
                    {wifiIfaces.map(i => <option key={i.name} value={i.name}>{i.name}</option>)}
                  </select>
                  <button type="button" className="btn-secondary !px-3 !py-1 text-xs" onClick={scanWifi} disabled={wifiScanning || !selectedWifiIface}>
                    {wifiScanning ? 'Buscando…' : 'Buscar redes'}
                  </button>
                </div>
              )}
            </div>

            {!hasWifi ? (
              <div className="rounded-xl border border-white/10 bg-slate-950/60 px-3 py-3 text-sm text-slate-400">
                󰖪 Nenhuma interface Wi-Fi detectada neste hardware.
              </div>
            ) : (
              <div className="space-y-3">
                {wifiList.length > 0 ? (
                  <>
                    <div>
                      <label className="label-text" htmlFor="wifiSsid">Rede Disponível</label>
                      <select id="wifiSsid" className="input-shell" value={wifiSsid} onChange={(e) => setWifiSsid(e.target.value)}>
                        <option value="">Selecione uma rede</option>
                        {wifiList.map((w) => (
                          <option key={w.ssid} value={w.ssid}>
                            {w.ssid} — {w.signal}% {w.security ? `(${w.security})` : '(Aberta)'}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div>
                      <label className="label-text" htmlFor="wifiPassword">Senha</label>
                      <div className="flex gap-2">
                        <input
                          id="wifiPassword"
                          type={showWifiPassword ? 'text' : 'password'}
                          className="input-shell flex-1"
                          value={wifiPassword}
                          autoComplete="off"
                          onChange={(e) => setWifiPassword(e.target.value)}
                          placeholder="Vazio para redes abertas"
                        />
                        <button type="button" className="btn-secondary !px-3 !py-2" onClick={() => setShowWifiPassword((p) => !p)}>
                          {showWifiPassword ? '󰈈' : '󰈉'}
                        </button>
                        <button type="button" className="btn-primary !px-4 !py-2" onClick={connectWifi} disabled={!wifiSsid || connecting}>
                          {connecting ? '...' : 'Conectar'}
                        </button>
                      </div>
                    </div>
                  </>
                ) : (
                  <div className="text-xs text-slate-500 italic">Clique em "Buscar redes" para listar sinais Wi-Fi.</div>
                )}
              </div>
            )}
          </div>

          {connectMsg ? <div className="mt-3 p-2 rounded bg-cyan-950/30 text-xs text-cyan-200 border border-cyan-400/20">{connectMsg}</div> : null}

          <div className="mt-6 pt-4 border-t border-white/5 flex items-center justify-between">
            <button type="button" className={`btn-secondary !px-4 !py-2 ${wizard.netOffline ? 'ring-2 ring-amber-400/50 bg-amber-400/10' : ''}`} onClick={continueOffline}>
              Continuar offline
            </button>
            {wizard.netOffline && (
              <span className="text-[10px] text-amber-300 font-medium uppercase tracking-wider">
                󱧥 Avanço offline liberado
              </span>
            )}
          </div>
          
          {wizard.netOffline && (
            <div className="mt-3 p-3 rounded-xl bg-amber-400/5 border border-amber-400/20 text-xs text-amber-100/80 leading-relaxed">
              <span className="font-bold text-amber-200">Aviso:</span> Modo offline ativado. A instalação dependerá exclusivamente do conteúdo presente na ISO ou em caches locais. Downloads de repositórios externos não serão realizados.
            </div>
          )}
        </div>

        {/* ── Configurações do Target ─────────────────────────────────────── */}
        <div className="mt-8 space-y-4">
          <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
            <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Servidor / LAN-PXE (Target)</div>

            {/* Modo de endereçamento IPv4 da interface LAN/PXE: DHCP (automático)
                ou manual (IP estático). Em DHCP os campos de IP/máscara/gateway/DNS
                são obtidos automaticamente e não são exigidos. */}
            <div className="mt-3 grid gap-2 sm:grid-cols-2">
              <button
                type="button"
                className={wizard.mgmtMode === 'dhcp' ? 'btn-primary' : 'btn-secondary'}
                onClick={() => onChange({ mgmtMode: 'dhcp' })}
              >
                DHCP (IP automático)
              </button>
              <button
                type="button"
                className={wizard.mgmtMode === 'static' ? 'btn-primary' : 'btn-secondary'}
                onClick={() => onChange({ mgmtMode: 'static' })}
              >
                Manual (IP estático)
              </button>
            </div>

            <div className="mt-3 grid gap-4 sm:grid-cols-2">
              <div>
                <label className="label-text" htmlFor="mgmtInterface">Interface LAN/PXE</label>
                <select
                  id="mgmtInterface"
                  className="input-shell"
                  value={wizard.mgmtInterface}
                  onChange={(event) => onChange({ mgmtInterface: event.target.value, lanIdentified: false })}
                >
                  <option value="">Selecione uma interface</option>
                  {ifaceNames.map((item) => (
                    <option key={item} value={item}>{item}</option>
                  ))}
                </select>
                <FieldError message={fieldErrors.mgmtInterface} />
              </div>

              {wizard.mgmtMode === 'static' ? (
                <>
                  <div>
                    <label className="label-text" htmlFor="serverIp">IP do servidor</label>
                    <input id="serverIp" className="input-shell" value={wizard.serverIp} onChange={handleIpv4Change('serverIp')} inputMode="numeric" />
                    <FieldError message={fieldErrors.serverIp} />
                  </div>
                  <div>
                    <label className="label-text" htmlFor="mgmtNetmask">Mascara / prefixo</label>
                    <select id="mgmtNetmask" className="input-shell" value={wizard.mgmtNetmask} onChange={(event) => onChange({ mgmtNetmask: event.target.value })}>
                      <option value="255.255.255.0">255.255.255.0 (/24)</option>
                      <option value="255.255.255.128">255.255.255.128 (/25)</option>
                      <option value="255.255.255.252">255.255.255.252 (/30)</option>
                      <option value="255.255.0.0">255.255.0.0 (/16)</option>
                    </select>
                    <FieldError message={fieldErrors.mgmtNetmask} />
                  </div>
                  <div>
                    <label className="label-text" htmlFor="mgmtGateway">Gateway</label>
                    <input id="mgmtGateway" className="input-shell" value={wizard.mgmtGateway} onChange={handleIpv4Change('mgmtGateway')} inputMode="numeric" />
                    <FieldError message={fieldErrors.mgmtGateway} />
                  </div>
                  <div>
                    <label className="label-text" htmlFor="mgmtDns">DNS</label>
                    <input id="mgmtDns" className="input-shell" value={wizard.mgmtDns} onChange={(event) => onChange({ mgmtDns: event.target.value })} />
                    <FieldError message={fieldErrors.mgmtDns} />
                  </div>
                </>
              ) : (
                <div className="sm:col-span-2 rounded-2xl border border-emerald-400/20 bg-emerald-400/10 p-3 text-sm text-emerald-100">
                  IP, máscara, gateway e DNS serão obtidos automaticamente via DHCP na interface LAN/PXE.
                </div>
              )}

              <div className="sm:col-span-2">
                <label className="label-text" htmlFor="httpPort">Porta HTTP</label>
                <input
                  id="httpPort"
                  type="number"
                  className="input-shell"
                  value={wizard.httpPort}
                  onChange={(event) => onChange({ httpPort: Number(event.target.value || 0) })}
                />
                <FieldError message={fieldErrors.httpPort} />
              </div>
            </div>

            <label className="mt-4 flex items-center gap-2 rounded-xl border border-white/10 bg-slate-950/60 px-3 py-2.5 text-sm text-slate-200">
              <input
                type="checkbox"
                className="h-4 w-4 rounded"
                checked={Boolean(wizard.lanIdentified)}
                onChange={(event) => onChange({ lanIdentified: event.target.checked })}
              />
              Confirmei fisicamente a interface LAN/PXE ({wizard.mgmtInterface || 'não selecionada'}).
            </label>
          </div>

          <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
            <details className="group" onToggle={(e) => setShowWanAdvanced(e.currentTarget.open)} open={showWanAdvanced}>
              <summary className="flex items-center justify-between gap-4 cursor-pointer list-none select-none">
                <div className="flex items-center gap-3">
                  <span className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">WAN opcional</span>
                  <span className={`metric-chip ${wanEnabled ? 'text-emerald-300' : 'text-slate-400'}`}>
                    {wanEnabled ? wizard.wanInterface + ' (' + wizard.wanMode + ')' : 'Sem WAN'}
                  </span>
                </div>
                <svg className="w-5 h-5 text-slate-400 group-open:rotate-180 transition-transform duration-200" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                </svg>
              </summary>

              <div className="mt-4 space-y-4">
                <div className="text-sm text-slate-400">Preencha apenas se houver uma segunda interface dedicada para uplink.</div>

                <div>
                  <label className="label-text" htmlFor="wanInterface">Interface WAN</label>
                  <select id="wanInterface" className="input-shell" value={wizard.wanInterface} onChange={(event) => handleWanInterfaceChange(event.target.value)}>
                    <option value="">Sem uplink dedicado</option>
                    {ifaceNames
                      .filter((item) => item !== wizard.mgmtInterface)
                      .map((item) => (
                        <option key={item} value={item}>{item}</option>
                      ))}
                  </select>
                  <FieldError message={fieldErrors.wanInterface} />
                </div>

                {wanEnabled ? (
                  <>
                    <div className="grid gap-2 sm:grid-cols-3">
                      <button type="button" className={wizard.wanMode === 'dhcp' ? 'btn-primary' : 'btn-secondary'} onClick={() => onChange({ wanMode: 'dhcp' })}>
                        DHCP
                      </button>
                      <button type="button" className={wizard.wanMode === 'static' ? 'btn-primary' : 'btn-secondary'} onClick={() => onChange({ wanMode: 'static' })}>
                        IP estático
                      </button>
                      <button type="button" className={wizard.wanMode === 'pppoe' ? 'btn-primary' : 'btn-secondary'} onClick={() => onChange({ wanMode: 'pppoe' })}>
                        PPPoE
                      </button>
                    </div>

                    {wizard.wanMode === 'static' ? (
                      <div className="grid gap-4 sm:grid-cols-2">
                        <div>
                          <label className="label-text" htmlFor="wanAddress">IP WAN</label>
                          <input id="wanAddress" className="input-shell" value={wizard.wanAddress} onChange={handleIpv4Change('wanAddress')} inputMode="numeric" />
                          <FieldError message={fieldErrors.wanAddress} />
                        </div>
                        <div>
                          <label className="label-text" htmlFor="wanNetmask">Mascara WAN</label>
                          <select id="wanNetmask" className="input-shell" value={wizard.wanNetmask} onChange={(event) => onChange({ wanNetmask: event.target.value })}>
                            <option value="255.255.255.0">255.255.255.0 (/24)</option>
                            <option value="255.255.255.128">255.255.255.128 (/25)</option>
                            <option value="255.255.255.252">255.255.255.252 (/30)</option>
                            <option value="255.255.0.0">255.255.0.0 (/16)</option>
                          </select>
                          <FieldError message={fieldErrors.wanNetmask} />
                        </div>
                        <div>
                          <label className="label-text" htmlFor="wanGateway">Gateway WAN</label>
                          <input id="wanGateway" className="input-shell" value={wizard.wanGateway} onChange={handleIpv4Change('wanGateway')} inputMode="numeric" />
                          <FieldError message={fieldErrors.wanGateway} />
                        </div>
                        <div>
                          <label className="label-text" htmlFor="wanDns">DNS WAN</label>
                          <input id="wanDns" className="input-shell" value={wizard.wanDns} onChange={(event) => onChange({ wanDns: event.target.value })} />
                          <FieldError message={fieldErrors.wanDns} />
                        </div>
                      </div>
                    ) : null}

                    {wizard.wanMode === 'pppoe' ? (
                      <div className="grid gap-4 sm:grid-cols-2">
                        <div>
                          <label className="label-text" htmlFor="pppoeUser">Usuário PPPoE</label>
                          <input id="pppoeUser" className="input-shell" value={wizard.pppoeUser || ''} onChange={(event) => onChange({ pppoeUser: event.target.value })} />
                          <FieldError message={fieldErrors.pppoeUser} />
                        </div>
                        <div>
                          <label className="label-text" htmlFor="pppoePassword">Senha PPPoE</label>
                          <div className="flex gap-2">
                            <input
                              id="pppoePassword"
                              type={showPppoePassword ? 'text' : 'password'}
                              className="input-shell flex-1"
                              value={wizard.pppoePassword || ''}
                              onChange={(event) => onChange({ pppoePassword: event.target.value })}
                            />
                            <button type="button" className="btn-secondary !px-3 !py-2" onClick={() => setShowPppoePassword((previous) => !previous)}>
                              {showPppoePassword ? '󰈈' : '󰈉'}
                            </button>
                          </div>
                          <FieldError message={fieldErrors.pppoePassword} />
                        </div>
                      </div>
                    ) : null}

                    <label className="flex items-center gap-2 rounded-xl border border-white/10 bg-slate-950/60 px-3 py-2.5 text-sm text-slate-200">
                      <input
                        type="checkbox"
                        className="h-4 w-4 rounded"
                        checked={Boolean(wizard.wanIdentified)}
                        onChange={(event) => onChange({ wanIdentified: event.target.checked })}
                      />
                      Confirmei fisicamente a interface WAN ({wizard.wanInterface || 'não selecionada'}).
                    </label>
                  </>
                ) : (
                  <div className="rounded-2xl border border-emerald-400/20 bg-emerald-400/10 p-3 text-sm text-emerald-100">
                    Sem WAN dedicada: o servidor usará apenas a interface LAN/PXE.
                  </div>
                )}
              </div>
            </details>
          </div>
        </div>
      </section>

      <section className="section-panel min-h-0 overflow-y-auto p-4">
        <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Resumo operacional</div>
        <div className="mt-4 space-y-3">
          <SummaryRow label="Interfaces detectadas" value={loading ? 'carregando' : String(interfaces.length)} />
          <SummaryRow label="LAN/PXE" value={wizard.mgmtInterface || 'pendente'} />
          <SummaryRow label="IP LAN/PXE" value={wizard.mgmtMode === 'dhcp' ? 'DHCP (automático)' : (wizard.serverIp || 'pendente')} />
          <SummaryRow label="WAN" value={wanEnabled ? `${wizard.wanInterface} (${wizard.wanMode})` : 'desabilitada'} />
          <SummaryRow label="Status Live" value={wizard.netConnected ? 'Online' : wizard.netOffline ? 'Offline' : 'Desconectado'} />
        </div>

        {sameNicSelected ? (
          <div className="mt-4 rounded-2xl border border-rose-400/25 bg-rose-400/10 p-3 text-sm text-rose-200">
            LAN/PXE e WAN não podem usar a mesma placa de rede.
          </div>
        ) : null}

        {error ? (
          <div className="mt-4 rounded-2xl border border-rose-400/25 bg-rose-400/10 p-3 text-sm text-rose-200">
            {error}
          </div>
        ) : null}

        {warnings.length > 0 ? (
          <div className="mt-4 rounded-2xl border border-amber-400/20 bg-amber-400/10 p-4 text-sm text-amber-100">
            <div className="font-semibold text-amber-50">Avisos de Configuração</div>
            <ul className="mt-2 space-y-1">
              {warnings.map((warning) => <li key={warning}>- {warning}</li>)}
            </ul>
          </div>
        ) : null}

        <div className="mt-6 rounded-2xl border border-white/10 bg-white/[0.03] p-4 text-sm text-slate-300">
          <div className="font-semibold text-white">Requisitos de Avanço</div>
          <ul className="mt-3 space-y-2 text-slate-400">
            <li className={wizard.netConnected || wizard.netOffline ? 'text-emerald-300' : 'text-slate-200'}>
              - {wizard.netConnected ? '󰄬 Conectado à rede' : wizard.netOffline ? '󰄬 Modo offline selecionado' : '󰅙 Conecte-se ou use Modo Offline'}
            </li>
            <li className={wizard.hostName ? 'text-emerald-300' : 'text-slate-400'}>- Hostname definido</li>
            <li className={wizard.mgmtInterface ? 'text-emerald-300' : 'text-slate-400'}>- Interface LAN/PXE selecionada</li>
          </ul>
        </div>
      </section>
    </div>
  );
}
