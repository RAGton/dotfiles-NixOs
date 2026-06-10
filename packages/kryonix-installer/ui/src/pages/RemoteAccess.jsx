import React from 'react';

export default function RemoteAccess({ wizard, onChange }) {
  return (
    <div className="wizard-content">
      <h2 className="text-2xl font-bold mb-4">Acesso Remoto</h2>
      <p className="text-gray-400 mb-8">
        Habilite o acesso remoto para continuar a instalação através de outro dispositivo na mesma rede.
      </p>

      <div className="bg-gray-800/50 border border-gray-700 p-6 rounded-xl mb-6">
        <label className="flex items-start space-x-4 cursor-pointer">
          <input
            type="checkbox"
            className="form-checkbox mt-1 h-5 w-5 text-blue-500 bg-gray-900 border-gray-700 rounded focus:ring-blue-500 focus:ring-offset-gray-900"
            checked={wizard.remoteAccessEnabled}
            onChange={(e) => onChange({ remoteAccessEnabled: e.target.checked })}
          />
          <div>
            <span className="block text-lg font-bold text-white mb-1">
              Habilitar instalador remoto
            </span>
            <span className="block text-sm text-gray-400">
              Permite acessar este assistente via navegador (porta 8080) de outra máquina.
              <br />
              <strong className="text-yellow-500 mt-2 block">Aviso: Use apenas em rede confiável.</strong>
            </span>
          </div>
        </label>
      </div>

      {wizard.remoteAccessEnabled ? (
        <div className="bg-blue-500/10 border border-blue-500/30 p-6 rounded-xl">
          <h3 className="text-lg font-bold text-blue-400 mb-2">Instruções de Acesso</h3>
          <p className="text-gray-300 text-sm mb-4">
            Acesse a interface a partir de outro dispositivo usando os endereços IP desta máquina na porta 8080.
          </p>
          <div className="bg-black/50 p-4 rounded border border-gray-700 font-mono text-sm text-green-400">
            {wizard.serverIp ? `http://${wizard.serverIp}:8080` : 'Aguardando rede...'}
          </div>
        </div>
      ) : (
        <div className="bg-gray-800/30 border border-gray-700/50 p-6 rounded-xl">
          <h3 className="text-lg font-bold text-gray-400 mb-2">Acesso Restrito (Local-Only)</h3>
          <p className="text-gray-500 text-sm">
            O instalador está acessível apenas localmente através da interface gráfica ou via <code>127.0.0.1</code>. O firewall bloqueia acessos externos.
          </p>
        </div>
      )}
    </div>
  );
}
