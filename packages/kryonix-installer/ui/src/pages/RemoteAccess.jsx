import React, { useState, useEffect, useCallback } from 'react';
import { installerApi } from '../utils/installerApi.js';

function isValidPrivateIp(ip) {
  if (!ip) return false;
  // Ignore loopback, link-local, and 0.0.0.0
  if (ip.startsWith('127.')) return false;
  if (ip.startsWith('169.254.')) return false;
  if (ip === '0.0.0.0') return false;
  // Prefer private IPv4 ranges
  const parts = ip.split('.').map(Number);
  if (parts[0] === 10) return true;
  if (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31) return true;
  if (parts[0] === 192 && parts[1] === 168) return true;
  return false;
}

function extractIpFromStatus(status) {
  if (!status?.ip) return null;
  // nmcli may return "192.168.122.45/24" - strip CIDR
  return status.ip.split('/')[0];
}

export default function RemoteAccess({ wizard, onChange }) {
  const [detectedIp, setDetectedIp] = useState('');
  const [detecting, setDetecting] = useState(false);
  const [detectError, setDetectError] = useState('');
  const [lastAttempt, setLastAttempt] = useState(null);

  const detectIp = useCallback(async () => {
    setDetecting(true);
    setDetectError('');
    try {
      const status = await installerApi.getNetworkStatus();
      const ip = extractIpFromStatus(status);

      if (ip && isValidPrivateIp(ip)) {
        setDetectedIp(ip);
        setLastAttempt(new Date().toLocaleTimeString('pt-BR'));
      } else if (!status?.connected) {
        setDetectError('Sem conectividade de rede detectada.');
      } else if (ip) {
        // IP found but not in preferred private ranges
        setDetectedIp(ip);
        setDetectError(`IP detectado (${ip}) não está em faixa privada preferida.`);
        setLastAttempt(new Date().toLocaleTimeString('pt-BR'));
      } else {
        setDetectError('IP não detectado na interface ativa. Aguardando DHCP...');
      }
    } catch (err) {
      setDetectError('Falha ao consultar o backend de rede.');
      console.error('[RemoteAccess] detectIp error:', err);
    } finally {
      setDetecting(false);
    }
  }, []);

  // Auto-detect when remote access is enabled
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
              Permite acessar este assistente via navegador (porta {accessPort}) de outra máquina.
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
            Acesse a interface a partir de outro dispositivo usando os endereços IP desta máquina na porta {accessPort}.
          </p>

          {accessUrl ? (
            <div className="bg-black/50 p-4 rounded border border-gray-700 font-mono text-sm text-green-400 mb-4">
              {accessUrl}
            </div>
          ) : (
            <div className="bg-amber-500/10 border border-amber-500/30 p-4 rounded-xl mb-4">
              <p className="text-amber-200 text-sm font-semibold mb-1">
                IP ainda não detectado
              </p>
              <p className="text-amber-100/80 text-sm">
                Aguardando DHCP / IP não detectado. Verifique a conectividade ou preencha manualmente na tela de Rede.
              </p>
              {detectError ? (
                <p className="text-amber-100/60 text-xs mt-2">{detectError}</p>
              ) : null}
            </div>
          )}

          {detectedIp && !wizard.serverIp ? (
            <div className="text-emerald-200 text-xs mb-4">
              IP detectado automaticamente: {detectedIp}
              {lastAttempt ? ` (atualizado em {lastAttempt})` : ''}
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
            O instalador está acessível apenas localmente através da interface gráfica ou via <code>127.0.0.1</code>. O firewall bloqueia acessos externos.
          </p>
        </div>
      )}
    </div>
  );
}
