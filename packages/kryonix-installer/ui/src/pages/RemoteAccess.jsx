import React, { useState, useEffect, useCallback } from 'react';
import { installerApi } from '../utils/installerApi.js';

export default function RemoteAccess({ wizard, onChange }) {
  const [detectedIp, setDetectedIp] = useState('');
  const [detecting, setDetecting] = useState(false);
  const [detectError, setDetectError] = useState('');

  const detectIp = useCallback(async () => {
    setDetecting(true);
    setDetectError('');
    try {
      const status = await installerApi.getNetworkStatus();
      if (status?.ip) {
        const ip = status.ip.split('/')[0];
        setDetectedIp(ip);
      } else if (!status?.connected) {
        setDetectError('Sem conectividade detectada.');
      } else {
        setDetectError('IP nao detectado na interface ativa.');
      }
    } catch {
      setDetectError('Falha ao consultar o backend de rede.');
    } finally {
      setDetecting(false);
    }
  }, []);

  useEffect(() => {
    if (wizard.remoteAccessEnabled) {
      detectIp();
    }
  }, [wizard.remoteAccessEnabled, detectIp]);

  const accessIp = wizard.serverIp || detectedIp;
  const accessPort = wizard.httpPort || 8080;
  const accessUrl = accessIp ? `http://${accessIp}:${accessPort}` : '';

  return (
    <div className="wizard-content">
      <h2 className="text-2xl font-bold mb-4">Acesso Remoto</h2>
      <p className="text-gray-400 mb-8">
        Habilite o acesso remoto para continuar a instalacao atraves de outro dispositivo na mesma rede.
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
              Permite acessar este assistente via navegador (porta {accessPort}) de outra maquina.
              <br />
              <strong className="text-yellow-500 mt-2 block">Aviso: Use apenas em rede confiavel.</strong>
            </span>
          </div>
        </label>
      </div>

      {wizard.remoteAccessEnabled ? (
        <div className="bg-blue-500/10 border border-blue-500/30 p-6 rounded-xl">
          <h3 className="text-lg font-bold text-blue-400 mb-2">Instrucoes de Acesso</h3>
          <p className="text-gray-300 text-sm mb-4">
            Acesse a interface a partir de outro dispositivo usando os enderecos IP desta maquina na porta {accessPort}.
          </p>

          {accessUrl ? (
            <div className="bg-black/50 p-4 rounded border border-gray-700 font-mono text-sm text-green-400 mb-4">
              {accessUrl}
            </div>
          ) : (
            <div className="bg-amber-500/10 border border-amber-500/30 p-4 rounded-xl mb-4">
              <p className="text-amber-200 text-sm font-semibold mb-1">
                IP ainda nao detectado
              </p>
              <p className="text-amber-100/80 text-sm">
                Aguardando DHCP / IP nao detectado. Verifique a conectividade ou preencha manualmente na tela de Rede.
              </p>
              {detectError ? (
                <p className="text-amber-100/60 text-xs mt-2">{detectError}</p>
              ) : null}
            </div>
          )}

          {detectedIp && !wizard.serverIp ? (
            <div className="text-emerald-200 text-xs mb-4">
              IP detectado automaticamente: {detectedIp}
            </div>
          ) : null}

          {wizard.serverIp ? (
            <div className="text-cyan-200 text-xs mb-4">
              IP configurado manualmente: {wizard.serverIp}
            </div>
          ) : null}

          <button
            type="button"
            className="btn-primary !px-4 !py-2 text-sm"
            onClick={detectIp}
            disabled={detecting}
          >
            {detecting ? 'Detectando...' : 'Atualizar IP automaticamente'}
          </button>
        </div>
      ) : (
        <div className="bg-gray-800/30 border border-gray-700/50 p-6 rounded-xl">
          <h3 className="text-lg font-bold text-gray-400 mb-2">Acesso Restrito (Local-Only)</h3>
          <p className="text-gray-500 text-sm">
            O instalador esta acessivel apenas localmente atraves da interface grafica ou via <code>127.0.0.1</code>. O firewall bloqueia acessos externos.
          </p>
        </div>
      )}
    </div>
  );
}
