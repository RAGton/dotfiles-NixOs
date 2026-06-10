import React from 'react';
import { FEATURE_CATALOG } from '../data/featureCatalog.js';

export default function UserFeatures({ wizard, onChange }) {
  const userFeatures = FEATURE_CATALOG.filter(f => f.level === 'user');
  const domains = [...new Set(userFeatures.map(f => f.domain))];

  const handleToggle = (featureId) => {
    const selected = new Set(wizard.selectedFeatures || []);
    if (selected.has(featureId)) {
      selected.delete(featureId);
    } else {
      selected.add(featureId);
    }
    onChange({ selectedFeatures: Array.from(selected) });
  };

  return (
    <div className="wizard-content">
      <h2 className="text-2xl font-bold mb-4">Features de Usuário</h2>
      <p className="text-gray-400 mb-8">
        Personalize editores, shells, temas e ferramentas de desenvolvimento que serão instaladas para o seu usuário.
      </p>

      <div className="space-y-8">
        {domains.map(domain => {
          const featuresInDomain = userFeatures.filter(f => f.domain === domain);
          if (featuresInDomain.length === 0) return null;

          return (
            <div key={domain} className="bg-gray-800/30 border border-gray-700/50 p-6 rounded-xl">
              <h3 className="text-lg font-bold text-white mb-4 uppercase tracking-wider text-sm">{featuresInDomain[0].category}</h3>
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                {featuresInDomain.map(feature => {
                  const isSelected = wizard.selectedFeatures?.includes(feature.id);
                  return (
                    <label 
                      key={feature.id}
                      className={`flex items-start space-x-4 p-4 rounded-lg border cursor-pointer transition-all ${
                        isSelected ? 'border-purple-500 bg-purple-500/10' : 'border-gray-700 bg-gray-900/50 hover:border-gray-600'
                      }`}
                    >
                      <input
                        type="checkbox"
                        checked={isSelected}
                        onChange={() => handleToggle(feature.id)}
                        className="form-checkbox mt-1 h-5 w-5 text-purple-500 bg-gray-900 border-gray-700 rounded focus:ring-purple-500 focus:ring-offset-gray-900"
                      />
                      <div className="flex-1">
                        <div className="flex justify-between items-start">
                          <span className="font-bold text-white block mb-1">{feature.name}</span>
                        </div>
                        <p className="text-xs text-gray-400 mb-2">{feature.description}</p>
                        
                        {feature.badges && feature.badges.length > 0 && (
                          <div className="flex flex-wrap gap-2 mt-2">
                            {feature.badges.map(badge => (
                              <span key={badge} className="px-2 py-0.5 text-[10px] uppercase font-bold tracking-wider rounded bg-gray-700 text-gray-300">
                                {badge}
                              </span>
                            ))}
                          </div>
                        )}
                      </div>
                    </label>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
