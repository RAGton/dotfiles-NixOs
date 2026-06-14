import React, { useState, useEffect } from 'react';
import { installerApi } from '../utils/installerApi';

const ProfileSelector = ({ host }) => {
    const [activeTab, setActiveTab] = useState('profiles');
    const [status, setStatus] = useState(null);
    const [loading, setLoading] = useState(false);
    const [restoreMode, setRestoreMode] = useState(false);
    
    // Disk Planner states
    const [disks, setDisks] = useState([]);
    const [selectedDisk, setSelectedDisk] = useState('');
    const [scheme, setScheme] = useState('btrfs');

    useEffect(() => {
        const checkRestore = async () => {
            try {
                const data = await installerApi.getHardware();
                // Check if any disk already has kryonix flag or existing partition
                const hasExisting = data.disks?.some(d => d.mountpoint === '/mnt' || d.label === 'NIXOS-SYSTEM');
                if (hasExisting) {
                    setRestoreMode(true);
                    setStatus("ℹ️ Repositório Kryonix detectado no disco. Modo de restauração disponível.");
                }
            } catch (e) {
                console.error("Restore check failed", e);
            }
        };
        checkRestore();
    }, []);

    useEffect(() => {
        if (activeTab === 'disk') {
            const fetchHardware = async () => {
                try {
                    const data = await installerApi.getHardware();
                    const inventory = data.disks || [];
                    setDisks(inventory);
                    if (inventory.length > 0) setSelectedDisk(inventory[0].name || inventory[0].path?.split('/').pop());
                } catch (error) {
                    console.error("Failed to fetch hardware probe", error);
                }
            };
            fetchHardware();
        }
    }, [activeTab]);

    const applyProfile = async (profile) => {
        setLoading(true);
        setStatus("Recompilando perfil...");
        try {
            const response = await fetch('/profile/apply', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ host, profile }),
            });
            const data = await response.json();
            if (response.ok) {
                setStatus("✅ Perfil aplicado com sucesso!");
            } else {
                setStatus(`❌ Erro: ${data.details || data.error}`);
            }
        } catch (error) {
            setStatus(`⚠️ Erro de conexão: ${error.message}`);
        } finally {
            setLoading(false);
        }
    };

    const applyDiskConfig = async (dryRun = false) => {
        if (!selectedDisk) return;
        
        if (!dryRun && !window.confirm("⚠️ ATENÇÃO: A formatação irá APAGAR todos os dados do disco selecionado. Deseja continuar?")) {
            return;
        }

        setLoading(true);
        setStatus(dryRun ? "Gerando preview..." : "Formatando disco (disko)...");
        
        try {
            const devicePath = selectedDisk.startsWith('/dev/') ? selectedDisk : `/dev/${selectedDisk}`;
            const response = await fetch('/disk/apply', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ host, device: devicePath, scheme, dry_run: dryRun }),
            });
            const data = await response.json();
            
            if (response.ok) {
                if (dryRun) {
                    setStatus(`✅ Configuração gerada em: ${data.path}\n\n${data.content}`);
                } else {
                    setStatus("✅ Disco particionado e formatado com sucesso!");
                }
            } else {
                setStatus(`❌ Erro: ${data.details || data.error}`);
            }
        } catch (error) {
            setStatus(`⚠️ Erro de conexão: ${error.message}`);
        } finally {
            setLoading(false);
        }
    };

    const finalizeInstall = async () => {
        setLoading(true);
        setStatus("🚀 Iniciando orquestração da instalação...");
        try {
            const response = await fetch('/install/finalize', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ host }),
            });
            if (response.ok) {
                setStatus("📦 Instalação em progresso. Verifique os logs de background.");
            } else {
                setStatus("❌ Falha ao iniciar finalização.");
            }
        } catch (e) {
            setStatus(`⚠️ Erro: ${e.message}`);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="border rounded shadow-sm bg-white dark:bg-gray-800">
            <div className="flex border-b">
                <button 
                    onClick={() => setActiveTab('profiles')}
                    className={`px-4 py-2 flex-1 text-sm font-medium ${activeTab === 'profiles' ? 'border-b-2 border-blue-500 text-blue-600' : 'text-gray-500 hover:text-gray-700'}`}
                >
                    🔧 Perfis de Sistema
                </button>
                <button 
                    onClick={() => setActiveTab('disk')}
                    className={`px-4 py-2 flex-1 text-sm font-medium ${activeTab === 'disk' ? 'border-b-2 border-blue-500 text-blue-600' : 'text-gray-500 hover:text-gray-700'}`}
                >
                    💾 Configuração de Disco
                </button>
            </div>

            <div className="p-4">
                {restoreMode && (
                    <div className="mb-6 p-4 bg-blue-50 border border-blue-200 rounded text-blue-800 flex justify-between items-center">
                        <div>
                            <strong>Modo de Restauração</strong>
                            <p className="text-sm">Configuração existente detectada. Deseja pular o particionamento?</p>
                        </div>
                        <button 
                            onClick={finalizeInstall}
                            className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 text-sm font-bold"
                        >
                            Restaurar Sistema
                        </button>
                    </div>
                )}

                {activeTab === 'profiles' ? (
                    <div>
                        <h3 className="text-lg font-bold mb-4">Selecionar Perfil para {host}</h3>
                        <div className="flex gap-4">
                            <button 
                                disabled={loading} 
                                onClick={() => applyProfile('GAMER')}
                                className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50"
                            >
                                🎮 Gamer
                            </button>
                            <button 
                                disabled={loading} 
                                onClick={() => applyProfile('DEV_RUST')}
                                className="px-4 py-2 bg-purple-600 text-white rounded hover:bg-purple-700 disabled:opacity-50"
                            >
                                🦀 Dev Rust
                            </button>
                        </div>
                    </div>
                ) : (
                    <div>
                        <h3 className="text-lg font-bold mb-4">Configuração de Disco (Disko)</h3>
                        <div className="mb-4">
                            <label className="block text-sm font-medium mb-1">Selecionar Disco Alvo:</label>
                            <select 
                                value={selectedDisk} 
                                onChange={(e) => setSelectedDisk(e.target.value)}
                                className="w-full p-2 border rounded dark:bg-gray-700"
                            >
                                <option value="">Selecione um disco...</option>
                                {disks.map(disk => (
                                    <option key={disk.name || disk.path} value={disk.name || disk.path}>
                                        {disk.path || `/dev/${disk.name}`} ({disk.size || disk.size_bytes}) {disk.model ? `- ${disk.model}` : ''}
                                    </option>
                                ))}
                            </select>
                        </div>

                        <div className="mb-4">
                            <label className="block text-sm font-medium mb-1">Esquema:</label>
                            <select 
                                value={scheme} 
                                onChange={(e) => setScheme(e.target.value)}
                                className="w-full p-2 border rounded dark:bg-gray-700"
                            >
                                <option value="btrfs">Recomendado: BTRFS (Subvolumes @, @home, @nix)</option>
                                <option value="manual">Manual: Usar layout existente (/)</option>
                            </select>
                        </div>

                        <div className="p-3 mb-4 bg-red-50 text-red-700 border border-red-200 rounded text-sm">
                            <strong>Aviso:</strong> A formatação irá APAGAR todos os dados do disco selecionado.
                        </div>

                        <div className="flex gap-4">
                            <button 
                                disabled={loading || !selectedDisk} 
                                onClick={() => applyDiskConfig(true)}
                                className="px-4 py-2 bg-gray-600 text-white rounded hover:bg-gray-700 disabled:opacity-50"
                            >
                                🔍 Preview (Dry-run)
                            </button>
                            <button 
                                disabled={loading || !selectedDisk} 
                                onClick={() => applyDiskConfig(false)}
                                className="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 disabled:opacity-50"
                            >
                                🚀 Aplicar & Formatar
                            </button>
                        </div>
                        
                        <div className="mt-8 border-t pt-4">
                            <button 
                                disabled={loading}
                                onClick={finalizeInstall}
                                className="w-full py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 font-bold shadow-lg"
                            >
                                ✨ Finalizar Instalação do KryonixOS
                            </button>
                        </div>
                    </div>
                )}

                {status && (
                    <div className={`mt-4 p-3 rounded font-mono text-xs whitespace-pre-wrap ${loading ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300'}`}>
                        {status}
                    </div>
                )}
            </div>
        </div>
    );
};

export default ProfileSelector;
