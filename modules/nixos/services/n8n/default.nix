# =============================================================================
# Módulo: n8n (Motor de automação e workflows locais)
#
# O que é:
# - n8n rodando localmente (127.0.0.1:5678) como orquestrador visual.
#
# Por quê:
# - Permite integrações da Aura/assistente através de Webhooks locais.
# - Integra Ollama, scripts e APIs de forma visual, 100% isolado da internet.
#
# Segurança:
# - Bind restrito a 127.0.0.1
# - Environment secrets em /etc/kryonix/n8n.env (não commitados).
# - Dados persistentes no state directory do n8n (DynamicUser).
# =============================================================================
{
  config,
  lib,
  ...
}:

let
  cfg = config.kryonix.services.n8n;
in
{
  options.kryonix.services.n8n = {
    enable = lib.mkEnableOption "Serviço local de workflows visuais (n8n)";
  };

  config = lib.mkIf cfg.enable {
    # Configurar o serviço NixOS nativo para o n8n
    services.n8n = {
      enable = true;
      openFirewall = false; # Fundamental: sem exposição externa.

      # Variáveis de ambiente configuradas no módulo (declarativas, não-secretas)
      environment = {
        N8N_HOST = "127.0.0.1";
        N8N_PORT = "5678";
        N8N_PROTOCOL = "http";
        WEBHOOK_URL = "http://127.0.0.1:5678/";
        GENERIC_TIMEZONE = "America/Cuiaba";
      };
    };

    # Ajustar o systemd service para carregar secrets via EnvironmentFile
    # A opção services.n8n usa DynamicUser, então ele cuidará dos dados persistentes em /var/lib/n8n
    systemd.services.n8n = {
      serviceConfig = {
        EnvironmentFile = [
          # Arquivo que o usuário deve criar contendo N8N_ENCRYPTION_KEY, etc.
          "-/etc/kryonix/n8n.env"
        ];
      };
    };
  };
}
