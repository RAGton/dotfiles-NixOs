import { useEffect, useMemo, useState } from 'react';
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

const TABS = ['Discos', 'Layout', 'Manual', 'RAID'];

/* ── helpers ── */

function arraysEqual(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

function uniqueStrings(items) {
  return Array.from(new Set((Array.isArray(items) ? items : []).filter(Boolean)));
}

function bytesToGb(bytes) {
  const n = Number(bytes);
  return Number.isFinite(n) ? (n / 1_073_741_824).toFixed(0) : '?';
}

/** CSS class para colorir o segmento de partição */
function segClass(part) {
  const mp = (part.mountpoint || '').toLowerCase();
  const fs = (part.fstype || '').toLowerCase();
  if (mp === '/boot/efi' || mp === '/efi' || fs === 'vfat') return 'pseg-efi';
  if (mp === '/' || mp === '/root') return 'pseg-root';
  if (mp === '/home') return 'pseg-home';
  if (fs === 'swap') return 'pseg-swap';
  if (fs === 'ntfs') return 'pseg-ntfs';
  if (mp.startsWith('/srv') || mp.startsWith('/data')) return 'pseg-data';
  return 'pseg-other';
}

/** Formata label legível para a partição */
function partLabel(part) {
  if (part.mountpoint) return part.mountpoint;
  if (part.label) return part.label;
  if (part.fstype) return part.fstype.toUpperCase();
  return part.name;
}

/* ── sub-componentes ── */

function PartitionBar({ partitions, totalBytes }) {
  if (!partitions || partitions.length === 0) {
    return (
      <div className="partition-bar">
        <div className="partition-seg pseg-free" style={{ flex: 1 }} title="Sem partições detectadas" />
      </div>
    );
  }

  const total = Number(totalBytes) || partitions.reduce((s, p) => s + Number(p.size || 0), 0);

  return (
    <div>
      <div className="partition-bar">
        {partitions.map((p, i) => {
          const size = Number(p.size || 0);
          const pct = total > 0 ? Math.max((size / total) * 100, 1) : 0;
          return (
            <div
              key={i}
              className={`partition-seg ${segClass(p)}`}
              style={{ flex: `${pct} 0 0` }}
              title={`${partLabel(p)} — ${bytesToGb(p.size)} GB`}
            />
          );
        })}
      </div>
      <div className="partition-legend">
        {partitions.map((p, i) => (
          <div key={i} className="legend-item">
            <div className={`legend-dot ${segClass(p)}`} />
            <span>{partLabel(p)} {bytesToGb(p.size)}G</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function DiskCard({ disk, selected, partData, onClick }) {
  const partitions = partData?.blockdevices?.[0]?.children ?? [];
  const totalSize = partData?.blockdevices?.[0]?.size ?? disk.size_bytes ?? disk.size;

  return (
    <div
      className={`disk-card${selected ? ' selected' : ''}`}
      onClick={onClick}
      role="button"
      tabIndex={0}
      onKeyDown={e => (e.key === 'Enter' || e.key === ' ') && onClick?.()}
    >
      <div className="disk-card-header">
        <div>
          <span className="disk-name">{disk.path ?? `/dev/${disk.name}`}</span>
          {disk.model && (
            <span style={{ fontSize: 11, color: 'var(--text3)', marginLeft: 8 }}>{disk.model}</span>
          )}
        </div>
        <span className="disk-size">{disk.size ?? `${bytesToGb(disk.size_bytes)} GB`}</span>
      </div>

      <PartitionBar partitions={partitions} totalBytes={totalSize} />

      {selected && (
        <div style={{ fontSize: 11, color: 'var(--primary)', marginTop: 6 }}>
          ✓ Disco selecionado para instalação
        </div>
      )}
    </div>
  );
}

/* ── aba Discos ── */

function TabDiscos({ diskInventory, loadingDisks, diskError, partitions, wizard, onChange, eligibleDisks, eligiblePaths }) {
  if (loadingDisks) {
    return (
      <div className="scanning" style={{ marginTop: 24, justifyContent: 'center' }}>
        <div className="scan-dot" />
        Detectando discos...
      </div>
    );
  }

  if (diskError) {
    return (
      <div style={{ padding: '16px 0', fontSize: 13, color: 'var(--danger)' }}>
        ✗ {diskError}
      </div>
    );
  }

  if (diskInventory.length === 0) {
    return (
      <div style={{ padding: '24px 0', fontSize: 13, color: 'var(--text3)', textAlign: 'center' }}>
        Nenhum disco detectado.
      </div>
    );
  }

  return (
    <div className="disk-grid">
      {diskInventory.map(disk => (
        <DiskCard
          key={disk.path}
          disk={disk}
          selected={wizard.sysDisk === disk.path}
          partData={partitions[disk.name ?? disk.path?.split('/').pop()]}
          onClick={() => {
            if (eligiblePaths.has(disk.path)) {
              onChange({ sysDisk: disk.path, selectedDisks: [disk.path] });
            }
          }}
        />
      ))}
    </div>
  );
}

/* ── aba Layout ── */

function TabLayout({ layoutMode, onLayoutChange, wizard, diskInventory, splitSummary, raidSummary, raidOptions }) {
  const modes = [
    { id: 'single', label: 'Apagar tudo', desc: 'Um disco · EFI + / BTRFS · subvolumes @, @home, @nix, @log' },
    { id: 'split',  label: 'Dois discos', desc: 'Sistema em disco 1 · dados em /srv/data no disco 2' },
    { id: 'raid',   label: 'RAID / LVM',  desc: 'Múltiplos discos · redundância ou expansão de capacidade' },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      {modes.map(m => (
        <div
          key={m.id}
          className={`disk-card${layoutMode === m.id ? ' selected' : ''}`}
          onClick={() => onLayoutChange(m.id)}
          role="button"
          tabIndex={0}
          onKeyDown={e => (e.key === 'Enter' || e.key === ' ') && onLayoutChange(m.id)}
        >
          <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text)', marginBottom: 4 }}>{m.label}</div>
          <div style={{ fontSize: 12, color: 'var(--text2)' }}>{m.desc}</div>
          {layoutMode === m.id && (splitSummary || raidSummary) && (
            <div style={{ fontSize: 11, color: 'var(--primary)', marginTop: 6 }}>
              {m.id === 'raid' ? raidSummary?.description : splitSummary?.description}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

/* ── abas placeholder ── */

function TabPlaceholder({ name }) {
  return (
    <div className="tab-placeholder">
      <span style={{ fontSize: 22, color: 'var(--border2)' }}>◈</span>
      <span>{name} — em desenvolvimento (Commit 4)</span>
    </div>
  );
}

/* ══════════════════════════════════════════════════════════════
   COMPONENTE PRINCIPAL
══════════════════════════════════════════════════════════════ */

export default function Disks({ wizard, uiState, onChange, validation }) {
  const [activeTab, setActiveTab] = useState(0);

  /* ── discos ── */
  const [diskInventory, setDiskInventory] = useState([]);
  const [loadingDisks, setLoadingDisks]   = useState(true);
  const [diskError, setDiskError]         = useState('');

  /* ── partições por device name ── */
  const [partitions, setPartitions] = useState({});

  /* carregar lista de discos */
  useEffect(() => {
    let cancelled = false;
    setLoadingDisks(true);
    setDiskError('');

    installerApi.getDisks()
      .then(payload => {
        if (!cancelled) setDiskInventory(normalizeDiskInventory(payload.disks));
      })
      .catch(err => {
        if (!cancelled) {
          setDiskError(getInstallerApiErrorMessage(err, 'Erro ao carregar discos.'));
          setDiskInventory([]);
        }
      })
      .finally(() => { if (!cancelled) setLoadingDisks(false); });

    return () => { cancelled = true; };
  }, []);

  /* carregar partições para cada disco depois da lista chegar */
  useEffect(() => {
    if (diskInventory.length === 0) return;
    let cancelled = false;

    diskInventory.forEach(disk => {
      const devName = disk.name ?? disk.path?.split('/').pop();
      if (!devName) return;

      fetch(`/api/disks/${encodeURIComponent(devName)}/partitions`)
        .then(r => r.ok ? r.json() : Promise.reject(r.status))
        .then(data => {
          if (!cancelled) setPartitions(prev => ({ ...prev, [devName]: data }));
        })
        .catch(() => {}); // falha silenciosa — barra fica vazia
    });

    return () => { cancelled = true; };
  }, [diskInventory]);

  /* ── derived state (preservado da versão original) ── */
  const eligibleDisks  = useMemo(() => diskInventory.filter(d => d.eligible), [diskInventory]);
  const eligiblePaths  = useMemo(() => new Set(eligibleDisks.map(d => d.path)), [eligibleDisks]);
  const layoutMode     = wizard.diskProfile === 'raid' ? 'raid' : wizard.diskMode === 'two' ? 'split' : 'single';
  const raidMembers    = useMemo(() => getSelectedDiskRecords(diskInventory, wizard.selectedDisks), [diskInventory, wizard.selectedDisks]);
  const raidMemberPaths = useMemo(() => raidMembers.map(d => d.path), [raidMembers]);
  const raidOptions    = useMemo(() => getRaidOptionsForSelection(raidMembers), [raidMembers]);
  const enabledRaidOptions = useMemo(() => raidOptions.filter(o => o.enabled), [raidOptions]);
  const resolvedRaidLevel  = useMemo(() => {
    if (enabledRaidOptions.some(o => o.id === wizard.raidLevel)) return wizard.raidLevel;
    return enabledRaidOptions[0]?.id || wizard.raidLevel || 'raid1';
  }, [enabledRaidOptions, wizard.raidLevel]);

  const singleValidation = useMemo(() => validateSingleDiskLayout(diskInventory, wizard.sysDisk), [diskInventory, wizard.sysDisk]);
  const splitValidation  = useMemo(() => validateSplitDiskLayout(diskInventory, wizard.sysDisk, wizard.dataDisk), [diskInventory, wizard.sysDisk, wizard.dataDisk]);
  const raidValidation   = useMemo(() => validateRaidSelection(raidMembers, resolvedRaidLevel), [raidMembers, resolvedRaidLevel]);
  const raidSummary      = useMemo(() => buildRaidPlanSummary(raidMembers, resolvedRaidLevel), [raidMembers, resolvedRaidLevel]);
  const splitSummary     = useMemo(() => buildSplitPlanSummary(diskInventory, wizard.sysDisk, wizard.dataDisk), [diskInventory, wizard.sysDisk, wizard.dataDisk]);

  const storageIssues   = layoutMode === 'raid' ? raidValidation.blockingReasons
    : layoutMode === 'split' ? splitValidation.blockingReasons : singleValidation.blockingReasons;
  const storageWarnings = layoutMode === 'raid' ? raidValidation.warnings
    : layoutMode === 'split' ? splitValidation.warnings : singleValidation.warnings;

  /* sync state → wizard */
  useEffect(() => {
    if (loadingDisks) return;
    const firstEligible  = eligibleDisks[0]?.path || '';
    const secondEligible = eligibleDisks.find(d => d.path !== firstEligible)?.path || '';
    const patch = {};

    if (layoutMode === 'single') {
      const nextSys = eligiblePaths.has(wizard.sysDisk) ? wizard.sysDisk : firstEligible;
      if (wizard.diskProfile !== 'single') patch.diskProfile = 'single';
      if (wizard.diskMode    !== 'one')    patch.diskMode    = 'one';
      if (wizard.sysDisk     !== nextSys)  patch.sysDisk     = nextSys;
      if (wizard.dataDisk)                 patch.dataDisk    = '';
      if (!arraysEqual(wizard.selectedDisks || [], nextSys ? [nextSys] : [])) patch.selectedDisks = nextSys ? [nextSys] : [];
      if (wizard.rootFs !== 'btrfs') patch.rootFs = 'btrfs';
      if (wizard.dataFs !== 'btrfs') patch.dataFs = 'btrfs';
    }

    if (!arraysEqual(storageIssues,   uiState.storageBlockingIssues || [])) patch.storageBlockingIssues = storageIssues;
    if (!arraysEqual(storageWarnings, uiState.storageWarnings        || [])) patch.storageWarnings       = storageWarnings;
    if (Object.keys(patch).length > 0) onChange(patch);
  }, [diskInventory, eligibleDisks, eligiblePaths, layoutMode, loadingDisks,
      onChange, resolvedRaidLevel, storageIssues, storageWarnings,
      uiState.storageBlockingIssues, uiState.storageWarnings,
      wizard.dataDisk, wizard.dataFs, wizard.diskMode, wizard.diskProfile,
      wizard.raidLevel, wizard.rootFs, wizard.selectedDisks, wizard.sysDisk]);

  /* ── handler layout mode ── */
  function handleLayoutChange(nextMode) {
    const firstEligible  = eligibleDisks[0]?.path || '';
    const secondEligible = eligibleDisks.find(d => d.path !== firstEligible)?.path || '';
    if (nextMode === 'single') {
      const nextSys = eligiblePaths.has(wizard.sysDisk) ? wizard.sysDisk : firstEligible;
      onChange({ diskProfile: 'single', diskMode: 'one', sysDisk: nextSys, dataDisk: '', selectedDisks: nextSys ? [nextSys] : [], rootFs: 'btrfs', dataFs: 'btrfs' });
    } else if (nextMode === 'split') {
      const nextSys  = eligiblePaths.has(wizard.sysDisk) ? wizard.sysDisk : firstEligible;
      const nextData = eligiblePaths.has(wizard.dataDisk) && wizard.dataDisk !== nextSys ? wizard.dataDisk : secondEligible;
      onChange({ diskProfile: 'single', diskMode: 'two', sysDisk: nextSys, dataDisk: nextData, selectedDisks: uniqueStrings([nextSys, nextData]) });
    } else if (nextMode === 'raid') {
      const members = eligibleDisks.slice(0, 2).map(d => d.path);
      onChange({ diskProfile: 'raid', diskMode: 'one', sysDisk: members[0] || '', dataDisk: '', selectedDisks: members, rootFs: 'btrfs', dataFs: 'btrfs', raidLevel: resolvedRaidLevel });
    }
  }

  /* ── render ── */
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', minHeight: 0 }}>

      {/* Barra de 4 abas */}
      <div className="tab-bar">
        {TABS.map((label, i) => (
          <button
            key={label}
            type="button"
            className={`tab${activeTab === i ? ' active' : ''}`}
            onClick={() => setActiveTab(i)}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Conteúdo da aba ativa */}
      <div style={{ flex: 1, minHeight: 0, overflow: 'hidden auto' }}>
        {activeTab === 0 && (
          <TabDiscos
            diskInventory={diskInventory}
            loadingDisks={loadingDisks}
            diskError={diskError}
            partitions={partitions}
            wizard={wizard}
            onChange={onChange}
            eligibleDisks={eligibleDisks}
            eligiblePaths={eligiblePaths}
          />
        )}
        {activeTab === 1 && (
          <TabLayout
            layoutMode={layoutMode}
            onLayoutChange={handleLayoutChange}
            wizard={wizard}
            diskInventory={diskInventory}
            splitSummary={splitSummary}
            raidSummary={raidSummary}
            raidOptions={raidOptions}
          />
        )}
        {activeTab === 2 && <TabPlaceholder name="Manual" />}
        {activeTab === 3 && <TabPlaceholder name="RAID" />}
      </div>

    </div>
  );
}
