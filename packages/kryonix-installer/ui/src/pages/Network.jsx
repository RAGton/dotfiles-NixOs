import { useEffect, useState } from 'react';
import FieldError from '../components/FieldError.jsx';
import { installerApi, getInstallerApiErrorMessage } from '../utils/installerApi.js';

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
  const fieldErrors = validation?.fieldErrors || {};
  const warnings = validation?.warnings || [];
  const wanEnabled = Boolean(wizard.wanInterface);
  const sameNicSelected = wizard.mgmtInterface && wizard.wanInterface && wizard.mgmtInterface === wizard.wanInterface;

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setLoading(true);
        setError('');
        const payload = await installerApi.getNetworkInterfaces();
        const next = Array.isArray(payload.interfaces) ? payload.interfaces : [];

        if (!cancelled) {
          setInterfaces(next);
          const nextPatch = { netIfacesCount: next.length };

          if (!wizard.mgmtInterface || !next.includes(wizard.mgmtInterface)) {
            nextPatch.mgmtInterface = next[0] || '';
          }

          if (wizard.wanInterface && !next.includes(wizard.wanInterface)) {
            nextPatch.wanInterface = '';
            nextPatch.wanMode = 'dhcp';
            nextPatch.wanAddress = '';
            nextPatch.wanGateway = '';
            nextPatch.wanDns = '';
            nextPatch.pppoeUser = '';
            nextPatch.pppoePassword = '';
            nextPatch.wanIdentified = false;
          }

          if (Object.keys(nextPatch).length > 0) {
            onChange(nextPatch);
          }
        }
      } catch (nextError) {
        if (!cancelled) {
          setError(getInstallerApiErrorMessage(nextError, 'Falha ao carregar interfaces.'));
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [onChange, wizard.mgmtInterface, wizard.wanInterface]);

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
            <h3 className="text-xl font-bold text-white">Rede do servidor</h3>
            <p className="mt-1 text-sm text-slate-400">Somente campos que entram no contrato real entre React, backend, shell e `params.nix`.</p>
          </div>
          <button type="button" className="btn-secondary !px-3 !py-2" onClick={() => setShowHelp((previous) => !previous)}>
            {showHelp ? 'Ocultar ajuda' : 'Ajuda tecnica'}
          </button>
        </div>

        {showHelp ? <HelpBlock /> : null}

        <div className="mt-4 space-y-4">
          <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
            <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Servidor / LAN-PXE</div>
            <div className="mt-3 grid gap-4 sm:grid-cols-2">
              <div>
                <label className="label-text" htmlFor="hostName">Hostname</label>
                <input id="hostName" className="input-shell" value={wizard.hostName} onChange={(event) => onChange({ hostName: event.target.value })} />
                <FieldError message={fieldErrors.hostName} />
              </div>
              <div>
                <label className="label-text" htmlFor="serverIp">IP do servidor</label>
                <input id="serverIp" className="input-shell" value={wizard.serverIp} onChange={handleIpv4Change('serverIp')} inputMode="numeric" />
                <FieldError message={fieldErrors.serverIp} />
              </div>
              <div>
                <label className="label-text" htmlFor="mgmtInterface">Interface LAN/PXE</label>
                <select
                  id="mgmtInterface"
                  className="input-shell"
                  value={wizard.mgmtInterface}
                  onChange={(event) => onChange({ mgmtInterface: event.target.value, lanIdentified: false })}
                >
                  <option value="">Selecione uma interface</option>
                  {interfaces.map((item) => (
                    <option key={item} value={item}>{item}</option>
                  ))}
                </select>
                <FieldError message={fieldErrors.mgmtInterface} />
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
              Confirmei fisicamente a interface LAN/PXE ({wizard.mgmtInterface || 'nao selecionada'}).
            </label>
          </div>

          <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
            <div className="flex items-start justify-between gap-4">
              <div>
                <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">WAN opcional</div>
                <p className="mt-2 text-sm text-slate-400">Preencha apenas se houver uma segunda interface dedicada para uplink, NAT ou PPPoE.</p>
              </div>
              <div className={`metric-chip ${wanEnabled ? 'text-emerald-300' : 'text-slate-400'}`}>
                {wanEnabled ? wizard.wanInterface : 'Sem WAN'}
              </div>
            </div>

            <div className="mt-4">
              <label className="label-text" htmlFor="wanInterface">Interface WAN</label>
              <select id="wanInterface" className="input-shell" value={wizard.wanInterface} onChange={(event) => handleWanInterfaceChange(event.target.value)}>
                <option value="">Sem uplink dedicado</option>
                {interfaces
                  .filter((item) => item !== wizard.mgmtInterface)
                  .map((item) => (
                    <option key={item} value={item}>{item}</option>
                  ))}
              </select>
              <FieldError message={fieldErrors.wanInterface} />
            </div>

            {wanEnabled ? (
              <>
                <div className="mt-4 grid gap-2 sm:grid-cols-3">
                  <button type="button" className={wizard.wanMode === 'dhcp' ? 'btn-primary' : 'btn-secondary'} onClick={() => onChange({ wanMode: 'dhcp' })}>
                    DHCP
                  </button>
                  <button type="button" className={wizard.wanMode === 'static' ? 'btn-primary' : 'btn-secondary'} onClick={() => onChange({ wanMode: 'static' })}>
                    IP estatico
                  </button>
                  <button type="button" className={wizard.wanMode === 'pppoe' ? 'btn-primary' : 'btn-secondary'} onClick={() => onChange({ wanMode: 'pppoe' })}>
                    PPPoE
                  </button>
                </div>

                {wizard.wanMode === 'static' ? (
                  <div className="mt-4 grid gap-4 sm:grid-cols-2">
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
                  <div className="mt-4 grid gap-4 sm:grid-cols-2">
                    <div>
                      <label className="label-text" htmlFor="pppoeUser">Usuario PPPoE</label>
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
                          {showPppoePassword ? 'Ocultar' : 'Mostrar'}
                        </button>
                      </div>
                      <FieldError message={fieldErrors.pppoePassword} />
                    </div>
                  </div>
                ) : null}

                <label className="mt-4 flex items-center gap-2 rounded-xl border border-white/10 bg-slate-950/60 px-3 py-2.5 text-sm text-slate-200">
                  <input
                    type="checkbox"
                    className="h-4 w-4 rounded"
                    checked={Boolean(wizard.wanIdentified)}
                    onChange={(event) => onChange({ wanIdentified: event.target.checked })}
                  />
                  Confirmei fisicamente a interface WAN ({wizard.wanInterface || 'nao selecionada'}).
                </label>
              </>
            ) : (
              <div className="mt-4 rounded-2xl border border-emerald-400/20 bg-emerald-400/10 p-3 text-sm text-emerald-100">
                Sem WAN dedicada: o servidor usara apenas a interface LAN/PXE e o gateway informado na configuracao principal.
              </div>
            )}
          </div>
        </div>
      </section>

      <section className="section-panel min-h-0 overflow-y-auto p-4">
        <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Resumo operacional</div>
        <div className="mt-4 space-y-3">
          <SummaryRow label="Interfaces detectadas" value={loading ? 'carregando' : String(interfaces.length)} />
          <SummaryRow label="LAN/PXE" value={wizard.mgmtInterface || 'pendente'} />
          <SummaryRow label="IP LAN/PXE" value={wizard.serverIp || 'pendente'} />
          <SummaryRow label="Gateway" value={wizard.mgmtGateway || 'pendente'} />
          <SummaryRow label="DNS" value={wizard.mgmtDns || 'pendente'} />
          <SummaryRow label="WAN" value={wanEnabled ? `${wizard.wanInterface} (${wizard.wanMode})` : 'desabilitada'} />
          <SummaryRow label="Porta HTTP" value={String(wizard.httpPort || 0)} />
        </div>

        {sameNicSelected ? (
          <div className="mt-4 rounded-2xl border border-rose-400/25 bg-rose-400/10 p-3 text-sm text-rose-200">
            LAN/PXE e WAN nao podem usar a mesma placa de rede.
          </div>
        ) : null}

        {error ? (
          <div className="mt-4 rounded-2xl border border-rose-400/25 bg-rose-400/10 p-3 text-sm text-rose-200">
            {error}
          </div>
        ) : null}

        {warnings.length > 0 ? (
          <div className="mt-4 rounded-2xl border border-amber-400/20 bg-amber-400/10 p-4 text-sm text-amber-100">
            <div className="font-semibold text-amber-50">Avisos</div>
            <ul className="mt-2 space-y-1">
              {warnings.map((warning) => <li key={warning}>- {warning}</li>)}
            </ul>
          </div>
        ) : null}

        <div className="mt-4 rounded-2xl border border-white/10 bg-white/[0.03] p-4 text-sm text-slate-300">
          <div className="font-semibold text-white">Automatico x manual</div>
          <ul className="mt-3 space-y-2 text-slate-400">
            <li>- Automatico: somente a lista de interfaces vem do backend e a primeira LAN/PXE pode ser sugerida.</li>
            <li>- Manual: IP, mascara, gateway, DNS, porta HTTP e qualquer uplink WAN continuam sendo revisados por voce.</li>
            <li>- Se a WAN ficar vazia, nenhum uplink extra sera enviado ao backend.</li>
          </ul>
        </div>
      </section>
    </div>
  );
}
