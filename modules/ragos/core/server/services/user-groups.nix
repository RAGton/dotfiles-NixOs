# ─────────────────────────────────────────────────────────────────────────────
# USER GROUPS AND SECTORS — Organizações dinâmicas de usuários por setores
#
# Estrutura:
#   - Grupos "admin" (GID 3000) + "public" (GID 3001): criados DURANTE INSTALAÇÃO
#   - Apenas admin user (criado na instalação) tem acesso ao grupo "admin"
#   - Todos os usuários podem usar "public" com permissões apropriadas
#   - Grupos adicionais: criados dinamicamente via CLI `ragos group add`
#   - Setores: /srv/data/storage/<setor>/ criado sob demanda
#   - Permissões: configuráveis por grupo (rwx bits + members)
#
# Storage Layout:
#   /srv/data/storage/
#   ├── admin/          (criado na instalação, GID 3000)
#   ├── public/         (criado na instalação, GID 3001, acesso geral)
#   ├── <grupo1>/       (criado via: ragos group add)
#   ├── <grupo2>/
#   └── .archive/       (armazena grupos deletados)
#
# CLI para gerenciar:
#   ragos group add <nome> [--storage-quota 100G]
#   ragos group list
#   ragos group delete <nome> --archive
#   ragos group chmod <nome> <perms>         (ex: 0750, g+rw)
#   ragos group members <nome> [--add USER] [--remove USER]
#   ragos group permissions <nome>           (listar permissões atuais)
#
# Permissões Padrão:
#   - admin: membro é admin user, perms 0750 (rwx para owner+group)
#   - public: todos os usuários podem ler/escrever, perms 0770
# ─────────────────────────────────────────────────────────────────────────────

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  storageBase = "/srv/data/storage";

  # Script para criar novo grupo e storage correspondente (via CLI apenas)
  createSectorScript = pkgs.writeShellApplication {
    name = "ragos-create-sector";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.shadow
      pkgs.gnugrep
    ];
    text = ''
          set -euo pipefail
          
          group_name="$1"
          gid="$2"
          description="$3"
          storage_quota="$4"
          
          # Criar group no sistema
          groupadd -g "$gid" -f -r "$group_name" || true
          
          # Criar storage sector
          mkdir -p "${storageBase}/$group_name"
          chgrp "$gid" "${storageBase}/$group_name"
          chmod 0750 "${storageBase}/$group_name"
          
          # Criar arquivo de metadata
          cat > "${storageBase}/$group_name/.sector-meta" <<EOF
      GROUP=$group_name
      GID=$gid
      DESCRIPTION=$description
      STORAGE_QUOTA=$storage_quota
      CREATED_AT=$(date --iso-8601=seconds)
      EOF
          chmod 0640 "${storageBase}/$group_name/.sector-meta"
    '';
  };

  # Script para deletar setor
  deleteSectorScript = pkgs.writeShellApplication {
    name = "ragos-delete-sector";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.shadow
      pkgs.gnugrep
    ];
    text = ''
      set -euo pipefail

      group_name="$1"
      group_path="${storageBase}/$group_name"

      # Validar que não há usuários no grupo
      if getent group "$group_name" | grep -q "$group_name"; then
        live_users=$(getent group "$group_name" | cut -d: -f4)
        if [[ -n "$live_users" ]]; then
          echo "Erro: usuários ainda no grupo $group_name: $live_users" >&2
          exit 1
        fi
      fi

      # Mover storage para archive
      if [[ -d "$group_path" ]]; then
        timestamp=$(date +%Y%m%d-%H%M%S)
        mv "$group_path" "/srv/data/storage/.archive/$group_name-$timestamp"
      fi

      # Remover group do sistema
      groupdel "$group_name" 2>/dev/null || true
    '';
  };

in
{
  options.ragos.userGroups = {
    enable = mkEnableOption "RAGOS user groups and sector storage (dynamic creation via CLI)";
  };

  config = mkIf config.ragos.userGroups.enable {
    # -----------------------------------------------------------------------
    # Base storage directory (sem grupos automáticos)
    # Grupos "admin" e "public" são criados DURANTE INSTALAÇÃO
    # -----------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${storageBase} 0755 root root -"
      "d ${storageBase}/.archive 0700 root root -"
    ];

    # -----------------------------------------------------------------------
    # Scripts de gerenciamento de setores via CLI
    # -----------------------------------------------------------------------
    environment.systemPackages = [
      createSectorScript
      deleteSectorScript
    ];
  };
}
