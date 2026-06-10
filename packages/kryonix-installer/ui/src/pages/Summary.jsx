import { useMemo, useState, useCallback } from 'react';
import { isStrongPassword, buildInstallPlanPayload } from '../utils/installPlan.js';
import { FEATURE_CATALOG } from '../data/featureCatalog.js';
import { getProfileById } from '../data/profileCatalog.js';
import { shouldRecommendSrvData, explainSrvDataReason } from '../utils/storagePlanner.js';

export default function Summary({ wizard, uiState, onChange, validation }) {
  const sshCount = String(wizard.adminAuthorizedKeys || '')
    .split('\n')
    .map((item) => item.trim())
    .filter(Boolean)
    .length;
  const layoutLabel = wizard.diskProfile === 'raid'
    ? `RAID ${String(wizard.raidLevel || '').toUpperCase()}`
    : wizard.diskMode === 'two'
      ? 'split disks'
      : 'single disk';

  const networkSummary = wizard.mgmtMode === 'dhcp'
    ? 'DHCP (automático)'
    : `IP: ${wizard.serverIp || 'pendente'} • GW: ${wizard.mgmtGateway || 'pendente'}`;

  const hasDedicatedData = wizard.diskMode === 'two' || wizard.diskProfile === 'raid';

  const adminPassword = String(wizard.adminPassword || '');
  const adminPasswordConfirm = String(wizard.adminPasswordConfirm || '');
  const passwordFilled = adminPassword.length > 0;
  const passwordStrong = isStrongPassword(adminPassword);
  const passwordMatches = passwordFilled && adminPassword === adminPasswordConfirm;
  const allowWeak = Boolean(wizard.allowWeakPassword);

  const srvDataActive = shouldRecommendSrvData(wizard.profileId, wizard.selectedFeatures);
  const srvDataReason = explainSrvDataReason(wizard.profileId, wizard.selectedFeatures);
  const profileObj = getProfileById(wizard.profileId);

  const { systemFeatures, homeFeatures } = useMemo(() => {
    const sys = [];
    const home = [];
    for (const id of (wizard.selectedFeatures || [])) {
      const f = FEATURE_CATALOG.find(x => x.id === id);
      if (!f) continue;
      if (f.level === 'system') sys.push(f);
      else if (f.level === 'user') home.push(f);
    }
    return { systemFeatures: sys, homeFeatures: home };
  }, [wizard.selectedFeatures]);

  const [importError, setImportError] = useState('');

  const handleExportPlan = useCallback(async () => {
    const payload = buildInstallPlanPayload(wizard);
    const content = JSON.stringify(payload, null, 2);
    const blob = new Blob([content], { type: 'application/json' });

    // Try File System Access API (showSaveFilePicker)
    if ('showSaveFilePicker' in window) {
      try {
        const handle = await window.showSaveFilePicker({
          suggestedName: 'kryonix-install-plan.json',
          types: [{
            description: 'JSON Plan',
            accept: { 'application/json': ['.json'] }
          }]
        });
        const writable = await handle.createWritable();
        await writable.write(blob);
        await writable.close();
        return;
      } catch (err) {
        if (err.name !== 'AbortError') {
          console.warn('[Summary] showSaveFilePicker failed, falling back:', err);
        }
      }
    }

    // Fallback: classic download
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'kryonix-install-plan.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }, [wizard]);

  const handleImportPlan = useCallback((event) => {
    const file = event.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const json = JSON.parse(e.target.result);
        // Basic validation: check required top-level fields
        if (!json.version || !json.network || !json.disk || !json.admin) {
          throw new Error('JSON não contém campos obrigatórios do plano de instalação.');
        }
        // Convert payload back to wizard draft fields where possible
        const draftPatch = {};
        if (json.network) {
          if (json.network.hostname) draftPatch.hostName = json.network.hostname;
          if (json.network.interface) draftPatch.mgmtInterface = json.network.interface;
          if (json.network.mode) draftPatch.mgmtMode = json.network.mode === 'static' ? 'static' : 'dhcp';
          if (json.network.serverIp && json.network.serverIp !== '0.0.0.0') draftPatch.serverIp = json.network.serverIp;
          if (json.network.gateway) draftPatch.mgmtGateway = json.network.gateway;
          if (json.network.dns?.length) draftPatch.mgmtDns = json.network.dns.join(',');
          if (json.network.httpPort) draftPatch.httpPort = json.network.httpPort;
          if (json.network.wan) {
            if (json.network.wan.interface) draftPatch.wanInterface = json.network.wan.interface;
            if (json.network.wan.mode) draftPatch.wanMode = json.network.wan.mode;
            if (json.network.wan.address) draftPatch.wanAddress = json.network.wan.address;
            if (json.network.wan.gateway) draftPatch.wanGateway = json.network.wan.gateway;
            if (json.network.wan.dns?.length) draftPatch.wanDns = json.network.wan.dns.join(',');
            if (json.network.wan.pppoeUser) draftPatch.pppoeUser = json.network.wan.pppoeUser;
          }
        }
        if (json.disk) {
          if (json.disk.mode) draftPatch.diskMode = json.disk.mode;
          if (json.disk.profile) draftPatch.diskProfile = json.disk.profile;
          if (json.disk.sysDisk) draftPatch.sysDisk = json.disk.sysDisk;
          if (json.disk.dataDisk) draftPatch.dataDisk = json.disk.dataDisk;
          if (json.disk.selectedDisks) draftPatch.selectedDisks = json.disk.selectedDisks;
          if (json.disk.raidLevel) draftPatch.raidLevel = json.disk.raidLevel;
          if (json.disk.luksEnabled !== undefined) draftPatch.luksEnabled = json.disk.luksEnabled;
          if (json.disk.rootFs) draftPatch.rootFs = json.disk.rootFs;
          if (json.disk.dataFs) draftPatch.dataFs = json.disk.dataFs;
        }
        if (json.locale) {
          if (json.locale.country) draftPatch.country = json.locale.country;
          if (json.locale.timezone) draftPatch.timeZone = json.locale.timezone;
          if (json.locale.locale) draftPatch.locale = json.locale.locale;
          if (json.locale.keymap) draftPatch.keyMap = json.locale.keymap;
        }
        if (json.admin) {
          if (json.admin.user) draftPatch.adminUser = json.admin.user;
          if (json.admin.uid) draftPatch.adminUid = json.admin.uid;
          if (json.admin.email) draftPatch.adminEmail = json.admin.email;
          if (json.admin.authorizedKeys) draftPatch.adminAuthorizedKeys = json.admin.authorizedKeys.join('\n');
        }
        if (json.profile?.id) draftPatch.profileId = json.profile.id;
        if (json.remoteAccess?.enabled !== undefined) draftPatch.remoteAccessEnabled = json.remoteAccess.enabled;
        if (json.security?.allowWeakPassword !== undefined) draftPatch.allowWeakPassword = json.security.allowWeakPassword;

        onChange(draftPatch);
        setImportError('');
        // Reset file input so same file can be imported again if needed
        event.target.value = '';
      } catch (err) {
        console.error('[Summary] Import error:', err);
        setImportError(err instanceof Error ? err.message : 'Falha ao importar JSON.');
      }
    };
    reader.onerror = () => setImportError('Erro ao ler arquivo.');
    reader.readAsText(file);
  }, [onChange]);

  return (
    <div className="grid h-full min-h-0 gap-6 lg:grid-cols-[1.05fr_0.95fr]">
      <section className="section-panel min-h-0 overflow-y-auto">
        <div className="mb-5">
          <h2 className="text-xl font-black text-white">Resumo final antes de instalar</h2>
          <p className="mt-2 text-sm text-slate-300">Revise tudo. Este é o último checkpoint antes de gerar o plano e iniciar a instalação com logs em tempo real.</p>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <div className="rounded-2xl border border-white/10 bg-white/[0.04] p-4">
            <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Instalação & Host</div>
            <div className="mt-2 text-sm text-white">Hostname: {wizard.hostName || 'pendente'}</div>
            <div className="mt-1 text-sm text-slate-300">Fonte: {wizard.sourceKind === 'offline-defaults' ? 'Offline (ISO base)' : wizard.sourceKind}</div>
            <div className="mt-1 text-sm text-slate-400">Acesso Remoto: {wizard.remoteAccessEnabled ? 'Ativado' : 'Desativado'}</div>
            <div className="mt-1 text-sm text-slate-400">
              Perfil: {profileObj ? `${profileObj.name} (${profileObj.id})` : (wizard.profileId || 'Nenhum')}
            </div>
          </div>
          <div className="rounded-2xl border border-white/10 bg-white/[0.04] p-4">
            <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Rede</div>
            <div className="mt-2 text-sm text-white">WAN: {wizard.wanInterface ? `${wizard.wanInterface} • modo ${wizard.wanMode}` : 'opcional / desabilitada'}</div>
            <div className="mt-1 text-sm text-slate-300">LAN/PXE: {wizard.mgmtInterface || 'sem interface'}</div>
            <div className="mt-1 text-sm text-slate-400">{networkSummary}</div>
          </div>
          <div className="rounded-2xl border border-white/10 bg-white/[0.04] p-4">
            <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Discos</div>
            <div className="mt-2 text-sm text-white">Layout: {layoutLabel}</div>
            <div className="mt-1 text-sm text-slate-300">Sistema: {wizard.sysDisk || '—'}</div>
            <div className="mt-1 text-sm text-slate-400">
              {wizard.diskProfile === 'raid'
                ? `Membros: ${(wizard.selectedDisks || []).join(', ') || '—'}`
                : hasDedicatedData
                  ? `Dados: ${wizard.dataDisk || '—'} -> /srv/data`
                  : 'Dados: subvol interno no mesmo BTRFS (sem disco dedicado)'}
            </div>
          </div>
          <div className="rounded-2xl border border-white/10 bg-white/[0.04] p-4">
            <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Admin</div>
            <div className="mt-2 text-sm text-white">{wizard.adminUser} • UID {wizard.adminUid}</div>
            <div className="mt-1 text-sm text-slate-400">{wizard.adminEmail} • {sshCount} chave(s) SSH</div>
          </div>
        </div>

        {/* /srv/data panel */}
        <div className={`mt-4 rounded-2xl border p-4 text-sm ${srvDataActive ? 'border-emerald-400/20 bg-emerald-400/10 text-emerald-100' : 'border-slate-400/20 bg-slate-400/5 text-slate-300'}`}>
          <div className="font-bold flex items-center gap-2">
            <span>{srvDataActive ? '✓' : '○'}</span>
            /srv/data {srvDataActive ? 'ativado' : 'não ativado'}
          </div>
          <p className="mt-2">
            {srvDataActive
              ? `Motivo: ${srvDataReason}. /srv/data será usado para dados de servidor, bancos, modelos, RAG, Neo4j, LightRAG e serviços persistentes.`
              : `Motivo: ${srvDataReason}. Este perfil não requer volume de dados persistente separado.`}
          </p>
        </div>

        {/* Features separadas */}
        {systemFeatures.length > 0 && (
          <div className="mt-4 rounded-2xl border border-white/10 bg-white/[0.04] p-4">
            <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Features de Sistema</div>
            <div className="mt-2 flex flex-wrap gap-2">
              {systemFeatures.map(f => (
                <span key={f.id} className="px-2.5 py-1 text-xs rounded-lg font-medium bg-blue-500/15 text-blue-300 border border-blue-500/20">
                  {f.name}
                </span>
              ))}
            </div>
          </div>
        )}
        {homeFeatures.length > 0 && (
          <div className="mt-4 rounded-2xl border border-white/10 bg-white/[0.04] p-4">
            <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Features Home Manager</div>
            <div className="mt-2 flex flex-wrap gap-2">
              {homeFeatures.map(f => (
                <span key={f.id} className="px-2.5 py-1 text-xs rounded-lg font-medium bg-purple-500/15 text-purple-300 border border-purple-500/20">
                  {f.name}
                </span>
              ))}
            </div>
          </div>
        )}

        <div className="mt-5 rounded-2xl border border-rose-400/20 bg-rose-400/10 p-4 text-sm text-rose-100">
          <div className="font-bold">Plano final de disco com confirmação destrutiva</div>
          <p className="mt-2">Os discos selecionados podem ser limpos e reformatados. Confira novamente sistema, dados, rede e usuário antes de prosseguir.</p>
        </div>
      </section>

      <section className="section-panel flex min-h-0 flex-col justify-between">
        <div>
          <div className="rounded-2xl border border-white/10 bg-slate-950/60 p-4">
            <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Checklist crítico</div>
            <ul className="mt-3 space-y-2 text-sm text-slate-300">
              <li>• EULA aceito: {uiState.eulaAccepted ? 'sim' : 'não'}</li>
              <li>• Hostname: {wizard.hostName ? 'sim' : 'não'}</li>
              <li>• Perfil selecionado: {wizard.profileId ? 'sim' : 'não'}</li>
              <li>• Features sistema: {systemFeatures.length} ativadas</li>
              <li>• Features usuário: {homeFeatures.length} ativadas</li>
              <li>• /srv/data: {srvDataActive ? 'sim' : 'não'}</li>
              <li>• Senha forte:{' '}
                {allowWeak
                  ? 'ignorada por modo laboratório'
                  : passwordStrong ? 'sim' : 'não'}
              </li>
              <li>• Senha confere: {passwordMatches ? 'sim' : 'não'}</li>
              <li>• Plano destrutivo entendido: {uiState.destructiveConfirmed ? 'sim' : 'não'}</li>
            </ul>

            {allowWeak ? (
              <div className="mt-3 rounded-xl border border-amber-400/20 bg-amber-400/10 px-3 py-2 text-xs text-amber-100">
                Modo laboratório ativo: regra de senha forte desativada. Não use este perfil para uso real.
              </div>
            ) : null}
            {validation?.warnings?.length > 0 ? (
              <div className="mt-4 rounded-xl border border-amber-400/20 bg-amber-400/10 px-3 py-2 text-amber-100">
                {validation.warnings[0]}
              </div>
            ) : null}
          </div>

          <label className="mt-5 flex cursor-pointer items-start gap-3 rounded-2xl border border-amber-400/20 bg-amber-400/10 p-4">
            <input
              type="checkbox"
              className="mt-1 h-5 w-5 rounded border-white/20 bg-slate-950 text-accent-500"
              checked={uiState.destructiveConfirmed}
              onChange={(event) => onChange({ destructiveConfirmed: event.target.checked })}
            />
            <div>
              <div className="font-semibold text-white">Confirmo que este plano pode apagar dados</div>
              <div className="mt-1 text-sm text-slate-300">Entendo que os discos selecionados serão alterados pela instalação unattended.</div>
            </div>
            </label>
        </div>

        <div className="flex flex-col gap-3 mt-4">
          <div className="flex gap-3">
            <button
              type="button"
              className="rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white hover:bg-white/10 transition-colors"
              onClick={handleExportPlan}
            >
              Exportar plano JSON
            </button>
            <label className="flex items-center rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white hover:bg-white/10 transition-colors cursor-pointer">
              <input
                type="file"
                accept="application/json,.json"
                className="sr-only"
                onChange={handleImportPlan}
              />
              Importar plano JSON
            </label>
          </div>
          {importError && (
            <div className="rounded-xl border border-rose-400/20 bg-rose-400/10 px-3 py-2 text-sm text-rose-100">
              {importError}
            </div>
          )}
          <div className="flex-1 rounded-xl border border-cyan-400/20 bg-cyan-400/10 p-4 text-sm text-cyan-50">
            A próxima etapa gera o plano via backend e permite iniciar a instalação com logs ao vivo.
          </div>
        </div>
      </section>
    </div>
  );
}
