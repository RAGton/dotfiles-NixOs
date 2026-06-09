import React from 'react';

export default function Source({ wizard, onChange }) {
  return (
    <div className="wizard-content">
      <h2 className="text-2xl font-bold mb-4">Fonte de Instalacao</h2>
      <p className="text-gray-400 mb-8">
        Escolha de onde os artefatos de instalacao serao obtidos.
      </p>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Offline Card */}
        <button
          type="button"
          className={`p-6 rounded-xl border-2 text-left transition-all ${
            wizard.sourceKind === 'offline-defaults'
              ? 'border-blue-500 bg-blue-500/10'
              : 'border-gray-700 bg-gray-800/50 hover:border-gray-600'
          }`}
          onClick={() => onChange({ sourceKind: 'offline-defaults' })}
        >
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-xl font-bold">Offline defaults</h3>
            {wizard.sourceKind === 'offline-defaults' && (
              <span className="text-blue-500">Ativo</span>
            )}
          </div>
          <p className="text-gray-400 text-sm">
            Instala o sistema base contido na ISO sem necessidade de internet para pacotes essenciais.
          </p>
        </button>

        {/* GitHub Card - Disabled P1 */}
        <div
          className="p-6 rounded-xl border-2 border-gray-800 bg-gray-900/50 opacity-50 cursor-not-allowed relative"
          aria-disabled="true"
          role="button"
        >
          <div className="absolute top-4 right-4 bg-yellow-500/20 text-yellow-500 text-xs px-2 py-1 rounded">
            Previsto para P2
          </div>
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-xl font-bold">GitHub /etc/kryonixos</h3>
          </div>
          <p className="text-gray-400 text-sm">
            Clona as configuracoes de um repositorio remoto. Disponivel na proxima versao.
          </p>
          <p className="text-gray-500 text-xs mt-2">
            A instalacao continuara com source.kind=&quot;offline-defaults&quot;.
          </p>
        </div>
      </div>
    </div>
  );
}
