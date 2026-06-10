import { useMemo } from 'react';
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

  const handleExportPlan = () => {
    const payload = buildInstallPlanPayload(wizard);
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'kryonix-install-plan.json';
    a.click();
    URL.revokeObjectURL(url);
  };

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

        <div className="flex gap-4">
          <button
            type="button"
            className="rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white hover:bg-white/10 transition-colors"
            onClick={handleExportPlan}
          >
            Exportar plano JSON
          </button>
          <div className="flex-1 rounded-xl border border-cyan-400/20 bg-cyan-400/10 p-4 text-sm text-cyan-50">
            A próxima etapa gera o plano via backend e permite iniciar a instalação com logs ao vivo.
          </div>
        </div>
      </section>
    </div>
  );
}
