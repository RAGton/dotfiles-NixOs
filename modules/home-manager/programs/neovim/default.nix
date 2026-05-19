# =============================================================================
# Autor: rag
#
# O que é:
# - Módulo Home Manager para instalar e configurar o Neovim como editor padrão.
# - Empacota dependências de LSP/formatters/linters usadas no dia a dia.
# - Importa a configuração Lua (LazyVim) versionada neste repositório.
#
# Por quê:
# - Garante uma experiência consistente entre máquinas sem setup manual.
# - Evita “funciona numa máquina e na outra não” por falta de ferramentas.
#
# Como:
# - Usa `pkgs.neovim-unwrapped` e habilita providers (Node/Python/Ruby).
# - Declara `extraPackages` com ferramentas por linguagem.
# - Publica `./lazyvim` em `~/.config/nvim` via `xdg.configFile`.
#
# Riscos:
# - A lista de `extraPackages` pode aumentar tempo/tamanho do build.
# - Mudanças em `./lazyvim` afetam todas as máquinas que importarem este módulo.
# =============================================================================
{ pkgs, ... }:
{
  # Neovim: editor padrão e providers habilitados.
  programs.neovim = {
    enable = true;
    package = pkgs.neovim-unwrapped;
    defaultEditor = true;
    withNodeJs = true;
    withPython3 = true;
    withRuby = true;

    extraPackages = with pkgs; [
      black
      golangci-lint
      gopls
      gotools
      hadolint
      isort
      lua-language-server
      markdownlint-cli
      nixd
      nixfmt
      bash-language-server
      prettier
      pyright
      ruff
      shellcheck
      shfmt
      stylua
      terraform-ls
      tflint
      tree-sitter
      vscode-langservers-extracted
      yaml-language-server
    ];
  };

  # Importa a configuração Lua a partir deste repositório.
  # Para evitar conflitos de symlink e permitir arquivos gravados em runtime (como dankcolors.lua e lazy-lock.json):
  # 1. Não linkamos o diretório ~/.config/nvim inteiro.
  # 2. Linkamos individualmente os arquivos na raiz de lazyvim, em lua/config e em lua/plugins.
  xdg.configFile = {
    "nvim/init.lua".source = ./lazyvim/init.lua;
    "nvim/stylua.toml".source = ./lazyvim/stylua.toml;
    "nvim/.luarc.json".source = ./lazyvim/.luarc.json;
    "nvim/.neoconf.json".source = ./lazyvim/.neoconf.json;
  } // (builtins.listToAttrs (map (name: {
    name = "nvim/lua/config/${name}";
    value = { source = ./lazyvim/lua/config + "/${name}"; };
  }) (builtins.attrNames (builtins.readDir ./lazyvim/lua/config))))
    // (builtins.listToAttrs (map (name: {
    name = "nvim/lua/plugins/${name}";
    value = { source = ./lazyvim/lua/plugins + "/${name}"; };
  }) (builtins.attrNames (builtins.readDir ./lazyvim/lua/plugins))));
}
