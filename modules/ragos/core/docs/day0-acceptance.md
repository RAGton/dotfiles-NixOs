# Contrato Day-0

Status: canonical
Scope: aceitacao operacional minima apos reinstalacao limpa do srv-rag e primeira publicacao do cliente
Last reviewed: 2026-04-08

Este documento define o que o RAGOS precisa entregar logo apos uma reinstalacao limpa para ser tratado como produto operacional, e nao apenas como sistema "que sobe".

Day-0, neste contexto, significa:

- o host instalado sai da ISO e entra em disco sem drift manual;
- o operador consegue validar estado, publicar cliente e iniciar o primeiro ciclo de boot sem investigacao tribal;
- o que ainda nao cabe no primeiro boot fica explicitamente classificado como pos-instalacao automatizada, nunca como passo artesanal indefinido.

Se um item desta pagina falhar, a release nao pode ser tratada como pronta sem classificacao explicita do risco.

## Deve funcionar logo apos reinstalar

Depois de uma instalacao limpa e do primeiro boot em disco, o RAGOS deve entregar no minimo:

1. O host sobe do disco instalado, nao da live ISO.
2. `ragos status` responde e aponta para `/etc/ragos` e `/var/lib/ragos/runtime`.
3. Os servicos criticos estao ativos: `sshd`, `dnsmasq`, `nginx`, `nfs-server`.
4. O storage base esta montado: `/boot`, `/nix`, `/srv`, `/srv/data/home`, `/srv/data/images`, `/srv/data/snapshots`.
5. O runtime persistente real existe em `/var/lib/ragos/runtime/params.nix` e continua referenciado por `/etc/ragos/server/runtime/params.nix`.
6. O inventario bootstrap existe em `/etc/ragos-inventory/clients.nix` e o primeiro boot aceita inventario vazio de forma controlada.
7. `ragc doctor` classifica corretamente o estado do servidor.
8. O operador consegue publicar a primeira geracao oficial com `sudo ragc switch --channel generic` ou `sudo ragc switch --channel lab`.
9. A publicacao gera manifests coerentes, links `current`/`previous` e `boot.ipxe`, `generic.ipxe`, `lab.ipxe`, `rescue.ipxe`.
10. Um cliente inventariado pega DHCP/PXE, carrega a geracao publicada e chega ao login grafico.
11. SDDM aparece de forma usavel, o login funciona e a sessao Plasma sobe.
12. `/home/<usuario>` monta por NFSv4 no cliente depois do login.

## Pode ser pos-instalacao, mas precisa ser automatizado

Os itens abaixo nao precisam existir no instante do primeiro boot, mas nao podem depender de improviso:

- preencher `clients.nix` a partir do template e aplicar com `sudo ragos-inventory-apply`;
- criar usuarios persistentes com `ragos user add ...`;
- publicar canais adicionais (`lab`, `generic`, `rescue`) via `ragc`;
- rodar a prova destrutiva de reinstalacao limpa em laboratorio com `scripts/lab/validate-srv-rag-libvirt.sh`;
- rodar a bateria segura de contrato com `scripts/tests/test-day0-contract.sh`.

## Ainda exige esforco demais hoje

Os pontos abaixo ainda geram friccao operacional acima do ideal e devem ser tratados como debito explicito:

- o host recem-instalado pode exigir configuracao de `safe.directory` para operar Git em `/etc/ragos`;
- antes da primeira publicacao, `ragc doctor` naturalmente acusa ausencia de artefatos publicados, o que precisa estar documentado como estado esperado e nao como misterio;
- a prova completa de cliente, SDDM, login e sessao ainda depende de harness de laboratorio com libvirt/QEMU, nao de um comando suportado diretamente no host instalado;
- automacoes por SSH depois de reinstalacao sofrem com churn de host key se o ambiente de lab nao limpar `known_hosts`.

Esses itens nao anulam Day-0 quando documentados e cobertos por harness, mas impedem vender a operacao como "sem esforco" se permanecerem implícitos.

## Fluxo canonico de aceitacao

### 1. Contrato estatico e de publish

Executar no checkout de desenvolvimento:

```bash
cd ~/code/ragos
bash ./scripts/tests/test-day0-contract.sh
```

Essa bateria precisa validar ao menos:

- contrato da live media do instalador;
- contrato de first publish channel-first;
- contratos do `ragc`;
- contratos de inventario e guardrails de runtime;
- referencia explicita ao harness destrutivo da reinstalacao limpa.

### 2. Prova destrutiva da reinstalacao limpa

Executar em laboratorio controlado:

```bash
cd ~/code/ragos
bash ./scripts/lab/validate-srv-rag-libvirt.sh --build-iso
```

O harness destrutivo precisa provar:

- UI live da ISO;
- instalacao unattended;
- reboot em disco;
- SSH no host instalado;
- mounts e servicos criticos;
- runtime persistente;
- primeiro publish;
- boot de cliente;
- SDDM, login, Plasma e `/home` por NFS.

## Evidencia minima exigida

Toda aceitacao Day-0 precisa dizer explicitamente:

- o que foi provado;
- o que nao foi provado;
- riscos remanescentes;
- local dos logs, screenshots e manifests usados como evidencia.

Sem isso, a reinstalacao limpa nao conta como aceite operacional.

## Bloqueios de release

Os itens abaixo sao bloqueio de release enquanto nao houver prova ou classificacao formal:

- o host instalado nao sobe com os servicos base operacionais;
- o primeiro publish falha ou exige editar estado fora do contrato documentado;
- o cliente nao chega em SDDM ou nao consegue abrir sessao;
- `/home` por NFS nao monta para o usuario da sessao;
- o contrato Day-0 nao tem harness reproduzivel e documentacao canonica coerente.

## Fora do contrato Day-0

Day-0 nao cobre por padrao:

- redesign visual novo;
- publicacao em KDE Store;
- limpeza de legado visual alem do necessario para prova;
- shutdown ordering, exceto quando bloquear diretamente o boot, login ou publish;
- automacoes de laboratorio experimentais sem relacao direta com a reinstalacao limpa.
