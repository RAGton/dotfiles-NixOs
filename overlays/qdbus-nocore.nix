# qdbus-nocore: silencia coredump residual do qdbus em qttools 6.11.0
#
# O que é
# - Overlay que substitui o binário `qdbus` do `kdePackages.qttools` por um
#   wrapper shell. O binário original passa a se chamar `qdbus-real`.
#
# Por quê
# - O `qdbus` do qttools 6.11.0 segfaulta no exit (destrutor estático
#   `registerComplexDBusType::Hash::~Hash` → `QMetaType::unregisterMetaType`)
#   APÓS imprimir o resultado da chamada D-Bus. É cosmético, mas:
#   * systemd-coredump captura e enche /var/lib/systemd/coredump
#   * drkonqi dispara popup mesmo com `drkonqi-ignore-missing-buildid`
#   * journalctl polui com "Process ... (qdbus) of user ... dumped core"
# - O Kryonix já migrou suas próprias chamadas para `gdbus` (ver
#   desktop/kde/keybinds.nix). Callers Qt6 terceiros (plasma scripts,
#   kdialog, kio-extras, autostarts) ainda invocam `qdbus` pelo PATH —
#   não dá para patchear caller a caller.
#
# Como
# - `postFixup` move o binário ELF para `qdbus-real` e instala um stub
#   shell em `qdbus` que:
#     1. `ulimit -c 0` → kernel não escreve o dump (RLIMIT_CORE=0).
#     2. roda o `qdbus-real` capturando stdout.
#     3. se exit==139 (SIGSEGV) E stdout não vazio: trata como sucesso (0).
#        Em qttools 6.11.0 o crash é SEMPRE pós-impressão, então stdout
#        não vazio == método D-Bus completou.
#     4. qualquer outro exit code propaga intacto (erro real não é
#        suprimido — smoke negativo: `qdbus org.kde.NaoExiste` ainda falha).
#
# Quando remover
# - Quando o nixpkgs subir para qttools 6.12+ e o destrutor for corrigido.
#   O `[ -x "$bin" ]` faz o postFixup virar no-op se o layout mudar.
final: prev: {
  kdePackages = prev.kdePackages.overrideScope (
    _kfinal: kprev: {
      qttools = kprev.qttools.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          bin="$out/bin/qdbus"
          if [ -x "$bin" ] && [ ! -e "$out/bin/qdbus-real" ]; then
            mv "$bin" "$out/bin/qdbus-real"
            cat > "$bin" <<'WRAP'
          #!${prev.runtimeShell}
          # Wrapper instalado por overlays/qdbus-nocore.nix.
          ulimit -c 0 2>/dev/null || true
          out=$("''${0%/*}/qdbus-real" "$@")
          rc=$?
          if [ "$rc" -eq 139 ] && [ -n "$out" ]; then
            printf '%s\n' "$out"
            exit 0
          fi
          [ -n "$out" ] && printf '%s\n' "$out"
          exit "$rc"
          WRAP
            chmod +x "$bin"
          fi
        '';
      });
    }
  );
}
