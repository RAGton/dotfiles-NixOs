# Aura Failure Patterns — Kryonix

## RemoteAccess mostra "IP não detectado"

### Causa conhecida

`nmcli device show` retorna:

```txt
IP4.ADDRESS[1]:192.168.122.X/24
```

Parser errado procurava:

```txt
IP4.ADDRESS:
```

### Correção

Parser deve aceitar:

```rust
line.starts_with("IP4.ADDRESS")
line.split_once(':')
```

E validar:

* não vazio;
* não 0.0.0.0;
* não 127.*;
* não 169.254.*;
* IPv4 válido.

---

## Porta 8080 timeout

### Diagnóstico

Se:

```bash
ping <VM_IP>
```

funciona, mas:

```bash
nc -vz -w 2 <VM_IP> 8080
```

falha, o problema é:

* firewall;
* backend bind;
* serviço backend;
* ISO antiga.

### Correção conhecida

No módulo web-kiosk:

```nix
networking.firewall.allowedTCPPorts = lib.mkIf (cfg.listenAddress != "127.0.0.1") [
  cfg.port
];
```

---

## nixos-install falha com pure evaluation

### Erro

```txt
access to absolute path '/nix/store/kryonix/flake.nix' is forbidden in pure evaluation mode
```

### Regras

Não corrigir com `--impure`.

Investigar primeiro:

```bash
rg -n "/nix/store/kryonix|path:/nix/store|KRYONIX_ENGINE_SOURCE|inputs.self.outPath"
```

Verificar dentro da ISO:

```bash
/mnt/etc/kryonix
/mnt/etc/kryonixos
/mnt/etc/kryonixos/flake.nix
/mnt/etc/kryonix/flake.nix
```

### Critério correto

`/mnt/etc/kryonixos/flake.nix` deve usar:

```nix
inputs.kryonix.url = "path:../kryonix";
```

E `/mnt/etc/kryonix` deve ser diretório real com `flake.nix`.
