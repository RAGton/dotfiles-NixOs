{ pkgs }:

pkgs.writeShellApplication {
  name = "kryonix";

  runtimeInputs = with pkgs; [
    coreutils
    gnumake
    git
    home-manager
    hostname
    nh
    nix
    ripgrep
  ];

  text = ''
    set -euo pipefail

    repo="''${KRYONIX_REPO:-/etc/kryonix}"
    if [ ! -d "$repo/.git" ]; then
      detected="$(git rev-parse --show-toplevel 2>/dev/null || true)"
      if [ -n "$detected" ]; then
        repo="$detected"
      fi
    fi

    usage() {
      printf '%s\n' \
        "kryonix <command>" \
        "" \
        "Commands:" \
        "  sync       Inicializa submodules no estado declarado pelo Git" \
        "  check      Executa nix flake check no repositório" \
        "  build      Compila o pacote padrão da CLI" \
        "  switch     Aplica o NixOS via nh os switch" \
        "  home       Aplica Home Manager para USER@HOST" \
        "  launcher   Abre o launcher de aplicativos" \
        "  doctor     Diagnóstico rápido do ambiente Kryonix"
    }

    cmd="''${1:-help}"
    if [ "$#" -gt 0 ]; then
      shift
    fi

    case "$cmd" in
      help|-h|--help)
        usage
        ;;
      sync)
        exec make -C "$repo" sync "$@"
        ;;
      check)
        exec nix flake check "path:$repo" --keep-going "$@"
        ;;
      build)
        if [ "$#" -gt 0 ]; then
          exec nix build "$@"
        fi
        exec nix build "path:$repo#kryonix" --no-link
        ;;
      switch)
        exec nh os switch "$repo" "$@"
        ;;
      home)
        target="''${1:-''${USER}@$(hostname)}"
        shift || true
        exec home-manager switch --flake "path:$repo#$target" "$@"
        ;;
      launcher)
        exec kryonix-launcher "$@"
        ;;
      doctor)
        echo "repo: $repo"
        if [ -d "$repo/.git" ]; then
          git -C "$repo" status --short
        fi
        echo
        echo "commands:"
        for bin in kryonix kryonix-launcher kryonix-menu kryonix-clipboard-menu kryonix-runner gtk-launch; do
          if command -v "$bin" >/dev/null 2>&1; then
            printf '  ok   %s -> %s\n' "$bin" "$(command -v "$bin")"
          else
            printf '  miss %s\n' "$bin"
          fi
        done
        echo
        legacy_r="r$(printf '%s' ofi)"
        legacy_w="w$(printf '%s' ofi)"
        legacy_pattern="\\b($legacy_r|$legacy_w)\\b"
        if rg -n "$legacy_pattern" "$repo" >/dev/null 2>&1; then
          echo "menu legado: encontrado"
          rg -n "$legacy_pattern" "$repo" || true
          exit 1
        fi
        echo "menu legado: ausente"
        ;;
      *)
        echo "kryonix: comando desconhecido: $cmd" >&2
        usage >&2
        exit 2
        ;;
    esac
  '';
}
