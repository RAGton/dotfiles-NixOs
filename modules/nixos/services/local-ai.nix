{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Ativa o Ollama Local apenas para modelos de utilidade de sistema
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
    loadModels = [ "qwen2.5-coder:1.5b" ];
  };

  # Script de ativação do sistema para garantir que os modelos leves existam localmente
  systemd.services.kryonix-local-models-warmup = {
    description = "Garanta que as SLMs leves de gerenciamento local estejam baixadas";
    after = [ "ollama.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.curl}/bin/curl -X POST http://localhost:11434/api/pull -d '{\"name\": \"qwen2.5-coder:1.5b\"}'";
      RemainAfterExit = true;
    };
  };
}
