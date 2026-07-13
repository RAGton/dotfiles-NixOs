# Roadmap RAGOS

Status: canonical
Scope: maturidade operacional desejada do RAGOS
Last reviewed: 2026-06-13

Este roadmap descreve a evolucao tecnica do RAGOS como plataforma on-premises
para clientes diskless reais em NixOS.

Ele nao e lista de desejos solta. Cada fase precisa aumentar ao menos um destes
atributos:

- previsibilidade operacional;
- auditabilidade;
- seguranca;
- recuperacao;
- experiencia real do operador ou do usuario final.

## Leitura honesta deste documento

Use estes marcadores:

- `[x]`: existe no codigo/documentacao atual e foi confirmado nesta revisao por leitura do repo.
- `[~]`: existe parcialmente ou precisa de prova runtime mais forte.
- `[ ]`: planejado; nao deve ser descrito como funcionalidade entregue.

Esta revisao analisou as ultimas mudancas visiveis no repo, incluindo:

- governanca local do Codex em `AGENTS.md`, `.codex/agents/` e `.agents/skills/`;
- branding Plasma 6 em `themes/plasma/` e `client/desktop/branding.nix`;
- criterios de prova em `docs/branding-review.md`;
- inventario externo e semantica compativel em `server/network/clients-inventory-lib.nix`;
- contratos de canal/perfil em `docs/ragc-channels-explained.md`;
- contratos de boot em `docs/boot-semantics.md` e `scripts/tests/test-client-boot-surface-contract.sh`;
- usuarios, grupos, setores e auditoria em `server/ragos-cli.nix`, `server/services/user-groups.nix` e `server/services/login-audit.nix`;
- contrato Day-0 em `docs/day0-acceptance.md`.

Nada aqui substitui prova real em lab ou runtime. Se a prova nao foi rodada, o
item permanece como planejamento ou consolidacao parcial.

---

# Fase 1 -- Base diskless reproduzivel

Objetivo: provar o modelo diskless centralizado.

Entregas centrais:

- [x] boot UEFI com PXE + iPXE
- [x] distribuicao de kernel/initrd por HTTP
- [x] cliente diskless funcional
- [x] persistencia remota de usuario
- [x] CLI operacional base
- [x] documentacao inicial da arquitetura

Resultado esperado:

- o cliente liga pela rede;
- o servidor entrega o sistema;
- o endpoint pode ser substituido sem reinstalacao artesanal.

---

# Fase 2 -- Arquitetura consolidada e storage defensavel

Objetivo: sair do "funciona no lab" para um desenho defensavel de producao.

Entregas centrais:

- [x] separacao entre disco de sistema e disco de dados
- [x] BTRFS no tier de dados
- [x] subvolumes para homes, imagens e snapshots
- [x] publicacao geracional da imagem do cliente
- [x] rollback rapido de imagem
- [x] observabilidade base
- [x] distincao clara entre `ragos` e `ragc`

Resultado esperado:

- o servidor e reinstalavel;
- os dados ficam protegidos e estruturados;
- a imagem do cliente pode evoluir com rollback controlado.

---

# Fase 3 -- Contratos canonicos e drift documental

Objetivo: manter README, docs, runbook, testes e codigo apontando para a mesma
arquitetura.

Estado confirmado nesta revisao:

- [x] README diferencia estado atual, direcao oficial e roadmap.
- [x] root atual do cliente esta documentado como `/nix/store` via NFS + overlay tmpfs.
- [x] netboot/SquashFS permanece tratado como roadmap, nao contrato atual.
- [x] persistencia do usuario via NFSv4 em `/home` esta documentada.
- [x] split-storage e BTRFS aparecem como padrao do servidor.
- [x] `docs/README.md` classifica docs canonicas, arquivadas e complementares.
- [~] ainda ha documentos historicos arquivados que podem confundir se forem lidos fora do contexto canonico.

Proximas entregas:

- [ ] adicionar check documental que falhe quando SquashFS for descrito como estado atual;
- [ ] cruzar `docs/runbook.md` com os comandos reais de `server/ragos-cli.nix` a cada novo subcomando;
- [ ] manter `docs/roadmap.md` como destino obrigatorio de item planejado, parcial ou sem prova.

