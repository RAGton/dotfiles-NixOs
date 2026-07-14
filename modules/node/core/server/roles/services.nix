{
  config,
  lib,
  pkgs,
  nodeServerIp,
  nodeHttpPort,
  nodeMgmtInterface,
  nodeMgmtPrefixLength,
  nodeInventoryDir ? "/etc/node-inventory",
  nodeInventoryRequireNonEmpty ? true,
  ...
}:

let
  # Subnet /24 derivada do IP do servidor (ex: 192.168.100.10 → 192.168.100.0/24)
  lanOctets = lib.strings.splitString "." nodeServerIp;
  lanPrefix = lib.concatStringsSep "." (lib.lists.take 3 lanOctets);
  lanSubnet = "${lanPrefix}.0/24";
  dhcpRange = "${lanPrefix}.100,${lanPrefix}.150,12h";
  inventoryFile = "${nodeInventoryDir}/clients.nix";
  inventoryRuntimeDir = "/run/node-inventory";
  inventoryDnsmasqHostsFile = "${inventoryRuntimeDir}/dnsmasq-hosts.conf";
  inventoryIpxeMacDir = "/srv/http/by-mac";
  inventoryLibPath = ../network/clients-inventory-lib.nix;

  renderInventoryScript = pkgs.writeShellApplication {
    name = "node-render-inventory";
    runtimeInputs = with pkgs; [
      nix
      jq
      coreutils
    ];
    text = ''
            set -euo pipefail

            inventory_path="''${1:-${inventoryFile}}"
            output_file="''${2:-${inventoryDnsmasqHostsFile}}"
            output_dir="$(dirname "$output_file")"
            routes_dir="${inventoryIpxeMacDir}"
            routes_parent="$(dirname "$routes_dir")"

            mkdir -p "$output_dir"
            mkdir -p "$routes_parent"

            if [[ ! -f "$inventory_path" ]]; then
              ${
                if nodeInventoryRequireNonEmpty then
                  ''
                    echo "NODE: inventario externo ausente em $inventory_path" >&2
                    echo "NODE: crie $inventory_path e mantenha o inventario em /etc/node-inventory." >&2
                    exit 1
                  ''
                else
                  ''
                              mkdir -p "$(dirname "$inventory_path")"
                              cat > "$inventory_path" <<'EOF'
                    [
                    ]
                    EOF
                              chmod 0644 "$inventory_path"
                  ''
              }
            fi

            inventory_json="$(
              nix-instantiate \
                --eval \
                --strict \
                --json \
                --argstr inventoryPath "$inventory_path" \
                --arg requireNonEmpty ${if nodeInventoryRequireNonEmpty then "true" else "false"} \
                --expr '
                  { inventoryPath, requireNonEmpty }:
                    let
                      lib = import ${pkgs.path + "/lib"};
                      inventoryLib = import ${inventoryLibPath} { inherit lib; };
                      inventory = import (/. + inventoryPath);
                      validated = inventoryLib.validateInventoryWithPolicy {
                        inherit inventory requireNonEmpty;
                      };
                      failures = builtins.map
                        (assertion: assertion.message)
                        (builtins.filter (assertion: !assertion.assertion) validated.assertions);
                    in
                    if failures != [ ] then
                      throw (builtins.concatStringsSep "\n" failures)
                    else
                      {
                        inventoryPath = inventoryPath;
                        clients = inventory;
                        dhcpHosts = validated.dhcpHosts;
                        ipxeRoutes = validated.ipxeRoutes;
                      }
                '
            )"

            tmp_file="$(mktemp "$output_dir/dnsmasq-hosts.conf.tmp.XXXXXX")"
            tmp_routes_dir="$(mktemp -d "$routes_parent/by-mac.tmp.XXXXXX")"
            chmod 0755 "$tmp_routes_dir"
            {
              printf '# gerado por node-render-inventory\n'
              printf '# source=%s\n' "$inventory_path"
              printf '%s\n' "$inventory_json" | jq -r '.dhcpHosts[] | "dhcp-host=" + .'
            } > "$tmp_file"

            while IFS= read -r route; do
              [[ -n "$route" ]] || continue
              mac="$(jq -r '.mac' <<<"$route")"
              channel="$(jq -r '.channel' <<<"$route")"
              release_track="$(jq -r '.releaseTrack' <<<"$route")"
              profile="$(jq -r '.profile' <<<"$route")"
              client_profile="$(jq -r '.clientProfile' <<<"$route")"
              boot_method="$(jq -r '.bootMethod' <<<"$route")"
              hardware_class="$(jq -r '.hardwareClass' <<<"$route")"
              hostname="$(jq -r '.hostname' <<<"$route")"
              ip_addr="$(jq -r '.ip' <<<"$route")"
              cat > "$tmp_routes_dir/''${mac}.ipxe" <<EOF
      #!ipxe

      # host=''${hostname} ip=''${ip_addr} channel=''${channel} releaseTrack=''${release_track} profile=''${profile} clientProfile=''${client_profile} hardwareClass=''${hardware_class} bootMethod=''${boot_method}

      chain --replace http://${nodeServerIp}:${toString nodeHttpPort}/''${channel}.ipxe || goto failed

      :failed
      echo Inventario do MAC ''${mac} apontou para o canal ''${channel}, mas o chain falhou.
      shell
      EOF
            done < <(printf '%s\n' "$inventory_json" | jq -c '.ipxeRoutes[]')

            chmod 0644 "$tmp_file"
            find "$tmp_routes_dir" -type f -name '*.ipxe' -exec chmod 0644 '{}' +
            mv -f "$tmp_file" "$output_file"
            rm -rf "$routes_dir"
            mv -f "$tmp_routes_dir" "$routes_dir"
    '';
  };

  applyInventoryScript = pkgs.writeShellApplication {
    name = "node-inventory-apply";
    runtimeInputs = [
      renderInventoryScript
      pkgs.systemd
    ];
    text = ''
      set -euo pipefail
      node-render-inventory ${lib.escapeShellArg inventoryFile} ${lib.escapeShellArg inventoryDnsmasqHostsFile}
      exec systemctl restart dnsmasq.service
    '';
  };

