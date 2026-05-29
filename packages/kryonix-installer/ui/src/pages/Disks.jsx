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
    { id: 'manual', label: 'Manual',      desc: 'Particionamento customizado · controle total de montagem' },
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
          {layoutMode === m.id && m.id === 'manual' && (
            <div style={{ fontSize: 11, color: 'var(--primary)', marginTop: 6 }}>
              ✓ Modo manual ativado. Configure as partições na aba Manual.
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

/* ── aba Manual ── */

function PartitionModal({ onClose, onSave, initialData, eligibleDisks }) {
  const [formData, setFormData] = useState(initialData || {
    device: eligibleDisks[0]?.path || '',
    mountpoint: '',
    fstype: 'ext4',
    size: '10G',
    format: true
  });

  const isValid = formData.device && formData.mountpoint && formData.size;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content glass-panel" style={{ width: 420 }} onClick={e => e.stopPropagation()}>
        <h3 className="modal-title">{initialData ? 'Editar Partição' : 'Nova Partição'}</h3>
        
        <div className="form-group">
          <label>Disco Alvo</label>
          <select 
            value={formData.device} 
            onChange={e => setFormData({...formData, device: e.target.value})}
            className="input-shell"
            style={{ width: '100%' }}
          >
            {eligibleDisks.map(d => (
              <option key={d.path} value={d.path}>{d.path} ({bytesToGb(d.size_bytes)} GB)</option>
            ))}
          </select>
        </div>

        <div className="form-group">
          <label>Ponto de Montagem</label>
          <input 
            type="text" 
            placeholder="Ex: /, /home, /boot/efi"
            value={formData.mountpoint}
            onChange={e => setFormData({...formData, mountpoint: e.target.value})}
            className="input-shell"
            style={{ width: '100%' }}
          />
        </div>

        <div className="form-grid">
          <div className="form-group">
            <label>Filesystem</label>
            <select 
              value={formData.fstype}
              onChange={e => setFormData({...formData, fstype: e.target.value})}
              className="input-shell"
              style={{ width: '100%' }}
            >
              <option value="ext4">ext4</option>
              <option value="btrfs">btrfs</option>
              <option value="vfat">vfat (EFI)</option>
              <option value="xfs">xfs</option>
              <option value="swap">swap</option>
            </select>
          </div>
          <div className="form-group">
            <label>Tamanho</label>
            <input 
              type="text" 
              placeholder="Ex: 512M, 20G, 100%"
              value={formData.size}
              onChange={e => setFormData({...formData, size: e.target.value})}
              className="input-shell"
              style={{ width: '100%' }}
            />
          </div>
        </div>

        <label className="flex-row gap-8" style={{ marginTop: 8, cursor: 'pointer', userSelect: 'none' }}>
          <input 
            type="checkbox" 
            checked={formData.format}
            onChange={e => setFormData({...formData, format: e.target.checked})}
          />
          <span style={{ fontSize: 13, color: 'var(--text2)' }}>Formatar partição (cria novo FS)</span>
        </label>

        <div className="modal-actions">
          <button className="btn-secondary" onClick={onClose}>Cancelar</button>
          <button 
            className="btn-primary" 
            disabled={!isValid} 
            onClick={() => onSave(formData)}
          >
            {initialData ? 'Atualizar' : 'Adicionar'}
          </button>
        </div>
      </div>
    </div>
  );
}

function TabManual({ wizard, onChange, eligibleDisks }) {
  const [showModal, setShowModal] = useState(false);
  const [editingIndex, setEditingIndex] = useState(-1);
  const manualParts = wizard.manualPartitions || [];

  const handleAdd = () => {
    setEditingIndex(-1);
    setShowModal(true);
  };

  const handleEdit = (index) => {
    setEditingIndex(index);
    setShowModal(true);
  };

  const handleRemove = (index) => {
    const next = [...manualParts];
    next.splice(index, 1);
    onChange({ manualPartitions: next });
  };

  const handleSave = (part) => {
    const next = [...manualParts];
    if (editingIndex >= 0) {
      next[editingIndex] = part;
    } else {
      next.push(part);
    }
    onChange({ manualPartitions: next });
    setShowModal(false);
  };

  return (
    <div className="manual-partition-container">
      <div className="flex-between" style={{ marginBottom: 16 }}>
        <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--text)' }}>Plano de Particionamento</div>
        <button className="btn-primary" style={{ padding: '6px 12px', fontSize: 12 }} onClick={handleAdd}>
          + Nova Partição
        </button>
      </div>

      <div className="manual-table-wrapper">
        <table className="manual-table">
          <thead>
            <tr>
              <th>Disco</th>
              <th>Montagem</th>
              <th>FS</th>
              <th>Tamanho</th>
              <th>Fmt</th>
              <th>Ações</th>
            </tr>
          </thead>
          <tbody>
            {manualParts.length === 0 ? (
              <tr>
                <td colSpan="6" style={{ textAlign: 'center', color: 'var(--text3)', padding: '32px 16px' }}>
                  Nenhuma partição customizada definida. <br/>
                  <span style={{ fontSize: 11, marginTop: 8, display: 'block' }}>
                    Adicione pelo menos / e /boot/efi para prosseguir.
                  </span>
                </td>
              </tr>
            ) : (
              manualParts.map((p, i) => (
                <tr key={i}>
                  <td style={{ fontSize: 11 }}>{p.device.split('/').pop()}</td>
                  <td><code className="code-pill">{p.mountpoint}</code></td>
                  <td>{p.fstype}</td>
                  <td>{p.size}</td>
                  <td>{p.format ? '✓' : '✗'}</td>
                  <td>
                    <div style={{ display: 'flex', gap: 8 }}>
                      <button className="btn-icon" title="Editar" onClick={() => handleEdit(i)}>✎</button>
                      <button className="btn-icon danger" title="Remover" onClick={() => handleRemove(i)}>✕</button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {showModal && (
        <PartitionModal
          onClose={() => setShowModal(false)}
          onSave={handleSave}
          initialData={editingIndex >= 0 ? manualParts[editingIndex] : null}
          eligibleDisks={eligibleDisks}
        />
      )}
    </div>
  );
}

/* ── abas placeholder ── */

function TabPlaceholder({ name }) {
  return (
    <div className="tab-placeholder">
      <span style={{ fontSize: 22, color: 'var(--border2)' }}>◈</span>
      <span>{name} — em desenvolvimento (RAID advanced UI)</span>
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
  const layoutMode     = wizard.diskProfile === 'raid' ? 'raid' : wizard.diskProfile === 'manual' ? 'manual' : wizard.diskMode === 'two' ? 'split' : 'single';
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
    : layoutMode === 'split' ? splitValidation.blockingReasons
    : layoutMode === 'manual' ? [] // Validação específica via validateStep
    : singleValidation.blockingReasons;
  const storageWarnings = layoutMode === 'raid' ? raidValidation.warnings
    : layoutMode === 'split' ? splitValidation.warnings
    : layoutMode === 'manual' ? []
    : singleValidation.warnings;

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
    } else if (nextMode === 'manual') {
      onChange({ diskProfile: 'manual', diskMode: 'one', sysDisk: wizard.sysDisk || firstEligible, dataDisk: '', selectedDisks: [wizard.sysDisk || firstEligible] });
      setActiveTab(2); // Jump to Manual tab
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
        {activeTab === 2 && (
          <TabManual
            wizard={wizard}
            onChange={onChange}
            eligibleDisks={eligibleDisks}
          />
        )}
        {activeTab === 3 && <TabPlaceholder name="RAID" />}
      </div>

    </div>
  );
}

