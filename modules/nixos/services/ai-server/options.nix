# =============================================================================
# Module: kryonix.services.aiServer — options
#
# O que é:
# - Define estritamente a API declarativa do Kryonix AI Server:
#   tipos, defaults e sub-opções. Nenhuma seção `config` deve aparecer aqui.
#
# Por quê:
# - Manter este arquivo puramente declarativo (apenas `options`) torna
#   seguro avaliar o módulo com `enable = false` (default) sem causar
#   qualquer efeito colateral: nenhum usuário é criado, nenhum serviço é
#   ativado, nenhuma porta é aberta, nenhum segredo é exigido.
#
# Convenção:
# - Caminho no filesystem: services/ai-server/ (kebab-case)
# - Option pública:        kryonix.services.aiServer (camelCase)
# - Defaults seguros:      enable=false, autonomy.level=readOnly,
#                          remoteAccess.mode=tailscale, sem exposição pública.
#
# NÃO toca:
# - kryonix.services.aura       (produto/persona — PR #95)
# - kryonix.services.brain      (já fala multi-backend; PR 2 integra)
# - kryonix.services.llama-cpp  (já tem hardening+CUDA+DynamicUser; PR 2 integra)
# - hosts/, profiles/, users/, features/
# =============================================================================
{
  config,
  lib,
  ...
}:
let
  cfg = config.kryonix.services.aiServer;
in
{
  options.kryonix.services.aiServer = {
    enable = lib.mkEnableOption ''
      Kryonix AI Server (orquestrador 24/7 declarativo para agentes
      locais com inferência opcional, permissões por capacidade, acesso
      remoto enumerado e autonomia granular). Inerte quando false.
    '';

    # ── Agente ────────────────────────────────────────────────────
    agent = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Habilita a integração com um provider de agente. Por padrão
          inerte. Integração com Podman/Hermes é adicionada em PR 2
          (kryx-agent.nixosModules.default).
        '';
      };

      provider = lib.mkOption {
        type = lib.types.enum [
          "hermes"
          "openclaw"
          "custom"
        ];
        default = "hermes";
        description = ''
          Backend do agente executado pelo AI Server. Valores adicionais
          (e.g. "openclaw", "custom") viram configuráveis sem quebrar
          hosts que já declaram o default.
        '';
      };

      runtime = lib.mkOption {
        type = lib.types.enum [
          "podman"
          "systemd"
        ];
        default = "podman";
        description = ''
          Runtime no qual o agente é executado. "podman" alinha com o
          stack atual do Hermes (oci-containers). "systemd" virá como
          alternativa em PR 2 para hosts sem podman.
        '';
      };
    };

    # ── Inferência ────────────────────────────────────────────────
    inference = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Habilita um backend de inferência local. Provider selecionado
          por `inference.provider`. Provider "external" não exige
          modelPath (apenas consome URL declarada em PR 2).
        '';
      };

      provider = lib.mkOption {
        type = lib.types.enum [
          "llama-cpp"
          "ollama"
          "external"
        ];
        default = "llama-cpp";
        description = ''
          Backend de inferência. "llama-cpp" e "ollama" rodam localmente
          (com overlay CUDA já empacotado). "external" delega para um
          endpoint HTTP declarado em PR 2.
        '';
      };

      modelPath = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Caminho para o arquivo de modelo. Obrigatório quando
          `inference.enable = true` E `inference.provider = "llama-cpp"`
          (validado em assertions.nix). Para "ollama" aceita nome de
          modelo (validado em PR 2); para "external" deve ficar null.
        '';
      };
    };

    # ── Autonomia ─────────────────────────────────────────────────
    autonomy = {
      level = lib.mkOption {
        type = lib.types.enum [
          "readOnly"
          "operator"
          "developer"
          "maintainer"
          "unrestricted"
        ];
        default = "readOnly";
        description = ''
          Nível de autonomia do agente.
          - readOnly:    logs, git read, diagnósticos.
          - operator:    + start/stop de serviços whitelisted.
          - developer:   + commits locais em worktrees.
          - maintainer:  + push para branches whitelisted.
          - unrestricted: tudo (requer acknowledgeUnrestricted).
        '';
      };

      acknowledgeUnrestricted = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Confirmação obrigatória quando `autonomy.level = "unrestricted"`.
          Sem isso, a avaliação do Nix falha com assertion.
        '';
      };
    };

    # ── Acesso remoto ─────────────────────────────────────────────
    remoteAccess = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "disabled"
          "lan"
          "tailscale"
          "wireguard"
          "publicSsh"
          "reverseProxy"
          "cloudflareTunnel"
        ];
        default = "tailscale";
        description = ''
          Canal pelo qual serviços internos podem ser acessados de fora
          do host. "disabled" = nada. "tailscale" = VPN mesh (recomendado).
          "publicSsh" exige `acknowledgePublicExposure = true`.
          Aplicação efetiva acontece em PR 7 (Glacier) — por enquanto
          esta option é puramente declarativa.
        '';
      };

      acknowledgePublicExposure = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Confirmação obrigatória quando `remoteAccess.mode = "publicSsh"`.
          Sem isso, a avaliação do Nix falha com assertion.
        '';
      };
    };
  };
}
