# =============================================================================
# Autor: Gabriel Aguiar Rocha (RAGton)
#
# O que é:
# - Módulo Home Manager para configurar `git` e `delta`.
# - Habilita assinatura de commits via chave SSH quando `userConfig.gitKey` for do tipo `ssh-*`.
#
# Por quê:
# - Centraliza identidade (nome/email), preferências e assinatura em todos os hosts.
# - Evita falhas ao habilitar assinatura quando a chave não é SSH.
#
# Como:
# - Cria `~/.config/git/allowed_signers` somente quando a chave é SSH.
# - Configura `programs.git.signing` apenas quando existe chave.
# - Habilita `delta` para pager/diff melhorado.
#
# Riscos:
# - Se `userConfig.gitKey` estiver incorreta, a assinatura pode falhar e o `git` vai recusar commits.
# - `allowed_signers` é gerado a partir de email/chave; mantenha `userConfig` consistente.
# =============================================================================
{
  lib,
  userConfig,
  config,
  ...
}:
{
  home.file = {
    ".ssh/config".force = true;
  }
  // (
    let
      hasGitKey = userConfig.gitKey != "";
      isSshSigningKey = hasGitKey && lib.hasPrefix "ssh-" userConfig.gitKey;
    in
    if isSshSigningKey then
      {
        ".config/git/allowed_signers" = {
          text = "${userConfig.email} ${userConfig.gitKey}\n";
          force = true;
        };
      }
    else
      { }
  );

  # Forçar a criação da config do Git para evitar conflitos de ativação
  xdg.configFile."git/config".force = true;

  # Git: identidade e preferências globais do usuário.
  programs.git = {
    enable = true;
    settings =
      let
        hasGitKey = userConfig.gitKey != "";
        isSshSigningKey = hasGitKey && lib.hasPrefix "ssh-" userConfig.gitKey;
      in
      lib.mkMerge [
        {
          user = {
            email = userConfig.email;
            name = userConfig.fullName;
          };
          pull.rebase = "true";
          init.defaultBranch = "main";
          push.autoSetupRemote = true;
        }
        (lib.mkIf isSshSigningKey {
          gpg = {
            format = "ssh";
            ssh.allowedSignersFile = "~/.config/git/allowed_signers";
          };
        })
      ];

    # Só habilita assinatura se a chave estiver definida.
    signing =
      let
        hasGitKey = userConfig.gitKey != "";
        isSshSigningKey = hasGitKey && lib.hasPrefix "ssh-" userConfig.gitKey;
        signingKey =
          if isSshSigningKey then
            (
              if userConfig ? gitSigningKeyPath then
                "${config.home.homeDirectory}/${userConfig.gitSigningKeyPath}"
              else
                "${config.home.homeDirectory}/.ssh/id_ed25519"
            )
          else
            userConfig.gitKey;
      in
      lib.mkIf hasGitKey {
        key = signingKey;
        signByDefault = true;
      };
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
    settings = {
      git_protocol = "ssh";
      aliases.co = "pr checkout";
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "github.com" = {
        Hostname = "github.com";
        User = "git";
        IdentitiesOnly = "yes";
        IdentityFile =
          if userConfig ? gitSigningKeyPath then "~/${userConfig.gitSigningKeyPath}" else "~/.ssh/id_ed25519";
        AddKeysToAgent = "yes";
        PreferredAuthentications = "publickey";
      };

      "glacier-publico" = {
        Hostname = "168.227.127.73";
        User = "rocha";
        Port = 2224;
        IdentityFile = [
          "~/.ssh/id_ed25519"
          "~/.ssh/node-ve"
        ];
        IdentitiesOnly = "yes";
        ServerAliveInterval = 30;
        ServerAliveCountMax = 3;
      };

      "glacier-public" = {
        Hostname = "168.227.127.73";
        User = "rocha";
        Port = 2224;
        IdentityFile = [
          "~/.ssh/id_ed25519"
          "~/.ssh/node-ve"
        ];
        IdentitiesOnly = "yes";
        ServerAliveInterval = 30;
        ServerAliveCountMax = 3;
      };
    };
  };

  # Solução resiliente para o erro "Bad owner or permissions on ~/.ssh/config"
  # que ocorre quando arquivos do Nix store são gerados como nobody:nogroup.
  home.activation.sshConfigPermissions = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ -L "$HOME/.ssh/config" ]; then
      target=$(readlink "$HOME/.ssh/config")
      rm -f "$HOME/.ssh/config"
      cp "$target" "$HOME/.ssh/config"
      chmod 600 "$HOME/.ssh/config"
    fi
  '';

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      keep-plus-minus-markers = true;
      light = false;
      line-numbers = true;
      navigate = true;
      width = 280;
    };
  };
}
