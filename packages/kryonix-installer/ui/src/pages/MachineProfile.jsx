import React from 'react';
import { PROFILE_CATALOG, getFeaturesForProfile } from '../data/profileCatalog.js';
import { FEATURE_CATALOG } from '../data/featureCatalog.js';

export default function MachineProfile({ wizard, onChange }) {
  const handleProfileSelect = (profileId) => {
    const defaultFeatures = getFeaturesForProfile(profileId);
    onChange({
      profileId,
      selectedFeatures: defaultFeatures
    });
  };

  const activeProfile = PROFILE_CATALOG.find(p => p.id === wizard.profileId);
  const activeFeatures = activeProfile ? getFeaturesForProfile(activeProfile.id) : [];

  const srvDataStatus = (profile) => {
    if (profile.enableSrvData) return { label: 'Obrigatório', color: 'text-emerald-400', bg: 'bg-emerald-400/10', border: 'border-emerald-400/30' };
    if (profile.srvDataRecommended) return { label: 'Recomendado', color: 'text-amber-400', bg: 'bg-amber-400/10', border: 'border-amber-400/30' };
    return { label: 'Não ativado', color: 'text-slate-500', bg: 'bg-slate-500/10', border: 'border-slate-500/30' };
  };

  const modeLabel = (mode) => mode === 'desktop' ? 'Desktop' : 'Server';

  const getFeatureStats = (profileId) => {
    const features = getFeaturesForProfile(profileId);
    const featureObjs = features.map(id => FEATURE_CATALOG.find(f => f.id === id)).filter(Boolean);
    const totalDisk = featureObjs.reduce((sum, f) => sum + (f.storage?.estimatedDiskGb || 0), 0);
    const maxRam = Math.max(0, ...featureObjs.map(f => f.hardware?.minRamGb || 0));
    return { count: features.length, totalDisk, maxRam };
  };

  return (
    <div className="wizard-content space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Perfil da Máquina</h2>
        <p className="text-gray-400 mt-2">
          Escolha o perfil que melhor descreve o uso principal desta máquina.
        </p>
      </div>

      <div className="rounded-2xl border border-blue-500/20 bg-blue-500/5 p-4 text-sm text-blue-200">
        <span className="font-bold">Este perfil influencia:</span> features de sistema, features de usuário, layout de disco, ativação de /srv/data e serviços instalados.
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {PROFILE_CATALOG.map((profile) => {
          const isActive = wizard.profileId === profile.id;
          const srv = srvDataStatus(profile);
          const stats = getFeatureStats(profile.id);

          return (
            <button
              key={profile.id}
              onClick={() => handleProfileSelect(profile.id)}
              className={`text-left p-5 rounded-xl border-2 transition-all ${
                isActive
                  ? 'border-blue-500 bg-blue-500/10 shadow-[0_0_24px_rgba(59,130,246,0.15)]'
                  : 'border-gray-700 bg-gray-800/50 hover:border-gray-500 hover:bg-gray-800/80'
              }`}
            >
              <div className="flex justify-between items-start mb-3">
                <div className="flex items-center gap-2">
                  <span className={`px-2 py-0.5 text-[10px] uppercase font-bold tracking-wider rounded ${
                    profile.mode === 'desktop' ? 'bg-violet-500/20 text-violet-300' : 'bg-cyan-500/20 text-cyan-300'
                  }`}>
                    {modeLabel(profile.mode)}
                  </span>
                  <h3 className="text-lg font-bold text-white">{profile.name}</h3>
                </div>
                {isActive && (
                  <div className="w-3 h-3 rounded-full bg-blue-500 shadow-[0_0_8px_rgba(59,130,246,0.8)] flex-shrink-0" />
                )}
              </div>

              <p className="text-sm text-gray-400 mb-3">{profile.description}</p>

              <div className="flex flex-wrap gap-1.5 mb-3">
                {profile.badges?.map(badge => (
                  <span key={badge} className="px-2 py-0.5 text-[10px] uppercase font-bold tracking-wider rounded bg-gray-700/80 text-gray-300">
                    {badge}
                  </span>
                ))}
              </div>

              <div className="flex items-center gap-2 mb-2">
                <span className={`px-2 py-0.5 text-[10px] uppercase font-bold tracking-wider rounded border ${srv.bg} ${srv.color} ${srv.border}`}>
                  /srv/data: {srv.label}
                </span>
              </div>

              <div className="flex gap-3 text-xs text-gray-500">
                <span>{stats.count} features</span>
                {stats.totalDisk > 0 && <span>{stats.totalDisk} GB disco</span>}
                {stats.maxRam > 0 && <span>min {stats.maxRam} GB RAM</span>}
              </div>
            </button>
          );
        })}
      </div>

      {activeProfile && activeFeatures.length > 0 && (
        <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
          <h3 className="text-sm font-bold uppercase tracking-wider text-slate-400 mb-3">
            Features incluídas no perfil «{activeProfile.name}»
          </h3>
          <div className="flex flex-wrap gap-2">
            {activeFeatures.map(featId => {
              const feat = FEATURE_CATALOG.find(f => f.id === featId);
              return (
                <span
                  key={featId}
                  className={`px-2.5 py-1 text-xs rounded-lg font-medium ${
                    feat?.level === 'system'
                      ? 'bg-blue-500/15 text-blue-300 border border-blue-500/20'
                      : 'bg-purple-500/15 text-purple-300 border border-purple-500/20'
                  }`}
                >
                  {feat?.name || featId}
                  {feat?.storage?.requiresSrvData && (
                    <span className="ml-1 text-amber-400">/srv</span>
                  )}
                </span>
              );
            })}
          </div>
        </div>
      )}

      {activeProfile && activeFeatures.length === 0 && (
        <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5 text-sm text-gray-400">
          Perfil Custom — você escolherá cada feature manualmente nas próximas etapas.
        </div>
      )}
    </div>
  );
}
