import { useEffect, useState } from 'react';

function HwCard({ icon, label, value, sub }) {
  return (
    <div className="hw-card">
      <div className="hw-card-label">{icon} {label}</div>
      <div className="hw-card-value" title={value ?? '—'}>{value ?? '—'}</div>
      {sub && <div className="hw-card-sub">{sub}</div>}
    </div>
  );
}

function StatusRow({ icon, label, value, ok }) {
  const valueColor = ok === true
    ? 'var(--success)'
    : ok === false
      ? 'var(--danger)'
      : 'var(--text2)';

  return (
    <div className="status-row">
      <span style={{ fontSize: 13, flexShrink: 0 }}>{icon}</span>
      <span style={{ fontSize: 12, color: 'var(--text2)', flex: 1 }}>{label}</span>
      <span style={{ fontSize: 11, fontWeight: 600, color: valueColor }}>{value ?? '—'}</span>
    </div>
  );
}

export default function Eula({ uiState, onChange, validation }) {
  const [probe, setProbe]       = useState(null);
  const [scanning, setScanning] = useState(true);   // true enquanto carrega
  const [offline, setOffline]   = useState(false);  // true se backend inacessível

  useEffect(() => {
    let active = true;
    fetch('/probe')
      .then(r => (r.ok ? r.json() : Promise.reject(r.status)))
      .then(data => {
        if (active) { setProbe(data); setScanning(false); }
      })
      .catch(() => {
        if (active) { setScanning(false); setOffline(true); }
      });
    return () => { active = false; };
  }, []);

  /* ── campos do probe com fallbacks seguros ── */
  const cpu  = probe?.cpu;
  const mem  = probe?.memory;
  const disk = probe?.disks?.[0];
  const gpu  = probe?.gpu;
  const boot = probe?.boot_mode;
  const net  = probe?.network;
  const virt = probe?.virtualization;

  const cpuLabel = cpu?.model
    ? cpu.model.replace(/\(.*\)/g, '').trim().split(' ').slice(-4).join(' ')
    : null;
  const cpuSub = cpu
    ? `${cpu.cores} núcleos · ${cpu.threads} threads`
    : null;
  const memVal  = mem?.total_gb != null ? `${mem.total_gb} GB` : null;
  const memSub  = mem?.available_gb != null ? `${mem.available_gb} GB livres` : null;
  const diskVal = disk?.name ?? null;
  const diskSub = disk?.size_gb != null
    ? `${disk.size_gb} GB`
    : disk?.size ?? null;
  const gpuVal  = gpu?.name ?? (gpu ? 'Integrada' : null);
  const gpuSub  = gpu?.vram_gb ? `${gpu.vram_gb} GB VRAM` : null;

  return (
    <div className="split">

      {/* ── Coluna esquerda: hardware ── */}
      <div className="left">

        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <h2 style={{ margin: 0, fontSize: 16, fontWeight: 700, color: 'var(--text)' }}>
            Hardware detectado
          </h2>

          {scanning ? (
            <div className="scanning">
              <div className="scan-dot" />
              Detectando hardware...
            </div>
          ) : offline ? (
            <div className="scanning" style={{ color: 'var(--danger)' }}>
              <span>✗</span> Backend offline — rode via ISO
            </div>
          ) : (
            <div className="scanning" style={{ color: 'var(--success)' }}>
              <span>✓</span> Sonda concluída
            </div>
          )}
        </div>

        <div className="hw-grid">
          <HwCard icon="⬡" label="CPU"   value={cpuLabel} sub={cpuSub} />
          <HwCard icon="▣" label="RAM"   value={memVal}   sub={memSub} />
          <HwCard icon="◈" label="Disco" value={diskVal}  sub={diskSub} />
          <HwCard icon="◇" label="GPU"   value={gpuVal}   sub={gpuSub} />
        </div>

        <div className="status-rows">
          <StatusRow
            icon="⬛"
            label="Boot mode"
            value={boot ?? '—'}
            ok={boot === 'UEFI' ? true : boot === 'BIOS' ? null : null}
          />
          <StatusRow
            icon="◎"
            label="Internet"
            value={net?.internet ? 'Conectado' : net ? 'Offline' : '—'}
            ok={net?.internet === true ? true : net ? false : null}
          />
          <StatusRow
            icon="⬡"
            label="Virtualização"
            value={virt ?? '—'}
            ok={null}
          />
          <StatusRow
            icon="◈"
            label="Interface"
            value={net?.interface ?? '—'}
            ok={null}
          />
        </div>

      </div>

      {/* ── Coluna direita: termos + aceite ── */}
      <div className="right">

        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0 }}>
          <h2 style={{ margin: 0, fontSize: 16, fontWeight: 700, color: 'var(--text)' }}>
            Termos de uso
          </h2>
          <p style={{ margin: 0, fontSize: 12, color: 'var(--text2)' }}>
            Leia antes de prosseguir.
          </p>
        </div>

        {/* Texto scrollável */}
        <div style={{
          flex: 1,
          minHeight: 0,
          overflowY: 'auto',
          background: 'var(--bg3)',
          border: '1px solid var(--border)',
          borderRadius: 'var(--r)',
          padding: '14px 16px',
          fontSize: 13,
          lineHeight: 1.75,
          color: 'var(--text2)',
          scrollbarWidth: 'thin',
          scrollbarColor: 'var(--border2) transparent',
        }}>
          <p style={{ margin: 0 }}><strong style={{ color: 'var(--text)' }}>1.</strong> O sistema será instalado com foco em uso de servidor.</p>
          <p style={{ marginTop: 10 }}><strong style={{ color: 'var(--text)' }}>2.</strong> A etapa de particionamento <strong>pode destruir dados existentes</strong> no disco selecionado.</p>
          <p style={{ marginTop: 10 }}><strong style={{ color: 'var(--text)' }}>3.</strong> Configurações incorretas de rede podem tornar o servidor inacessível remotamente.</p>
          <p style={{ marginTop: 10 }}><strong style={{ color: 'var(--text)' }}>4.</strong> O operador é responsável por confirmar discos, interface de rede, timezone, locale e layout de teclado.</p>
          <p style={{ marginTop: 10 }}><strong style={{ color: 'var(--text)' }}>5.</strong> Esta UI reduz erros, mas não elimina a necessidade de revisão final antes da instalação.</p>
          <p style={{ marginTop: 10 }}><strong style={{ color: 'var(--text)' }}>6.</strong> A instalação irá <strong>apagar e reparticionar</strong> o disco selecionado. Faça backup antes de continuar.</p>
        </div>

        {/* Checkbox de aceite */}
        <div style={{
          background: 'var(--bg3)',
          border: `1px solid ${uiState.eulaAccepted ? 'var(--primary)' : 'var(--border)'}`,
          borderRadius: 'var(--r)',
          padding: '12px 14px',
          flexShrink: 0,
          transition: 'border-color 0.2s',
        }}>
          <label style={{ display: 'flex', alignItems: 'flex-start', gap: 10, cursor: 'pointer' }}>
            <input
              type="checkbox"
              style={{
                marginTop: 2,
                width: 15,
                height: 15,
                flexShrink: 0,
                accentColor: 'var(--primary)',
              }}
              checked={uiState.eulaAccepted}
              onChange={e => onChange({ eulaAccepted: e.target.checked })}
            />
            <div>
              <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--text)' }}>
                Li e aceito os termos acima
              </div>
              <div style={{ fontSize: 12, color: 'var(--text2)', marginTop: 3 }}>
                Confirmo que tenho backup dos dados importantes do disco selecionado.
              </div>
            </div>
          </label>
        </div>

        {/* Erro de validação */}
        {validation?.blockingIssues?.length > 0 && (
          <div style={{
            flexShrink: 0,
            fontSize: 12,
            color: 'var(--danger)',
            padding: '8px 12px',
            background: 'var(--bg3)',
            borderRadius: 'var(--r)',
            border: '1px solid #f38ba830',
          }}>
            {validation.blockingIssues[0]}
          </div>
        )}

      </div>
    </div>
  );
}
