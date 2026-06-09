import React from 'react';

export default function HostSelection({ wizard, onChange, validation }) {
  const error = validation?.fieldErrors?.hostName;

  return (
    <div className="wizard-content">
      <h2 className="text-2xl font-bold mb-4">Identificação da Máquina</h2>
      <p className="text-gray-400 mb-8">
        Defina o nome pelo qual este computador será conhecido na rede.
      </p>

      <div className="bg-gray-800/50 border border-gray-700 p-6 rounded-xl max-w-lg">
        <label className="block text-sm font-medium text-gray-300 mb-2">
          Hostname
        </label>
        <input
          type="text"
          value={wizard.hostName}
          onChange={(e) => onChange({ hostName: e.target.value })}
          className={`w-full bg-gray-900 border ${error ? 'border-red-500' : 'border-gray-700'} rounded-lg px-4 py-2 text-white focus:outline-none focus:border-blue-500`}
          placeholder="ex: kryonix-server"
        />
        {error && <p className="text-red-400 text-sm mt-2">{error}</p>}
        
        <div className="mt-4 text-sm text-gray-500 bg-black/30 p-4 rounded-lg">
          <p><strong>Nota:</strong> O nome escolhido aqui sera o nome do host final.</p>
          <p className="mt-2 text-amber-500/80">
            Em P1 a fonte e <strong>offline (ISO base)</strong>. A integracao com repositorio
            GitHub remoto esta em construcao e ainda nao e usada neste instalador.
          </p>
        </div>
      </div>
    </div>
  );
}
