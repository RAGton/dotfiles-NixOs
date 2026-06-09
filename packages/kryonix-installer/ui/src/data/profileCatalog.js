export const PROFILE_CATALOG = [
  {
    id: 'minimal',
    name: 'Minimal',
    mode: 'server',
    description: 'Sistema base CLI puro. Sem desktop, sem /srv/data, servicos extras opcionais. Ideal para VMs leves e containers.',
    icon: '',
    badges: ['Rapido', 'CLI']
  },
  {
    id: 'desktop-plasma',
    name: 'Desktop Plasma',
    mode: 'desktop',
    description: 'KDE Plasma Wayland completo. Apps de usuario, sem /srv/data por padrao. Ideal para uso diario.',
    icon: '',
    badges: ['Wayland', 'GUI']
  },
  {
    id: 'developer',
    name: 'Developer Workstation',
    mode: 'desktop',
    description: 'Plasma + Rust, Python, Nix, Jupyter, VSCode, Antigravity. Otimizado para engenharia de software.',
    icon: '',
    badges: ['Dev', 'Produtividade']
  },
  {
    id: 'server',
    name: 'Server Node',
    mode: 'server',
    description: 'Foco em estabilidade, firewall, containers, observabilidade e acesso remoto. /srv/data altamente recomendado.',
    icon: '',
    badges: ['Headless', 'Rede']
  },
  {
    id: 'ai-local',
    name: 'AI Local Edge',
    mode: 'server',
    description: 'Ollama, Brain, Neo4j, LightRAG pre-configurados. Exige /srv/data para bancos de vetores e modelos.',
    icon: '',
    badges: ['Exige GPU', 'IA Local']
  },
  {
    id: 'kryonix-full',
    name: 'Kryonix Full',
    mode: 'desktop',
    description: 'Desktop + Dev + AI + Server. Instalacao maxima (a.k.a The Glacier). /srv/data obrigatorio.',
    icon: '',
    badges: ['Massivo', 'Completo']
  },
  {
    id: 'custom',
    name: 'Custom',
    mode: 'server',
    description: 'Nenhum padrao assumido. Voce escolhe feature por feature de forma granular na proxima etapa.',
    icon: '',
    badges: ['Avancado']
  }
];

export function getProfileById(id) {
  return PROFILE_CATALOG.find((p) => p.id === id) || null;
}

// Todas as features retornadas DEVEM existir em FEATURE_CATALOG.
// IDs mortos removidos: network.networkmanager, dev.rust (nao, existe sim), server.openssh, server.docker
// /srv/data: desktop-plasma e developer NAO ativam por padrao.
// ai-local e kryonix-full ativam storage.srv-data.
// server recomenda mas nao forca — so ativa se usuario selecionar storage.srv-data.
export function getFeaturesForProfile(id) {
  switch (id) {
    case 'minimal':
      return [];
    case 'desktop-plasma':
      return [
        'desktop.plasma',
        'desktop.audio',
        'security.firewall',
        'network.openssh'
      ];
    case 'developer':
      return [
        'desktop.plasma',
        'desktop.audio',
        'security.firewall',
        'network.openssh',
        'shell.zsh',
        'dev.rust',
        'dev.python',
        'dev.nix',
        'editor.vscode-insiders',
        'virtualization.podman'
      ];
    case 'server':
      return [
        'security.firewall',
        'network.openssh',
        'virtualization.podman',
        'observability.prometheus'
      ];
    case 'ai-local':
      return [
        'security.firewall',
        'network.openssh',
        'ai.ollama',
        'ai.open-webui',
        'ai.neo4j',
        'ai.kryonix-brain',
        'storage.srv-data',
        'virtualization.podman'
      ];
    case 'kryonix-full':
      return [
        'desktop.plasma',
        'desktop.audio',
        'security.firewall',
        'network.openssh',
        'shell.zsh',
        'dev.rust',
        'dev.python',
        'dev.nix',
        'editor.vscode-insiders',
        'ai.ollama',
        'ai.open-webui',
        'ai.neo4j',
        'ai.kryonix-brain',
        'virtualization.podman',
        'virtualization.libvirt',
        'storage.srv-data',
        'observability.prometheus',
        'observability.grafana',
        'mcp.filesystem',
        'mcp.neo4j',
        'mcp.ollama'
      ];
    default:
      return [];
  }
}