Resultado esperado:

- menos drift entre desejo, codigo e operacao;
- contribuicao mais segura;
- release notes mais honestas.

---

# Fase 4 -- Inventario declarativo e controle do parque

Objetivo: transformar clientes em entidades operaveis por inventario, nao por
memoria humana.

Estado confirmado nesta revisao:

- [x] inventario externo canonico em `/etc/ragos-inventory/clients.nix`;
- [x] validacao de MAC, hostname e IP unicos;
- [x] renderizacao para `dnsmasq`;
- [x] roteamento por MAC para `generic.ipxe`, `lab.ipxe` e `rescue.ipxe`;
- [x] camada compativel para `releaseTrack`, `clientProfile`, `hardwareClass` e `bootMethod`;
- [~] `uefi-http` existe como metadado/controle compativel, nao como boot canonico provado;
- [ ] comando `ragos clients` para visao operacional do parque;
- [ ] historico por cliente: ultimo DHCP, ultimo boot, canal atual e geracao carregada;
- [ ] import/export validado do inventario para manutencao externa.

Resultado esperado:

- cada estacao deixa de ser "aquela maquina ali";
- o parque vira estrutura rastreavel e auditavel;
- troubleshooting comeca pelo inventario, nao por tentativa manual.

---

# Fase 5 -- Branding como sistema, nao como wallpaper

Objetivo: transformar branding em contrato de produto mensuravel entre boot,
greeter e desktop.

Estado confirmado nesta revisao:

- [x] Plymouth possui tema declarativo em `themes/plymouth/`;
- [x] SDDM possui tema `ragos-control` em `themes/sddm/`;
- [x] Plasma 6 possui Global Themes, Plasma Styles, Color Schemes e wallpapers em `themes/plasma/`;
- [x] `client/desktop/branding.nix` aplica variante Plasma e gera `ragos-plasma-report`;
- [x] `docs/branding-review.md` exige prova visual real antes de declarar sucesso;
- [x] scripts de BrandLab existem em `scripts/lab/branding/`;
- [~] GTK ainda nao possui tema declarativo proprio;
- [~] prova visual completa ainda depende de screenshots/logs de lab.

Entregas prioritarias:

- [ ] consolidar uma identidade visual unica para Plymouth, SDDM e Plasma, com paleta, tipografia e logo versionados;
- [ ] criar checklist visual por release: boot, greeter, desktop dark, desktop light e menu;
- [ ] adicionar teste que garanta que `ragos-plasma-report` aparece nos perfis desktop oficiais;
- [ ] definir politica de assets: origem, dimensoes, licenca, regeneracao e comparacao de manifest;
- [ ] evoluir `ragos branding doctor` para classificar `OK`, `PARTIAL`, `BROKEN` e `UNKNOWN` por superficie;
- [ ] criar modo de captura e comparacao que produza relatorio unico em `artifacts/branding/reports/`;
- [ ] planejar tema GTK somente depois de Plymouth/SDDM/Plasma estarem provados em runtime.

Resultado esperado:

- o usuario reconhece o RAGOS do boot ao desktop;
- o operador sabe diferenciar tema aplicado, fallback visual e prova incompleta;
- branding passa a ser parte da qualidade do sistema, nao acabamento manual.

---

# Fase 6 -- Servidor operacional completo

Objetivo: fazer o `srv-rag` operar parque, usuarios, dados e diagnostico sem
depender de improviso.

Estado confirmado nesta revisao:

- [x] `ragos status` existe como resumo operacional;
- [x] `ragos user` cobre criacao, resize, listagem, delete com archive, doctor, quota-sync e activity;
- [x] `ragos group` cobre setores, permissoes, membros e defaults;
- [x] homes usam `/srv/data/home` e catalogo de cliente em `/var/lib/ragos/runtime/client-users.json`;
- [x] setores usam `/srv/data/storage/<grupo>` e catalogo em `/var/lib/ragos/runtime/user-groups.json`;
- [x] auditoria de login usa `/var/lib/ragos/audit/login-history.json`;
- [x] acesso primario por SSH e fallbacks `tty1`, `ttyS0`, `hvc0`, `ttyAMA0` estao documentados/testados por harness;
- [~] `server/services/user-management.nix` ainda e stub e precisa virar modulo real ou ser removido;
- [~] rotinas de backup/restore ainda precisam de prova operacional formal.