in
{
  assertions = [
    {
      assertion = nodeMgmtPrefixLength == 24;
      message = "NODE: DHCP declarativo do srv-rag atualmente exige mgmtPrefixLength=24 para evitar drift silencioso de rede.";
    }
  ];

  environment.systemPackages = [
    renderInventoryScript
    applyInventoryScript
  ];
  environment.etc."node-inventory/clients.nix".source = "/var/lib/node/inventory/clients.nix";
  environment.etc."node-inventory/README.md".source = ../network/clients-inventory.README.md;
  environment.etc."node-inventory/clients.template.nix".source =
    ../network/clients-inventory.bootstrap.nix;

  warnings =
    lib.optional (!nodeInventoryRequireNonEmpty)
      "NODE: inventario externo vazio foi explicitamente permitido. Isso reduz a protecao fail-closed do cadastro de clientes.";

  services.chrony = {
    enable = true;
    enableRTCTrimming = false;
    extraConfig = ''
      allow ${lanSubnet}
      local stratum 10 orphan
    '';
  };

  services.dnsmasq = {
    enable = true;

    settings = {
      conf-file = inventoryDnsmasqHostsFile;

      # Interface LAN — ajuste conforme hardware (ip link)
      interface = nodeMgmtInterface;
      bind-interfaces = true;

      domain-needed = true;
      bogus-priv = true;

      # Pool DHCP geral
      dhcp-range = dhcpRange;

      enable-tftp = true;
      tftp-root = "/srv/tftp";

      dhcp-match = "set:ipxe,175";
      dhcp-ignore-names = true;

      dhcp-boot = [
        "tag:ipxe,http://${nodeServerIp}:${toString nodeHttpPort}/boot.ipxe"
        "tag:!ipxe,EFI/BOOT/BOOTX64.EFI"
      ];

      dhcp-ignore = [ "tag:!known" ];
      dhcp-authoritative = true;
    };
  };

  services.nginx = {
    enable = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    virtualHosts."pxe" = {
      listen = [
        {
          addr = nodeServerIp;
          port = nodeHttpPort;
        }
      ];
      # /srv/http contém boot.ipxe e o symlink netboot/ → /srv/data/images
      # Estrutura acessível via HTTP:
      #   /boot.ipxe
      #   /netboot/current/bzImage
      #   /netboot/current/initrd
      root = "/srv/http";
      extraConfig = "autoindex off;";
    };
  };

  # Dirs de runtime gerenciados aqui (persistentes ficam em storage.nix)
  systemd.tmpfiles.rules = [
    "d /srv/http  0755 root root -"
    "d /var/lib/node/inventory 0755 root root -"
    "f /var/lib/node/inventory/clients.nix 0644 root root -"
    "d ${inventoryRuntimeDir} 0755 root root -"
    "d ${inventoryIpxeMacDir} 0755 root root -"
  ];

  system.activationScripts.nodeInventory = lib.stringAfter [ "etc" ] ''
        inventory_dir=${lib.escapeShellArg nodeInventoryDir}
        inventory_file=${lib.escapeShellArg inventoryFile}
        require_non_empty="${if nodeInventoryRequireNonEmpty then "1" else "0"}"
        mkdir -p "$inventory_dir"
        if [[ ! -e "$inventory_file" && "$require_non_empty" != "1" ]]; then
          cat > "$inventory_file" <<'EOF'
    [
    ]
    EOF
          chmod 0644 "$inventory_file"
        fi
        if [[ ! -e "$inventory_dir/README.md" ]]; then
          cp -f ${lib.escapeShellArg ../network/clients-inventory.README.md} "$inventory_dir/README.md"
          chmod 0644 "$inventory_dir/README.md"
        fi
        if [[ ! -e "$inventory_dir/clients.template.nix" ]]; then
          cp -f ${lib.escapeShellArg ../network/clients-inventory.bootstrap.nix} "$inventory_dir/clients.template.nix"
          chmod 0644 "$inventory_dir/clients.template.nix"
        fi
        echo "NODE: validando inventario externo em ${inventoryFile}" >&2
        ${renderInventoryScript}/bin/node-render-inventory ${lib.escapeShellArg inventoryFile} ${lib.escapeShellArg inventoryDnsmasqHostsFile}
  '';

  systemd.services.dnsmasq = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig.ExecStartPre = [
      "${renderInventoryScript}/bin/node-render-inventory ${lib.escapeShellArg inventoryFile} ${lib.escapeShellArg inventoryDnsmasqHostsFile}"
    ];
  };

  services.nfs.settings.nfsd.threads = 16;

  services.nfs = {
    server = {
      enable = true;

      exports = ''
        # /nix/store — somente leitura para a LAN
        /nix/store ${lanSubnet}(ro,async,no_subtree_check,no_root_squash,insecure)

        # Homes persistentes — disco de dados separado
        /srv/data/home ${lanSubnet}(rw,sync,no_subtree_check,root_squash,insecure)
      '';
    };

    settings = {
      nfsd = {
        vers3 = false;
        vers4 = true;
        tcp = true;
      };
    };
  };
}
