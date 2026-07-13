import { useEffect, useMemo, useState } from 'react';
import FieldError from '../components/FieldError.jsx';
import { installerApi, getInstallerApiErrorMessage } from '../utils/installerApi.js';
import { buildInstallPlanPayload } from '../utils/installPlan.js';
import {
  buildRaidPlanSummary,
  buildSplitPlanSummary,
  formatBytes,
  getRaidOptionsForSelection,
  getSelectedDiskRecords,
  normalizeDiskInventory,
  validateRaidSelection,
  validateSingleDiskLayout,
  validateSplitDiskLayout,
} from '../utils/storagePlanner.js';

const filesystemOptions = ['btrfs', 'ext4', 'xfs'];

function arraysEqual(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function uniqueStrings(items) {
  return Array.from(new Set((Array.isArray(items) ? items : []).filter(Boolean)));
}

function SummaryRow({ label, value }) {
  return (
    <div className="flex items-center justify-between gap-3 rounded-xl border border-white/10 bg-white/[0.03] px-3 py-2 text-sm text-slate-300">
      <span className="text-slate-400">{label}</span>
      <span className="font-semibold text-white">{value}</span>
    </div>
  );
}

function Metric({ label, value, tone = 'text-white' }) {
  return (
    <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-3">
      <div className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">{label}</div>
      <div className={`mt-2 text-sm font-semibold ${tone}`}>{value}</div>
    </div>
  );
}

function HelpBlock() {
  return (
    <div className="rounded-2xl border border-cyan-400/20 bg-cyan-400/10 p-4 text-sm text-cyan-50">
      <div className="text-xs font-semibold uppercase tracking-[0.22em] text-cyan-200">Ajuda tecnica</div>
      <div className="mt-3 space-y-3 text-cyan-100">
        <p><b className="text-white">Single disk</b>: um unico disco. O executor cria EFI + raiz BTRFS e mantem `/srv/data` no mesmo device usando subvolumes.</p>
        <p><b className="text-white">Split disks</b>: dois discos distintos. O disco raiz recebe EFI + `/`; o disco de dados recebe `/srv/data`.</p>
        <p><b className="text-white">RAID</b>: opcional e nunca automatico. No executor atual ele usa `mdadm` + BTRFS. So faz sentido quando a redundancia foi realmente planejada.</p>
        <p><b className="text-white">Quando RAID nao faz sentido</b>: apenas porque ha 2 discos, quando os tamanhos sao muito diferentes, ou quando o objetivo real e separar sistema de dados.</p>
        <p><b className="text-white">LVM</b>: nao implementado no executor atual. O botao fica apenas como marcador honesto de backlog, sem entrar no payload.</p>
        <p><b className="text-white">Exemplo pratico</b>: Disco 1 -&gt; `/`; Disco 2 -&gt; `/srv/data`. Esse e o layout split real do pipeline atual.</p>
      </div>
    </div>
  );
}

function roleTone(role) {
  switch (role) {
    case 'root':
      return 'border-cyan-300/40 bg-cyan-400/20 text-cyan-100';
    case 'data':
      return 'border-emerald-300/40 bg-emerald-400/20 text-emerald-100';
    case 'member':
      return 'border-indigo-300/40 bg-indigo-400/20 text-indigo-100';
    default:
      return 'border-white/10 bg-white/[0.03] text-slate-300';
  }
}

export default function Disks({ wizard, uiState, onChange, validation }) {
  const [diskInventory, setDiskInventory] = useState([]);
  const [loadingDisks, setLoadingDisks] = useState(true);
  const [diskError, setDiskError] = useState('');
  const [showHelp, setShowHelp] = useState(false);
  const fieldErrors = validation?.fieldErrors || {};

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        setLoadingDisks(true);
        setDiskError('');
        const payload = await installerApi.getDisks();
        if (!cancelled) {
          setDiskInventory(normalizeDiskInventory(payload.disks));
        }
      } catch (error) {
        if (!cancelled) {
          setDiskError(getInstallerApiErrorMessage(error, 'Erro ao carregar discos.'));
          setDiskInventory([]);
        }
      } finally {
        if (!cancelled) {
          setLoadingDisks(false);
        }
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, []);

  const eligibleDisks = useMemo(() => diskInventory.filter((disk) => disk.eligible), [diskInventory]);
  const eligiblePaths = useMemo(() => new Set(eligibleDisks.map((disk) => disk.path)), [eligibleDisks]);
  const layoutMode = wizard.diskProfile === 'raid' ? 'raid' : wizard.diskMode === 'two' ? 'split' : 'single';
  const raidMembers = useMemo(() => getSelectedDiskRecords(diskInventory, wizard.selectedDisks), [diskInventory, wizard.selectedDisks]);
  const raidMemberPaths = useMemo(() => raidMembers.map((disk) => disk.path), [raidMembers]);
  const raidOptions = useMemo(() => getRaidOptionsForSelection(raidMembers), [raidMembers]);
  const enabledRaidOptions = useMemo(() => raidOptions.filter((option) => option.enabled), [raidOptions]);
  const resolvedRaidLevel = useMemo(() => {
    if (enabledRaidOptions.some((option) => option.id === wizard.raidLevel)) {
      return wizard.raidLevel;
    }
    return enabledRaidOptions[0]?.id || wizard.raidLevel || 'raid1';
  }, [enabledRaidOptions, wizard.raidLevel]);
  const singleValidation = useMemo(() => validateSingleDiskLayout(diskInventory, wizard.sysDisk), [diskInventory, wizard.sysDisk]);
  const splitValidation = useMemo(() => validateSplitDiskLayout(diskInventory, wizard.sysDisk, wizard.dataDisk), [diskInventory, wizard.sysDisk, wizard.dataDisk]);
  const raidValidation = useMemo(() => validateRaidSelection(raidMembers, resolvedRaidLevel), [raidMembers, resolvedRaidLevel]);
  const raidSummary = useMemo(() => buildRaidPlanSummary(raidMembers, resolvedRaidLevel), [raidMembers, resolvedRaidLevel]);
  const splitSummary = useMemo(() => buildSplitPlanSummary(diskInventory, wizard.sysDisk, wizard.dataDisk), [diskInventory, wizard.sysDisk, wizard.dataDisk]);
  const planPayload = useMemo(() => buildInstallPlanPayload(wizard), [wizard]);

  const storageIssues = layoutMode === 'raid'
    ? raidValidation.blockingReasons
    : layoutMode === 'split'
      ? splitValidation.blockingReasons
      : singleValidation.blockingReasons;
  const storageWarnings = layoutMode === 'raid'
    ? raidValidation.warnings
    : layoutMode === 'split'
      ? splitValidation.warnings
      : singleValidation.warnings;

  useEffect(() => {
    if (loadingDisks) return;

    const patch = {};
    const firstEligible = eligibleDisks[0]?.path || '';
    const secondEligible = eligibleDisks.find((disk) => disk.path !== firstEligible)?.path || '';

    if (layoutMode === 'single') {
      const nextSys = eligiblePaths.has(wizard.sysDisk) ? wizard.sysDisk : firstEligible;
      const selectedDisks = nextSys ? [nextSys] : [];

      if (wizard.diskProfile !== 'single') patch.diskProfile = 'single';
      if (wizard.diskMode !== 'one') patch.diskMode = 'one';
      if (wizard.sysDisk !== nextSys) patch.sysDisk = nextSys;
      if (wizard.dataDisk) patch.dataDisk = '';
      if (!arraysEqual(wizard.selectedDisks || [], selectedDisks)) patch.selectedDisks = selectedDisks;
      if (wizard.rootFs !== 'btrfs') patch.rootFs = 'btrfs';
      if (wizard.dataFs !== 'btrfs') patch.dataFs = 'btrfs';
    }

    if (layoutMode === 'split') {
      const nextSys = eligiblePaths.has(wizard.sysDisk) ? wizard.sysDisk : firstEligible;
      const nextData = eligiblePaths.has(wizard.dataDisk) && wizard.dataDisk !== nextSys
        ? wizard.dataDisk
        : eligibleDisks.find((disk) => disk.path !== nextSys)?.path || '';
      const selectedDisks = uniqueStrings([nextSys, nextData]);

      if (wizard.diskProfile !== 'single') patch.diskProfile = 'single';
      if (wizard.diskMode !== 'two') patch.diskMode = 'two';
      if (wizard.sysDisk !== nextSys) patch.sysDisk = nextSys;
      if (wizard.dataDisk !== nextData) patch.dataDisk = nextData;
      if (!arraysEqual(wizard.selectedDisks || [], selectedDisks)) patch.selectedDisks = selectedDisks;
      if (!filesystemOptions.includes(wizard.rootFs)) patch.rootFs = 'btrfs';
      if (!filesystemOptions.includes(wizard.dataFs)) patch.dataFs = 'btrfs';
    }

    if (layoutMode === 'raid') {
      let nextMembers = diskInventory
        .filter((disk) => disk.eligible && raidMemberPaths.includes(disk.path))
        .map((disk) => disk.path);

      if (nextMembers.length === 0) {
        nextMembers = uniqueStrings([wizard.sysDisk, wizard.dataDisk].filter((path) => eligiblePaths.has(path)));
      }

      if (nextMembers.length === 0 && eligibleDisks.length >= 2) {
        nextMembers = eligibleDisks.slice(0, 2).map((disk) => disk.path);
      }

      const nextSys = nextMembers.includes(wizard.sysDisk) ? wizard.sysDisk : nextMembers[0] || '';

      if (wizard.diskProfile !== 'raid') patch.diskProfile = 'raid';
      if (wizard.diskMode !== 'one') patch.diskMode = 'one';
      if (!arraysEqual(wizard.selectedDisks || [], nextMembers)) patch.selectedDisks = nextMembers;
      if (wizard.sysDisk !== nextSys) patch.sysDisk = nextSys;
      if (wizard.dataDisk) patch.dataDisk = '';
      if (wizard.rootFs !== 'btrfs') patch.rootFs = 'btrfs';
      if (wizard.dataFs !== 'btrfs') patch.dataFs = 'btrfs';
      if (wizard.raidLevel !== resolvedRaidLevel) patch.raidLevel = resolvedRaidLevel;
    }

    if (!arraysEqual(storageIssues, uiState.storageBlockingIssues || [])) patch.storageBlockingIssues = storageIssues;
    if (!arraysEqual(storageWarnings, uiState.storageWarnings || [])) patch.storageWarnings = storageWarnings;

    if (Object.keys(patch).length > 0) {
      onChange(patch);
    }
  }, [
    diskInventory,
    eligibleDisks,
    eligiblePaths,
    layoutMode,
    loadingDisks,
    onChange,
    raidMemberPaths,
    resolvedRaidLevel,
    storageIssues,
    storageWarnings,
    uiState.storageBlockingIssues,
    uiState.storageWarnings,
    wizard.dataDisk,
    wizard.dataFs,
    wizard.diskMode,
    wizard.diskProfile,
    wizard.raidLevel,
    wizard.rootFs,
    wizard.selectedDisks,
    wizard.sysDisk,
  ]);

  function getDiskRole(path) {
    if (layoutMode === 'raid') {
      return raidMemberPaths.includes(path) ? 'member' : 'unused';
    }
    if (layoutMode === 'split') {
      if (wizard.sysDisk === path) return 'root';
      if (wizard.dataDisk === path) return 'data';
      return 'unused';
    }
    return wizard.sysDisk === path ? 'root' : 'unused';
  }

  function getDiskMountpoint(path) {
    const role = getDiskRole(path);
    if (role === 'root') return '/';
    if (role === 'data') return '/srv/data';
    if (role === 'member') return wizard.sysDisk === path ? 'mdadm member / referencia' : 'mdadm member';
    return 'unused';
  }

  function handleLayoutModeChange(nextMode) {
    const firstEligible = eligibleDisks[0]?.path || '';
    const secondEligible = eligibleDisks.find((disk) => disk.path !== firstEligible)?.path || '';

    if (nextMode === 'single') {
      const nextSys = eligiblePaths.has(wizard.sysDisk) ? wizard.sysDisk : firstEligible;
      onChange({
        diskProfile: 'single',
        diskMode: 'one',
        sysDisk: nextSys,
        dataDisk: '',
        selectedDisks: nextSys ? [nextSys] : [],
        rootFs: 'btrfs',
        dataFs: 'btrfs',
      });
      return;
    }

    if (nextMode === 'split') {
      const nextSys = eligiblePaths.has(wizard.sysDisk) ? wizard.sysDisk : firstEligible;
      const nextData = eligiblePaths.has(wizard.dataDisk) && wizard.dataDisk !== nextSys ? wizard.dataDisk : secondEligible;
      onChange({
        diskProfile: 'single',
        diskMode: 'two',
        sysDisk: nextSys,
        dataDisk: nextData,
        selectedDisks: uniqueStrings([nextSys, nextData]),
      });
      return;
    }

    if (nextMode === 'raid') {
      let nextMembers = uniqueStrings([
        ...((wizard.selectedDisks || []).filter((path) => eligiblePaths.has(path))),
        ...(eligiblePaths.has(wizard.sysDisk) ? [wizard.sysDisk] : []),
        ...(eligiblePaths.has(wizard.dataDisk) ? [wizard.dataDisk] : []),
      ]);

      if (nextMembers.length < 2) {
        nextMembers = eligibleDisks.slice(0, 2).map((disk) => disk.path);
      }

      onChange({
        diskProfile: 'raid',
        diskMode: 'one',
        sysDisk: nextMembers[0] || '',
        dataDisk: '',
        selectedDisks: nextMembers,
        rootFs: 'btrfs',
        dataFs: 'btrfs',
        raidLevel: resolvedRaidLevel,
      });
    }
  }

  function handleSystemDiskChange(nextSysDisk) {
    if (layoutMode === 'single') {
      onChange({
        sysDisk: nextSysDisk,
        selectedDisks: nextSysDisk ? [nextSysDisk] : [],
      });
      return;
    }

    const nextDataDisk = wizard.dataDisk === nextSysDisk ? '' : wizard.dataDisk;
    onChange({
      sysDisk: nextSysDisk,
      dataDisk: nextDataDisk,
      selectedDisks: uniqueStrings([nextSysDisk, nextDataDisk]),
    });
  }

  function handleDataDiskChange(nextDataDisk) {
    onChange({
      dataDisk: nextDataDisk,
      selectedDisks: uniqueStrings([wizard.sysDisk, nextDataDisk]),
    });
  }

  function toggleRaidMember(path) {
    const exists = raidMemberPaths.includes(path);
    const nextMembers = exists
      ? raidMemberPaths.filter((item) => item !== path)
      : [...raidMemberPaths, path];

    onChange({
      selectedDisks: diskInventory
        .filter((disk) => disk.eligible && nextMembers.includes(disk.path))
        .map((disk) => disk.path),
      sysDisk: exists && wizard.sysDisk === path ? nextMembers[0] || '' : wizard.sysDisk || nextMembers[0] || '',
    });
  }

  const summaryTitle = layoutMode === 'raid'
    ? `RAID ${resolvedRaidLevel.toUpperCase()}`
    : layoutMode === 'split'
      ? 'Split disks'
      : 'Single disk';

  return (
    <div className="grid h-full min-h-0 gap-4 lg:grid-cols-[1.08fr_0.92fr]">
      <section className="section-panel min-h-0 overflow-y-auto p-4">
        <div className="mb-4 flex items-start justify-between gap-4">
          <div>
            <h3 className="text-xl font-bold text-white">Storage do instalador</h3>
            <p className="mt-1 text-sm text-slate-400">Inventario, layout, papeis e validacao alinhados ao executor real do RAGOS.</p>
          </div>
          <button type="button" className="btn-secondary !px-3 !py-2" onClick={() => setShowHelp((previous) => !previous)}>
            {showHelp ? 'Ocultar ajuda' : 'Ajuda tecnica'}
          </button>
        </div>

        {showHelp ? <HelpBlock /> : null}

        <div className="mt-4 space-y-4">
          <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
            <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">1. Inventario de discos</div>
            {loadingDisks ? <div className="mt-3 rounded-xl border border-white/10 bg-slate-950/60 p-3 text-sm text-slate-400">Carregando inventario...</div> : null}
            {diskError ? <div className="mt-3 rounded-xl border border-rose-400/20 bg-rose-400/10 p-3 text-sm text-rose-200">{diskError}</div> : null}
            <div className="mt-3 grid gap-3">
              {diskInventory.map((disk) => {
                const role = getDiskRole(disk.path);
                return (
                  <div key={disk.path} className="rounded-2xl border border-white/10 bg-slate-950/60 p-4">
                    <div className="flex items-start justify-between gap-4">
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="font-semibold text-white">{disk.path}</span>
                          <span className={`rounded-full border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.18em] ${roleTone(role)}`}>
                            {role}
                          </span>
                        </div>
                        <div className="mt-2 text-sm text-slate-300">{disk.model || 'Disco fisico detectado pelo backend'}</div>
                        <div className="mt-1 text-xs text-slate-400">
                          {disk.sizeLabel} • tipo {disk.type || 'disk'} • transporte {disk.transport || 'n/d'} • mount {getDiskMountpoint(disk.path)}
                        </div>
                        {disk.eligibilityIssues[0] ? (
                          <div className="mt-2 text-xs text-amber-200">{disk.eligibilityIssues[0]}</div>
                        ) : null}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
            <FieldError message={fieldErrors.selectedDisks} />
          </div>

          <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
            <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">2. Modo de layout</div>
            <div className="mt-3 grid gap-2 sm:grid-cols-2 xl:grid-cols-4">
              <button type="button" className={layoutMode === 'single' ? 'btn-primary' : 'btn-secondary'} onClick={() => handleLayoutModeChange('single')}>
                Single disk
              </button>
              <button type="button" className={layoutMode === 'split' ? 'btn-primary' : 'btn-secondary'} onClick={() => handleLayoutModeChange('split')}>
                Split disks
              </button>
              <button
                type="button"
                className={layoutMode === 'raid' ? 'btn-primary' : 'btn-secondary'}
                disabled={eligibleDisks.length < 2}
                onClick={() => handleLayoutModeChange('raid')}
              >
                RAID (software)
              </button>
              <button type="button" className="btn-secondary" disabled>
                LVM (pendente)
              </button>
            </div>
            <div className="mt-3 rounded-xl border border-white/10 bg-slate-950/60 p-3 text-sm text-slate-300">
              Layout atual: <b className="text-white">{summaryTitle}</b>.
              {layoutMode === 'raid' ? ' Nenhum RAID e ativado automaticamente; ele so existe quando esta selecionado aqui.' : ' O contrato antigo continua preservado por meio de disk.mode + disk.profile.'}
            </div>
          </div>

          <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
            <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">3. Mapeamento de papeis</div>

            {layoutMode === 'single' ? (
              <div className="mt-3 grid gap-4">
                <div>
                  <label className="label-text" htmlFor="sysDiskSingle">Disco raiz</label>
                  <select id="sysDiskSingle" className="input-shell" value={wizard.sysDisk} onChange={(event) => handleSystemDiskChange(event.target.value)}>
                    <option value="">Selecione um disco</option>
                    {eligibleDisks.map((disk) => (
                      <option key={disk.path} value={disk.path}>{disk.path} • {disk.sizeLabel}</option>
                    ))}
                  </select>
                  <FieldError message={fieldErrors.sysDisk} />
                </div>
                <div className="rounded-xl border border-emerald-400/20 bg-emerald-400/10 p-3 text-sm text-emerald-100">
                  `/`, `/srv` e `/srv/data` ficarao no mesmo device BTRFS. RAID e data disk separados nao entram neste layout.
                </div>
              </div>
            ) : null}

            {layoutMode === 'split' ? (
              <div className="mt-3 grid gap-4">
                <div className="grid gap-4 sm:grid-cols-2">
                  <div>
                    <label className="label-text" htmlFor="sysDiskSplit">Papel root</label>
                    <select id="sysDiskSplit" className="input-shell" value={wizard.sysDisk} onChange={(event) => handleSystemDiskChange(event.target.value)}>
                      <option value="">Selecione um disco</option>
                      {eligibleDisks.map((disk) => (
                        <option key={disk.path} value={disk.path}>{disk.path} • {disk.sizeLabel}</option>
                      ))}
                    </select>
                    <FieldError message={fieldErrors.sysDisk} />
                  </div>
                  <div>
                    <label className="label-text" htmlFor="dataDiskSplit">Papel data</label>
                    <select id="dataDiskSplit" className="input-shell" value={wizard.dataDisk} onChange={(event) => handleDataDiskChange(event.target.value)}>
                      <option value="">Selecione um disco</option>
                      {eligibleDisks
                        .filter((disk) => disk.path !== wizard.sysDisk)
                        .map((disk) => (
                          <option key={disk.path} value={disk.path}>{disk.path} • {disk.sizeLabel}</option>
                        ))}
                    </select>
                    <FieldError message={fieldErrors.dataDisk} />
                  </div>
                </div>

                <div className="grid gap-4 sm:grid-cols-2">
                  <div>
                    <label className="label-text" htmlFor="rootFs">Filesystem raiz</label>
                    <select id="rootFs" className="input-shell" value={wizard.rootFs} onChange={(event) => onChange({ rootFs: event.target.value })}>
                      {filesystemOptions.map((item) => <option key={item} value={item}>{item}</option>)}
                    </select>
                  </div>
                  <div>
                    <label className="label-text" htmlFor="dataFs">Filesystem de dados</label>
                    <select id="dataFs" className="input-shell" value={wizard.dataFs} onChange={(event) => onChange({ dataFs: event.target.value })}>
                      {filesystemOptions.map((item) => <option key={item} value={item}>{item}</option>)}
                    </select>
                  </div>
                </div>

                <div className="rounded-xl border border-white/10 bg-slate-950/60 p-3 text-sm text-slate-300">
                  Root: <b className="text-white">/</b> no disco do sistema. Dados: <b className="text-white">/srv/data</b> no disco de dados.
                </div>
              </div>
            ) : null}

            {layoutMode === 'raid' ? (
              <div className="mt-3 grid gap-4">
                <div>
                  <label className="label-text">Papel member</label>
                  <div className="mt-2 grid gap-2">
                    {eligibleDisks.map((disk) => {
                      const checked = raidMemberPaths.includes(disk.path);
                      return (
                        <label key={disk.path} className={`flex items-center justify-between gap-3 rounded-xl border px-3 py-2.5 text-sm ${checked ? 'border-accent-400/40 bg-accent-500/10 text-white' : 'border-white/10 bg-slate-950/60 text-slate-300'}`}>
                          <span>{disk.path} • {disk.sizeLabel}</span>
                          <input type="checkbox" className="h-4 w-4 rounded" checked={checked} onChange={() => toggleRaidMember(disk.path)} />
                        </label>
                      );
                    })}
                  </div>
                </div>

                <div>
                  <label className="label-text" htmlFor="raidBootMember">Membro de referencia</label>
                  <select id="raidBootMember" className="input-shell" value={wizard.sysDisk} onChange={(event) => onChange({ sysDisk: event.target.value })}>
                    <option value="">Selecione um membro</option>
                    {raidMembers.map((disk) => (
                      <option key={disk.path} value={disk.path}>{disk.path}</option>
                    ))}
                  </select>
                  <FieldError message={fieldErrors.sysDisk} />
                </div>

                <div>
                  <label className="label-text">Nivel RAID</label>
                  <div className="mt-2 grid gap-2">
                    {raidOptions.map((option) => {
                      const active = resolvedRaidLevel === option.id;
                      return (
                        <button
                          key={option.id}
                          type="button"
                          className={`w-full rounded-2xl border px-4 py-3 text-left transition ${active ? 'border-accent-400/60 bg-accent-500/15' : 'border-white/10 bg-white/[0.03] hover:border-white/20 hover:bg-white/[0.05]'}`}
                          onClick={() => onChange({ raidLevel: option.id })}
                        >
                          <div className="flex items-start justify-between gap-4">
                            <div>
                              <div className="font-semibold text-white">{option.label}</div>
                              <div className="mt-1 text-xs text-slate-400">{option.description}</div>
                              <div className="mt-2 text-xs text-slate-300">Minimo {option.minDisks} discos • tolerancia {option.faultTolerance}</div>
                              {option.blockingReasons[0] ? (
                                <div className="mt-2 text-xs text-rose-200">{option.blockingReasons[0]}</div>
                              ) : option.warnings[0] ? (
                                <div className="mt-2 text-xs text-amber-200">{option.warnings[0]}</div>
                              ) : (
                                <div className="mt-2 text-xs text-emerald-200">Pronto para o executor atual.</div>
                              )}
                            </div>
                          </div>
                        </button>
                      );
                    })}
                  </div>
                  <FieldError message={fieldErrors.raidLevel} />
                </div>
              </div>
            ) : null}

            <label className="mt-4 flex items-center gap-2 rounded-xl border border-white/10 bg-slate-950/60 px-3 py-2.5 text-sm text-slate-200">
              <input type="checkbox" className="h-4 w-4 rounded" checked={Boolean(wizard.luksEnabled)} onChange={(event) => onChange({ luksEnabled: event.target.checked })} />
              Criptografar a raiz com LUKS no executor atual.
            </label>
          </div>
        </div>
      </section>

      <section className="section-panel min-h-0 overflow-y-auto p-4">
        <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">4. Resumo final do layout</div>
        <div className="mt-4 space-y-3">
          <SummaryRow label="Layout solicitado" value={summaryTitle} />
          <SummaryRow label="disk.mode -> backend" value={planPayload.disk.mode} />
          <SummaryRow label="disk.profile -> backend" value={planPayload.disk.profile} />
          <SummaryRow label="Discos apagados" value={planPayload.disk.selectedDisks.join(', ') || 'nenhum'} />
          <SummaryRow label="Raiz" value={planPayload.disk.sysDisk ? `${planPayload.disk.sysDisk} -> /` : 'pendente'} />
          <SummaryRow
            label="Dados"
            value={
              planPayload.disk.profile === 'raid'
                ? `mesmo array RAID (${resolvedRaidLevel.toUpperCase()})`
                : planPayload.disk.mode === 'two'
                  ? `${planPayload.disk.dataDisk || 'pendente'} -> /srv/data`
                  : `${planPayload.disk.sysDisk || 'pendente'} -> /srv/data (subvolumes)`
            }
          />
          <SummaryRow
            label="Filesystems"
            value={
              planPayload.disk.profile === 'raid' || planPayload.disk.mode === 'one'
                ? 'root=btrfs, data=btrfs'
                : `root=${planPayload.disk.rootFs}, data=${planPayload.disk.dataFs}`
            }
          />
        </div>

        {layoutMode === 'raid' ? (
          <div className="mt-4">
            <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Capacidade RAID</div>
            <div className="mt-3 grid gap-3 sm:grid-cols-2">
              <Metric label="Membros" value={raidSummary.members.join(', ') || 'nenhum'} />
              <Metric label="Capacidade util" value={raidSummary.usableLabel} tone="text-cyan-100" />
              <Metric label="Capacidade bruta" value={raidSummary.rawLabel} />
              <Metric label="Tolerancia" value={raidSummary.faultTolerance} />
            </div>
          </div>
        ) : null}

        {layoutMode === 'split' ? (
          <div className="mt-4">
            <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-400">Capacidade split</div>
            <div className="mt-3 grid gap-3 sm:grid-cols-2">
              <Metric label="Sistema" value={splitSummary.systemDisk || 'pendente'} />
              <Metric label="Dados" value={splitSummary.dataDisk || 'pendente'} />
              <Metric label="Bruto somado" value={splitSummary.rawLabel} />
              <Metric label="Mount de dados" value="/srv/data" tone="text-emerald-100" />
            </div>
          </div>
        ) : null}

        {layoutMode === 'single' ? (
          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            <Metric label="Disco raiz" value={planPayload.disk.sysDisk || 'pendente'} />
            <Metric label="Dados" value="/srv/data no mesmo BTRFS" tone="text-emerald-100" />
          </div>
        ) : null}

        <div className={`mt-4 rounded-2xl border p-4 text-sm ${storageIssues.length > 0 ? 'border-rose-400/20 bg-rose-400/10 text-rose-100' : 'border-emerald-400/20 bg-emerald-400/10 text-emerald-100'}`}>
          <div className="text-xs font-semibold uppercase tracking-[0.22em] text-white/80">5. Validacao explicita</div>
          {storageIssues.length > 0 ? (
            <ul className="mt-3 space-y-2">
              {storageIssues.map((issue) => <li key={issue}>- {issue}</li>)}
            </ul>
          ) : (
            <div className="mt-3">Sem inconsistencias bloqueantes para o layout atual.</div>
          )}
          {storageWarnings.length > 0 ? (
            <div className="mt-4 rounded-xl border border-amber-400/20 bg-amber-400/10 p-3 text-amber-100">
              <div className="font-semibold text-amber-50">Avisos</div>
              <ul className="mt-2 space-y-1">
                {storageWarnings.map((warning) => <li key={warning}>- {warning}</li>)}
              </ul>
            </div>
          ) : null}
        </div>

        <div className="mt-4 rounded-2xl border border-white/10 bg-white/[0.03] p-4 text-sm text-slate-300">
          <div className="font-semibold text-white">Estado persistido</div>
          <pre className="mt-3 overflow-x-auto rounded-xl border border-white/10 bg-slate-950/70 p-3 text-xs text-slate-300">
            {JSON.stringify(planPayload.disk, null, 2)}
          </pre>
        </div>
      </section>
    </div>
  );
}