Entregas prioritarias:

- [ ] implementar `ragos clients` com leitura do inventario, canal, IP, MAC e estado esperado;
- [ ] implementar `ragos wol <hostname|mac>` usando inventario e interface LAN correta;
- [ ] adicionar `ragos health` com checks estruturados para storage, servicos, inventario, HTTP de boot e NFS;
- [ ] adicionar `ragos backup plan` e `ragos backup verify` para homes, setores, inventario e runtime;
- [ ] criar prova de restore de usuario e setor a partir de arquivo e snapshot;
- [ ] transformar `server/services/user-management.nix` em modulo efetivo ou consolidar a responsabilidade no CLI;
- [ ] expor alertas de quotas, geracoes antigas e storage cheio na observabilidade;
- [ ] criar modo `ragos doctor --json` para consumo por painel futuro.

Resultado esperado:

- o servidor deixa de ser apenas host de boot e vira console operacional do parque;
- adicionar/remover usuario, setor e cliente vira fluxo auditavel;
- restore e rollback deixam de depender de memoria do operador.

---

# Fase 7 -- Cliente previsivel, recuperavel e confortavel

Objetivo: tornar o cliente descartavel no hardware, mas consistente para o
usuario final.

Estado confirmado nesta revisao:

- [x] perfis oficiais: `desktop-generic`, `desktop-lab`, `rescue-minimal` e `hyperv-debug`;
- [x] `desktop-generic` preserva boot silencioso com Plymouth por contrato de teste;
- [x] `desktop-lab` preserva boot verboso e nao promete Plymouth;
- [x] `/home/<usuario>` monta por NFSv4 apos login;
- [x] setores compartilhados aparecem em `~/Setores/<grupo>`;
- [x] o contrato ativo remove dependencia de `/mnt/groups`;
- [x] `rescue-minimal` existe como perfil sem Plasma para recuperacao;
- [~] prova completa de SDDM, login, Plasma e home ainda depende de lab/libvirt/QEMU.

Entregas prioritarias:

- [ ] adicionar `ragos client session-doctor --json` com home, setores, usuario, canal e geracao;
- [ ] criar diagnostico no cliente para explicar falha de login, home NFS, setor ausente e perfil incorreto;
- [ ] validar performance de login e montagem de setores com N usuarios e N grupos;
- [ ] criar politica de cache seguro para reduzir latencia sem criar estado local critico;
- [ ] fortalecer `rescue-minimal` com runbook de recuperacao de rede, NFS e publish;
- [ ] definir criterio para novos perfis: so aceitar perfil novo se houver hardware-alvo, contrato e teste;
- [ ] planejar acessibilidade visual minima: contraste, fonte, escala e teclado no greeter/desktop.

Resultado esperado:

- cliente quebrado vira diagnostico guiado, nao investigacao manual;
- usuario percebe ambiente coerente e rapido;
- o endpoint continua substituivel sem estado local critico.

---

# Fase 8 -- Wake-on-LAN e operacao remota do parque

Objetivo: permitir que o servidor acione clientes conhecidos de forma previsivel.

Entregas minimas:

- [ ] `ragos wol <hostname|mac>`;
- [ ] lookup por inventario;
- [ ] identificacao da interface correta de saida;
- [ ] envio de magic packet com log operacional;
- [ ] `ragos wait <hostname>` para aguardar DHCP/boot;
- [ ] troubleshooting documentado;
- [ ] validacao em hardware fisico compativel.

Entregas desejaveis:

- [ ] `ragos wol-all --tag <tag>`;
- [ ] metricas de ultimo WOL, ultimo DHCP e ultimo boot;
- [ ] correlacao com status por cliente;
- [ ] integracao com painel futuro.

