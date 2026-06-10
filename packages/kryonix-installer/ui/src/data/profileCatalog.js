export const PROFILE_CATALOG = [
  {
    id: 'minimal',
    name: 'Minimal',
    mode: 'server',
    description: 'Base NixOS mínima. Sem desktop, sem gamer, sem IA, sem /srv/data. Ideal para VMs leves e containers.',
    icon: '',
    badges: ['Rápido', 'CLI'],
    enableSrvData: false,
    srvDataRecommended: false,
    defaultFeatures: ['network.openssh', 'security.firewall']
  },
  {
    id: 'desktop',
    name: 'Desktop Plasma',
    mode: 'desktop',
    description: 'KDE Plasma, áudio, bluetooth, navegador, terminal, tema Kryonix. Sem /srv/data.',
    icon: '',
    badges: ['Wayland', 'GUI'],
    enableSrvData: false,
    srvDataRecommended: false,
    defaultFeatures: ['desktop.plasma', 'desktop.audio', 'desktop.bluetooth', 'security.firewall', 'network.openssh', 'shell.zsh', 'shell.starship', 'terminal.warp', 'browser.firefox']
  },
  {
    id: 'development',
    name: 'Developer Workstation',
    mode: 'desktop',
    description: 'Desktop/dev workstation. Rust, Python, Nix tooling, VSCode, Jupyter. Sem /srv/data por padrão.',
    icon: '',
    badges: ['Dev', 'Produtividade'],
    enableSrvData: false,
    srvDataRecommended: false,
    defaultFeatures: ['desktop.plasma', 'desktop.audio', 'desktop.bluetooth', 'security.firewall', 'network.openssh', 'shell.zsh', 'shell.starship', 'terminal.warp', 'editor.vscode-insiders', 'dev.rust', 'dev.python', 'dev.nix', 'dev.jupyter', 'virtualization.podman']
  },
  {
    id: 'gamer',
    name: 'Gamer Desktop',
    mode: 'desktop',
    description: 'Desktop gamer. Steam, GameMode, MangoHud, drivers, suporte a controles. Sem /srv/data.',
    icon: '',
    badges: ['Gaming', 'Steam'],
    enableSrvData: false,
    srvDataRecommended: false,
    defaultFeatures: ['desktop.plasma', 'desktop.audio', 'desktop.bluetooth', 'security.firewall', 'network.openssh', 'shell.zsh', 'terminal.warp', 'gamer.steam', 'gamer.gamemode', 'gamer.mangohud', 'gamer.proton', 'gamer.controllers']
  },
  {
    id: 'gamer-dev',
    name: 'Gamer + Dev',
    mode: 'desktop',
    description: 'Desktop gamer + desenvolvimento. Steam, GameMode, Rust, Python, VSCode. Sem /srv/data.',
    icon: '',
    badges: ['Gaming', 'Dev'],
    enableSrvData: false,
    srvDataRecommended: false,
    defaultFeatures: ['desktop.plasma', 'desktop.audio', 'desktop.bluetooth', 'security.firewall', 'network.openssh', 'shell.zsh', 'terminal.warp', 'editor.vscode-insiders', 'dev.rust', 'dev.python', 'dev.nix', 'gamer.steam', 'gamer.gamemode', 'gamer.mangohud', 'gamer.proton', 'gamer.controllers', 'virtualization.podman']
  },
  {
    id: 'server',
    name: 'Server Node',
    mode: 'server',
    description: 'Servidor. SSH, firewall, containers, observabilidade básica. /srv/data recomendado.',
    icon: '',
    badges: ['Headless', 'Rede'],
    enableSrvData: false,
    srvDataRecommended: true,
    defaultFeatures: ['security.firewall', 'network.openssh', 'security.fail2ban', 'virtualization.podman', 'server.containers', 'observability.prometheus', 'storage.srv-data']
  },
  {
    id: 'server-dev',
    name: 'Server + Dev',
    mode: 'server',
    description: 'Servidor + ferramentas de desenvolvimento/admin. /srv/data recomendado.',
    icon: '',
    badges: ['Headless', 'DevOps'],
    enableSrvData: false,
    srvDataRecommended: true,
    defaultFeatures: ['security.firewall', 'network.openssh', 'security.fail2ban', 'virtualization.podman', 'server.containers', 'observability.prometheus', 'storage.srv-data', 'dev.git', 'dev.github-cli', 'dev.nix', 'shell.zsh']
  },
  {
    id: 'ai-local',
    name: 'AI Local Edge',
    mode: 'server',
    description: 'IA local. Ollama, Open WebUI, Neo4j, LightRAG, Kryonix Brain. /srv/data obrigatório.',
    icon: '',
    badges: ['Exige GPU', 'IA Local'],
    enableSrvData: true,
    srvDataRecommended: true,
    defaultFeatures: ['security.firewall', 'network.openssh', 'ai.ollama', 'ai.open-webui', 'ai.neo4j', 'ai.lightrag', 'ai.kryonix-brain', 'storage.srv-data', 'virtualization.podman']
  },
  {
    id: 'server-ai',
    name: 'Server AI',
    mode: 'server',
    description: 'Servidor de IA. AI local + server stack. /srv/data obrigatório.',
    icon: '',
    badges: ['Headless', 'IA', 'Servidor'],
    enableSrvData: true,
    srvDataRecommended: true,
    defaultFeatures: ['security.firewall', 'network.openssh', 'security.fail2ban', 'ai.ollama', 'ai.open-webui', 'ai.neo4j', 'ai.lightrag', 'ai.kryonix-brain', 'storage.srv-data', 'virtualization.podman', 'server.containers', 'observability.prometheus', 'observability.grafana']
  },
  {
    id: 'full',
    name: 'Kryonix Full',
    mode: 'desktop',
    description: 'Desktop + Dev + Gamer + Server + AI. Instalação máxima. /srv/data recomendado.',
    icon: '',
    badges: ['Massivo', 'Completo'],
    enableSrvData: true,
    srvDataRecommended: true,
    defaultFeatures: ['desktop.plasma', 'desktop.audio', 'desktop.bluetooth', 'desktop.printing', 'security.firewall', 'network.openssh', 'shell.zsh', 'shell.starship', 'terminal.warp', 'editor.vscode-insiders', 'dev.rust', 'dev.python', 'dev.nix', 'dev.jupyter', 'gamer.steam', 'gamer.gamemode', 'gamer.mangohud', 'gamer.proton', 'gamer.controllers', 'ai.ollama', 'ai.open-webui', 'ai.neo4j', 'ai.lightrag', 'ai.kryonix-brain', 'virtualization.podman', 'virtualization.libvirt', 'storage.srv-data', 'observability.prometheus', 'observability.grafana', 'mcp.filesystem', 'mcp.neo4j', 'mcp.ollama', 'server.containers', 'server.database', 'server.reverse-proxy', 'server.backups']
  },
  {
    id: 'custom',
    name: 'Custom',
    mode: 'server',
    description: 'Nenhum padrão assumido. Você escolhe feature por feature de forma granular.',
    icon: '',
    badges: ['Avançado'],
    enableSrvData: false,
    srvDataRecommended: false,
    defaultFeatures: []
  }
];

export function getProfileById(id) {
  return PROFILE_CATALOG.find((p) => p.id === id) || null;
}

export function getFeaturesForProfile(id) {
  const profile = PROFILE_CATALOG.find(p => p.id === id);
  if (profile && Array.isArray(profile.defaultFeatures)) {
    return [...profile.defaultFeatures];
  }
  return [];
}
