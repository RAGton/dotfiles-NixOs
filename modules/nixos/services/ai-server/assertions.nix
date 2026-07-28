# =============================================================================
# Module: kryonix.services.aiServer — assertions
#
# O que é:
# - Quatro assertions mínimas que validam combinações inseguras entre
#   opções declaradas. Implementação viva em PR 2+; este arquivo só falha
#   cedo no `nix flake check`.
#
# Por quê:
# - Tornar erros de configuração LOCALIZÁVEIS (mensagem com hint) em vez
#   de silenciar combinações perigosas que explodem em runtime (Tailscale
#   off + SSH exposto, ou unrestricted sem acknowledgement, etc).
#
# Cada assertion tem:
# - predicate (cfg → bool)
# - mensagem clara citando o caminho da option
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
  config = {
    assertions = [
      # 1) Exposição pública exige acknowledgement explícito.
      {
        assertion =
          cfg.remoteAccess.mode != "publicSsh"
          || cfg.remoteAccess.acknowledgePublicExposure;
        message = ''
          kryonix.services.aiServer.remoteAccess: configurar
          mode = "publicSsh" exige acknowledgePublicExposure = true
          (confirmação declarativa de que você aceita a exposição
          direta da porta no MikroTik/IP público).
        '';
      }

      # 2) llama-cpp exige modelPath. Espelha o que llama-cpp.nix já faz,
      #    mas declarado também aqui para falhar cedo no eval do aiServer.
      {
        assertion =
          !cfg.inference.enable
          || cfg.inference.provider != "llama-cpp"
          || cfg.inference.modelPath != null;
        message = ''
          kryonix.services.aiServer.inference: provider = "llama-cpp"
          exige inference.modelPath apontando para um arquivo .gguf.
          Use provider = "external" para apontar apenas para uma URL.
        '';
      }

      # 3) Autonomia "unrestricted" exige acknowledgement.
      {
        assertion =
          cfg.autonomy.level != "unrestricted"
          || cfg.autonomy.acknowledgeUnrestricted;
        message = ''
          kryonix.services.aiServer.autonomy: level = "unrestricted"
          exige acknowledgeUnrestricted = true (o agente poderá
          executar qualquer comando no host através do helper
          kryx-agent-control, incluindo os que alteram estado
          persistente).
        '';
      }

      # 4) provider="custom" exige um comando explícito em PR 2+. Por
      #    enquanto, este slot fica inutilizado: assertion documenta a
      #    intenção sem quebrar nada (custom só vira funcional em PR 2).
      {
        assertion =
          cfg.agent.provider != "custom"
          || cfg.agent.command or null != null;
        message = ''
          kryonix.services.aiServer.agent: provider = "custom" exige
          declarar agent.command (caminho do binário). Implementação
          entra em PR 2 (kryx-agent-control). Por enquanto mantenha
          provider = "hermes" (default) ou "openclaw".
        '';
      }
    ];
  };
}
