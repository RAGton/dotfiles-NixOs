# =============================================================================
# Teste versionado: kryonix.services.aiServer
#
# O que e:
# - Avalia os 10 cenarios das assertions do modulo aiServer.
# - Cada cenario e avaliado com `lib.evalModules` puro (sem NixOS
#   toplevel). O eval produz a lista de assertions; contabilizamos
#   quantas falham e comparamos com o esperado.
# - Emite um relatorio markdown-like com uma linha por cenario. Se
#   qualquer cenario divergir, o check falha.
#
# Por que:
# - Substitui o harness ad-hoc em `/tmp` por um teste versionado que entra
#   automaticamente em `nix flake check` via `flake/checks.nix` (PR 1).
# - Nao exige rede, nao constroi closures, nao toca o sistema, nao usa
#   inputs externos alem do proprio motor.
#
# Como:
# - O check produz um arquivo com `checkPkgs.writeText` (mesmo padrao do
#   `nixos-iso-eval` ja existente em flake/checks.nix).
# - Os 10 cenarios correspondem EXATAMENTE ao que foi validado ad-hoc no
#   log do vault: `09-Logs/Kryonix/2026-07-28-ai-server-pr1-skeleton.md`.
#
# Limitacao conhecida vs. CI:
# - `lib.evalModules` nao executa o modulo contra o NixOS toplevel
#   (nao consegue resolver `nixpkgs`, `fileSystems`, `boot.*`, etc).
#   E deliberadamente isolado: testa APENAS as opcoes + assertions do
#   aiServer contra si proprio. O gate canonico (que carrega o modulo
#   via `services/default.nix` e exercita o motor inteiro) continua
#   sendo `nix flake check` no flake do motor.
#
# Adicionar novo cenario:
# - Incremente o `scenarios` abaixo.
#   Formato: { label, expected-fails, moduleExtra (attrset) }.
# =============================================================================
{
  self,
  lib,
  checkPkgs,
  nixpkgsLib,
}:

let
  # A `lib` recebida e a `flake/lib.nix` customizada do motor, que
  # **nao expoe** `evalModules` (esse helper vive no `nixpkgs.lib`
  # canonico). Para testar o modulo de forma isolada sem depender
  # de NixOS toplevel, recebemos o `nixpkgs.lib` canonico via parametro
  # e usamos para `evalModules`. Ver `flake/checks.nix` para a injecao.
  aiServerModule = {
    imports = [ ./default.nix ];
    options.assertions = nixpkgsLib.mkOption {
      type = nixpkgsLib.types.listOf (nixpkgsLib.types.submodule {
        options = {
          assertion = nixpkgsLib.mkOption { type = nixpkgsLib.types.bool; default = true; };
          message = nixpkgsLib.mkOption { type = nixpkgsLib.types.str; default = ""; };
        };
      });
      default = [ ];
    };
  };

  eval =
    moduleExtra:
    nixpkgsLib.evalModules {
      modules = [
        aiServerModule
        (
          { ... }:
          {
            config.kryonix.services.aiServer = moduleExtra;
          }
        )
      ];
    };

  failedCount = evaled:
    builtins.length (builtins.filter (a: !(a.assertion)) evaled.config.assertions);

  scenarios = [
    {
      label = "defaults-keep-module-inert";
      expected = 0;
      moduleExtra = { enable = false; };
    }
    {
      label = "valid-combo-operator-llama-cpp-with-modelPath";
      expected = 0;
      moduleExtra = {
        enable = true;
        inference = {
          enable = true;
          provider = "llama-cpp";
          modelPath = "/var/lib/kryonix/models/chat.gguf";
        };
        autonomy.level = "operator";
      };
    }
    {
      label = "public-ssh-with-acknowledge";
      expected = 0;
      moduleExtra = {
        enable = true;
        remoteAccess = {
          mode = "publicSsh";
          acknowledgePublicExposure = true;
        };
      };
    }
    {
      label = "public-ssh-without-acknowledge-FAILS";
      expected = 1;
      moduleExtra = {
        enable = true;
        remoteAccess = {
          mode = "publicSsh";
          acknowledgePublicExposure = false;
        };
      };
    }
    {
      label = "unrestricted-with-acknowledge";
      expected = 0;
      moduleExtra = {
        enable = true;
        autonomy = {
          level = "unrestricted";
          acknowledgeUnrestricted = true;
        };
      };
    }
    {
      label = "unrestricted-without-acknowledge-FAILS";
      expected = 1;
      moduleExtra = {
        enable = true;
        autonomy = {
          level = "unrestricted";
          acknowledgeUnrestricted = false;
        };
      };
    }
    {
      label = "llama-cpp-with-modelPath";
      expected = 0;
      moduleExtra = {
        enable = true;
        inference = {
          enable = true;
          provider = "llama-cpp";
          modelPath = "/srv/models/x.gguf";
        };
      };
    }
    {
      label = "llama-cpp-without-modelPath-FAILS";
      expected = 1;
      moduleExtra = {
        enable = true;
        inference = {
          enable = true;
          provider = "llama-cpp";
          modelPath = null;
        };
      };
    }
    {
      label = "ollama-no-path-required";
      expected = 0;
      moduleExtra = {
        enable = true;
        inference = {
          enable = true;
          provider = "ollama";
          modelPath = null;
        };
      };
    }
    {
      label = "external-no-path-required";
      expected = 0;
      moduleExtra = {
        enable = true;
        inference = {
          enable = true;
          provider = "external";
          modelPath = null;
        };
      };
    }
  ];

  lineFor = scenario:
    let
      r = builtins.tryEval (eval scenario.moduleExtra);
      fails = if r.success then (failedCount r.value) else -1;
      passed = r.success && (fails == scenario.expected);
      status = if passed then "PASS" else "FAIL";
    in "${status} fails=${toString fails} expected=${toString scenario.expected}  ${scenario.label}";

  report = builtins.concatStringsSep "\n" (map lineFor scenarios);

  allPass = builtins.all
    (s:
      let
        r = builtins.tryEval (eval s.moduleExtra);
        ok = r.success && (failedCount r.value == s.expected);
      in ok)
    scenarios;

  summary = if allPass then
    "ALL PASS: 10/10 scenarios"
  else
    "FAIL: at least one scenario diverged from expected";

  # Força a avaliacao agora (em vez de lazy dentro do writeText).
  # Garante que o report seja materializado e qualquer erro de eval
  # apareça como falha do check, nao como arquivo incompleto.
  evaluated = {
    inherit summary report allPass;
  };
in
# Se algum cenario divergir, o check falha em vez de criar o arquivo.
# O mecanismo: `assert evaluated.allPass;` torna o derivation impossivel
# de construir quando ha regressao, e `nix flake check` reporta o erro.
assert evaluated.allPass;
checkPkgs.writeText "ai-server-options-report" ''
  Kryonix AI Server — PR 1 — assertion regression test
  Generated by modules/nixos/services/ai-server/tests.nix

  ${evaluated.summary}

${evaluated.report}
''
