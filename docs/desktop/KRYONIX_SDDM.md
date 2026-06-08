# Kryonix Aurora — Tema SDDM

Tema próprio do greeter (login gráfico) do Kryonix: **dark navy**, accent
`#38BDF8`, minimalista, em QtQuick, com **arte SVG própria** (sem assets
externos baixados da internet) e ativação **declarativa e opt-in**.

> ⚠️ **Risco — login gráfico.** O SDDM é a porta de entrada do sistema. Um tema
> quebrado pode impedir o login pela interface. **Nunca** ative direto em
> produção sem antes validar (build do pacote + `sddm-greeter --test-mode`). O
> default seguro é `breeze`, e o rollback é trivial (voltar para `breeze`).

## Estrutura

```txt
desktop/sddm/kryonix-aurora/
├── Main.qml                 # raiz do greeter (QtQuick 2.15)
├── metadata.desktop         # MainScript=Main.qml, ConfigFile=theme.conf
├── theme.conf               # background + tokens da paleta (exposto como `config`)
├── Colors.js                # paleta (fonte de verdade do QML; .pragma library)
├── components/
│   ├── Clock.qml            # relógio + data
│   ├── InputField.qml       # campo "pílula" (usuário/senha)
│   ├── PillButton.qml       # botão accent
│   ├── LoginCard.qml        # card central (avatar, usuário, senha, Entrar)
│   ├── SessionSelector.qml  # chips de sessão (sessionModel)
│   └── PowerBar.qml         # suspender / reiniciar / desligar
└── assets/                  # SVG próprio (background, logo, avatar, ícones)

packages/kryonix-sddm-theme.nix    # empacota o tema em share/sddm/themes/kryonix-aurora
```

O QML usa **apenas `import QtQuick 2.15`** + a pasta `components/` (sem
`QtQuick.Controls`), para minimizar dependências de módulos QML no greeter.
Os objetos do SDDM (`sddm`, `userModel`, `sessionModel`, `keyboard`,
`screenModel`, `config`) são context properties globais — acessíveis em
qualquer componente. Login via `sddm.login(user, password, sessionIndex)`;
energia via `sddm.suspend()/reboot()/powerOff()` (respeitando `can*`).

## Ativar (opt-in — não troca o default global)

No host (ex.: `hosts/inspiron/default.nix` no downstream `/etc/kryonixos`):

```nix
kryonix.desktop.kde.sddm.theme = "kryonix-aurora";
```

Isso, no módulo `modules/nixos/desktop/kde/default.nix`:

- adiciona `pkgs.kryonix-sddm-theme` ao sistema
  (`/run/current-system/sw/share/sddm/themes/kryonix-aurora`);
- seta `services.displayManager.sddm.theme = "kryonix-aurora"`;
- injeta `kdePackages.qtsvg` em `sddm.extraPackages` (renderização do SVG).

Em `"breeze"` (default) **nada** disso acontece — o greeter Breeze padrão é
mantido (fallback).

## Validar SEM aplicar

```bash
cd /etc/kryonix

# 1) Build do pacote do tema (precisa dos arquivos tracked no git):
nix build .#kryonix-sddm-theme --no-link -L

# 2) Render do greeter em modo teste (sem tocar no sistema):
THEME_PATH="$(nix build .#kryonix-sddm-theme --no-link --print-out-paths)/share/sddm/themes/kryonix-aurora"
sddm-greeter --test-mode --theme "$THEME_PATH"   # SDDM Qt6: pode ser `sddm-greeter6`
```

Se `sddm-greeter` não existir no ambiente atual, isso é **pendência de
ambiente** (não falha do tema) — valide ao menos o build do pacote e do host.

## Rollback

1. **Sem rebuild ainda:** basta não setar a opção (default já é `breeze`).
2. **Já aplicado:** volte para o Breeze e rebuild:
   ```nix
   kryonix.desktop.kde.sddm.theme = "breeze";
   ```
   ```bash
   kryonix test   # valida a geração; depois kryonix switch
   ```
3. **Greeter travado (não loga):** no boot, escolha a **geração anterior** no
   menu do bootloader (rollback declarativo do NixOS), ou via TTY
   (`Ctrl+Alt+F3`) → login → `kryonix switch` para a config com `breeze`.

## Personalização

- **Paleta:** edite `Colors.js` (fonte de verdade do QML). `theme.conf`
  documenta os tokens e permite trocar o `background`.
- **Arte:** substitua os SVG em `assets/` (mantendo os nomes), sem baixar nada
  da internet.
