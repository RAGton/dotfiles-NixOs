{ config, lib, pkgs, ... }:

{
  # Ativa o Ollama Local apenas para modelos de utilidade de sistema
  services.ollama = {
    enable = true;
    # Desativa carregamento persistente em background para poupar bateria do notebook
    acceleration = null; # Deixa rodar leve na CPU/iGPU se não houver dGPU ativa
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