Resultado esperado:

- o servidor deixa de apenas publicar o sistema e passa tambem a acionar o endpoint;
- operacao remota do parque fica mais completa.

---

# Fase 9 -- Seguranca e blindagem de rede

Objetivo: reduzir superficie de erro e exposicao do ambiente diskless.

Entregas prioritarias:

- [ ] VLAN ou segmentacao dedicada para rede de boot;
- [ ] hardening de exports NFS;
- [ ] revisao de firewall do servidor;
- [ ] validacao estrita de clientes autorizados;
- [ ] modo fail-closed padrao para inventario fora do primeiro boot controlado;
- [ ] rotacao e revisao de chaves/credenciais operacionais;
- [ ] testes automatizados de regressao do fluxo PXE/iPXE;
- [ ] trilha de auditoria para mudancas de usuario, grupo, inventario e publish.

Resultado esperado:

- menos ruido na rede;
- menos risco operacional;
- mais previsibilidade em escala.

---

# Fase 10 -- Day-0, release e reinstalacao confiavel

Objetivo: garantir que uma instalacao limpa vira servidor operacional sem
passos tribais.

Estado confirmado nesta revisao:

- [x] `docs/day0-acceptance.md` define contrato minimo;
- [x] `scripts/tests/test-day0-contract.sh` existe como harness documental/contratual;
- [~] prova destrutiva completa continua dependente de lab com libvirt/QEMU;
- [~] primeiro publish e primeiro boot de cliente precisam continuar evidenciados por logs/manifests/screenshots.

Entregas prioritarias:

- [ ] consolidar um comando suportado para validar Day-0 do host instalado;
- [ ] preservar logs de instalacao, primeiro publish, boot de cliente e branding em local padrao;
- [ ] reduzir friccao de `safe.directory` e churn de host key no lab;
- [ ] transformar falhas Day-0 em diagnosticos `OK`, `PARTIAL`, `BROKEN` e `UNKNOWN`;
- [ ] definir checklist de promocao `lab -> generic -> release/tag`.

Resultado esperado:

- reinstalar deixa de ser evento arriscado;
- release so avanca com evidencia;
- rollback e revalidacao ficam claros para operador novo.

---

# Fase 11 -- Escala, painel e produto

Objetivo: consolidar o RAGOS como plataforma operacional, nao apenas composicao
tecnica.

Entregas prioritarias:

- [ ] painel web read-only para estado do parque;
- [ ] visao de clientes por inventario, canal, perfil, geracao e ultimo boot;
- [ ] visao de usuarios, quotas, setores e auditoria sem expor segredos;
- [ ] leitura de metricas e alertas ja produzidos pelo servidor;
- [ ] acao controlada para WOL, publish e diagnostico quando os comandos CLI estiverem maduros;
- [ ] documentar API interna somente depois de estabilizar CLI e JSON outputs.

Resultado esperado:

- operacao mais acessivel sem sacrificar clareza tecnica;
- produto mais completo sem virar trambolho;
- CLI continua sendo fonte operacional primaria, painel vira camada de visibilidade.

---

# Ordem pratica recomendada

A ordem mais defensavel hoje e:

1. estabilizar `docs/roadmap.md`, runbook e contratos de teste;
2. fechar `ragos clients` e `ragos health`;
3. fortalecer `ragos branding doctor` com classificacao por superficie;
4. provar branding em `lab` com screenshots e `ragos-plasma-report`;
5. implementar WOL por inventario;
6. adicionar backup/restore verificavel para homes, setores e inventario;
7. promover prova completa Day-0 em lab;
8. so depois iniciar painel web.

Essa ordem evita construir interface bonita em cima de contrato operacional fraco.

## Proximos commits sugeridos

1. `docs(roadmap): align phases with current server client and branding work`
2. `feat(server): add clients and health subcommands to ragos`
3. `feat(branding): classify branding doctor surfaces`
4. `feat(server): implement inventory-based wol`
5. `test(day0): persist evidence bundle for clean install validation`
