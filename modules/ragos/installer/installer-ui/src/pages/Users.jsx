import { useMemo } from 'react';
import FieldError from '../components/FieldError.jsx';

function passwordStrength(password) {
  let score = 0;
  if (password.length >= 12) score += 1;
  if (/[a-z]/.test(password)) score += 1;
  if (/[A-Z]/.test(password)) score += 1;
  if (/[0-9]/.test(password)) score += 1;
  if (/[^A-Za-z0-9\s]/.test(password)) score += 1;
  const pct = Math.round((score / 5) * 100);
  const label = pct >= 80 ? 'forte' : pct >= 60 ? 'média' : 'fraca';
  return { pct, label };
}

export default function Users({ wizard, onChange, validation }) {
  const strength = useMemo(() => passwordStrength(wizard.adminPassword || ''), [wizard.adminPassword]);
  const sshKeys = useMemo(
    () => String(wizard.adminAuthorizedKeys || '').split('\n').map((line) => line.trim()).filter(Boolean),
    [wizard.adminAuthorizedKeys],
  );
  const fieldErrors = validation?.fieldErrors || {};

  return (
    <div className="grid h-full min-h-0 gap-6 lg:grid-cols-[1fr_0.9fr]">
      <section className="section-panel min-h-0 overflow-y-auto">
        <div className="mb-6">
          <h2 className="text-xl font-black text-white">Conta administrativa</h2>
          <p className="mt-2 text-sm text-slate-300">Defina o usuário principal do servidor e uma senha forte compatível com o backend do instalador.</p>
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label className="label-text" htmlFor="adminUser">Usuário</label>
            <input id="adminUser" className="input-shell" value={wizard.adminUser} onChange={(e) => onChange({ adminUser: e.target.value })} />
            <FieldError message={fieldErrors.adminUser} />
          </div>
          <div>
            <label className="label-text" htmlFor="adminUid">UID</label>
            <input id="adminUid" type="number" className="input-shell" value={wizard.adminUid} onChange={(e) => onChange({ adminUid: Number(e.target.value || 0) })} />
            <FieldError message={fieldErrors.adminUid} />
          </div>
          <div className="sm:col-span-2">
            <label className="label-text" htmlFor="adminEmail">E-mail</label>
            <input id="adminEmail" className="input-shell" value={wizard.adminEmail} onChange={(e) => onChange({ adminEmail: e.target.value })} />
            <FieldError message={fieldErrors.adminEmail} />
          </div>
          <div>
            <label className="label-text" htmlFor="adminPassword">Senha</label>
            <input id="adminPassword" type="password" className="input-shell" value={wizard.adminPassword} onChange={(e) => onChange({ adminPassword: e.target.value })} />
            <FieldError message={fieldErrors.adminPassword} />
          </div>
          <div>
            <label className="label-text" htmlFor="adminPasswordConfirm">Confirmar senha</label>
            <input id="adminPasswordConfirm" type="password" className="input-shell" value={wizard.adminPasswordConfirm} onChange={(e) => onChange({ adminPasswordConfirm: e.target.value })} />
            <FieldError message={fieldErrors.adminPasswordConfirm} />
          </div>
        </div>

        <div className="mt-5 rounded-2xl border border-white/10 bg-white/[0.04] p-4">
          <div className="flex items-center justify-between gap-4">
            <span className="text-sm font-semibold text-white">Força da senha</span>
            <span className="text-sm font-bold text-cyan-300">{strength.label}</span>
          </div>
          <div className="mt-3 h-2.5 overflow-hidden rounded-full bg-white/10">
            <div className="h-full rounded-full bg-gradient-to-r from-rose-400 via-amber-300 to-emerald-400" style={{ width: `${strength.pct}%` }} />
          </div>
        </div>
      </section>

      <section className="section-panel flex min-h-0 flex-col overflow-hidden">
        <div className="mb-4">
          <h3 className="text-lg font-bold text-white">Chaves SSH autorizadas</h3>
          <p className="mt-1 text-sm text-slate-400">Uma chave pública por linha. Elas serão escritas em `adminAuthorizedKeys` no plano final.</p>
        </div>

        <textarea
          className="input-shell min-h-[220px] flex-1 resize-none font-mono text-xs leading-6"
          value={wizard.adminAuthorizedKeys}
          onChange={(e) => onChange({ adminAuthorizedKeys: e.target.value })}
          placeholder="ssh-ed25519 AAAAC3... usuario@host"
        />

        <div className="mt-4 rounded-2xl border border-white/10 bg-slate-950/60 p-4">
          <div className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-400">Resumo SSH</div>
          <div className="mt-2 text-lg font-bold text-white">{sshKeys.length} chave(s)</div>
          <div className="mt-2 max-h-[120px] overflow-y-auto text-xs text-slate-400">
            {sshKeys.length === 0 ? 'Nenhuma chave informada.' : sshKeys.map((key, index) => <div key={`${index}-${key.slice(0, 12)}`} className="mb-1 truncate">{key}</div>)}
          </div>
        </div>
      </section>
    </div>
  );
}
