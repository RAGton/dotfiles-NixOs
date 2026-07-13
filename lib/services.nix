{ lib, ... }:

{
  # Helper para garantir que os serviços escrevam apenas no seu namespace
  mkKryonixService = { name, files ? {}, legacyLinks ? {} }: {
    environment.etc = lib.mapAttrs' (filename: content: {
      name = "kryonix/services/${name}/${filename}";
      value = { source = content; };
    }) files;

    # Gestão de compatibilidade: cria links para caminhos legados, se necessário
    system.activationScripts = lib.mapAttrs' (legacyPath: targetPath: {
      name = "link-legacy-${name}-${builtins.replaceStrings ["/"] ["-"] legacyPath}";
      value = ''
        mkdir -p $(dirname ${legacyPath})
        ln -sf /etc/kryonix/services/${name}/${targetPath} ${legacyPath}
      '';
    }) legacyLinks;
  };
}
