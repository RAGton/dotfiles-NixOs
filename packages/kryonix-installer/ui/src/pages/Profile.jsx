import React from 'react';
import { PROFILE_CATALOG, getFeaturesForProfile } from '../data/profileCatalog.js';

export default function Profile({ wizard, onChange }) {
  const handleProfileSelect = (profileId) => {
    const defaultFeatures = getFeaturesForProfile(profileId);
    onChange({ 
      profileId,
      selectedFeatures: defaultFeatures
    });
  };

  return (
    <div className="wizard-content">
      <h2 className="text-2xl font-bold mb-4">Perfil de Sistema</h2>
      <p className="text-gray-400 mb-8">
        Escolha um perfil para pré-carregar as features recomendadas para o seu caso de uso.
      </p>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {PROFILE_CATALOG.map((profile) => {
          const isActive = wizard.profileId === profile.id;
          return (
            <div
              key={profile.id}
              onClick={() => handleProfileSelect(profile.id)}
              className={`p-6 rounded-xl border-2 cursor-pointer transition-all ${
                isActive
                  ? 'border-blue-500 bg-blue-500/10'
                  : 'border-gray-700 bg-gray-800/50 hover:border-gray-600'
              }`}
            >
              <div className="flex justify-between items-start mb-2">
                <h3 className="text-lg font-bold text-white">{profile.name}</h3>
                {isActive && (
                  <div className="w-3 h-3 rounded-full bg-blue-500 shadow-[0_0_8px_rgba(59,130,246,0.8)]"></div>
                )}
              </div>
              <p className="text-sm text-gray-400">{profile.description}</p>
            </div>
          );
        })}
      </div>
    </div>
  );
}
