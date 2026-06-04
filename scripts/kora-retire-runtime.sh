#!/usr/bin/env bash
# =============================================================================
# kora-retire-runtime.sh — aposenta o RUNTIME da Kora no host (manual, seguro).
#
# A Kora foi removida do repositório (código/módulo/CLI). Este script desativa
# os serviços systemd remanescentes e MOVE (não apaga) os dados/secrets para
# *.retired.<timestamp>, permitindo rollback. Rode COMO ROOT, no host, depois
# do `nixos-rebuild switch` que removeu o módulo Kora.
#
# NÃO apaga nada destrutivamente. Exige confirmação explícita.
# =============================================================================
set -uo pipefail

TS="$(date +%Y%m%d-%H%M%S)"

echo "Este script vai:"
echo "  1) desativar kora.service / kora-memory-worker.{service,timer} (se existirem)"
echo "  2) mover /var/lib/kryonix/kora      -> /var/lib/kryonix/kora.retired.$TS"
echo "  3) mover /etc/kryonix/kora.env      -> /etc/kryonix/kora.env.retired.$TS"
echo
read -r -p "Confirmar aposentadoria do runtime da Kora? digite 'aposentar': " ans
[ "$ans" = "aposentar" ] || { echo "Abortado."; exit 1; }

if [ "$(id -u)" -ne 0 ]; then
  echo "Rode como root (sudo)." >&2; exit 1
fi

systemctl disable --now kora.service kora-memory-worker.service kora-memory-worker.timer 2>/dev/null || true

[ -e /var/lib/kryonix/kora ] && mv -v /var/lib/kryonix/kora "/var/lib/kryonix/kora.retired.$TS"
[ -e /etc/kryonix/kora.env ] && mv -v /etc/kryonix/kora.env "/etc/kryonix/kora.env.retired.$TS"

echo
echo "Concluído. Dados preservados em *.retired.$TS (não foram apagados)."
echo "Para reverter: pare aqui e mova de volta. Para descartar de vez (irreversível),"
echo "remova manualmente os diretórios *.retired.* depois de confirmar que não precisa."
