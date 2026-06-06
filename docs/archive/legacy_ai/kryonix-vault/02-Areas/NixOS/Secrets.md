# Secrets no NixOS

## O que é
Gerenciamento declarativo de dados sensíveis (senhas, chaves de API, tokens) em sistemas NixOS. O desafio fundamental é que o Nix Store é legível por qualquer usuário local, portanto, segredos não podem ser injetados diretamente como strings em arquivos de configuração tradicionais.

## Como funciona
O modelo de segurança do Kryonix exige que segredos sejam descriptografados apenas no momento da ativação do sistema (runtime) e armazenados em locais protegidos (geralmente `/run/secrets` ou `/var/lib/kryonix/secrets`) com permissões restritas.

### Mecanismos Principais:
1. **sops-nix**: Usa criptografia baseada em chaves SSH ou chaves de host. Permite versionar segredos criptografados no Git.
2. **agenix**: Alternativa leve focada em chaves SSH (age).
3. **Environment Variables**: Carregamento via scripts de ativação para evitar o Nix Store.

## Uso prático
No Kryonix, preferimos **sops-nix** pela sua robustez e suporte a múltiplos destinos.

### Fluxo de Trabalho:
1. Criar segredo: `sops secrets/api-key.yaml`
2. Declarar no Nix:
   ```nix
   sops.secrets."api_key" = {
     owner = "kryonix";
     group = "users";
     mode = "0400";
   };
   ```
3. Acessar no serviço: `path = config.sops.secrets.api_key.path;`

## Exemplos
### Configuração de um Segredo para o LightRAG
```nix
sops.secrets."lightrag/anthropic_key" = {
  format = "yaml";
  sopsFile = ../../secrets/ai.yaml;
};

systemd.services.lightrag = {
  serviceConfig.EnvironmentFile = config.sops.secrets."lightrag/anthropic_key".path;
};
```

## Problemas comuns
- **Insecure string**: Usar `${builtins.readFile ./secret}` resulta no segredo sendo copiado para o Nix Store em texto puro. **NUNCA FAÇA ISSO**.
- **Permissão negada**: O usuário do serviço não tem permissão de leitura no arquivo descriptografado em `/run/secrets`.
- **Race Condition**: O serviço inicia antes do sops-nix descriptografar o arquivo.

## Boas práticas
- Use chaves de host (`/etc/ssh/ssh_host_ed25519_key.pub`) para descriptografar segredos da máquina.
- Rotacione segredos a cada 90 dias ou em caso de desligamento de membros da equipe.
- Use arquivos `.yaml` ou `.json` criptografados para agrupar segredos por domínio (ex: `network.yaml`, `ai.yaml`).
- Sempre valide se o segredo não está presente no `nix-store -q --references $(which config)`.

## Links
- [[01-MOCs/Mapa - Segurança]]
- [[06-Playbooks/Playbook - Auditoria de Secrets]]
- [sops-nix Documentation](https://github.com/Mic92/sops-nix)
