{
  config,
  lib,
  ...
}:

{
  # Desabilitar login root por segurança
  # Root ainda tem acesso via sudo (com password do admin)
  users.users.root = {
    hashedPassword = "!";
    # Impedir que root faça login direto — usar nologin shell
    shell = lib.mkForce "/sbin/nologin";
  };

  # Desabilitar SSH root login
  services.openssh = {
    permitRootLogin = lib.mkForce "no";
    passwordAuthentication = false;
  };

  # Sudo — permitir que admin use sudo SEM password (requer ser grupo wheel)
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  # Mensagem para quem tentar fazer login como root
  environment.etc."nologin".text = lib.mkForce ''
    ╔═════════════════════════════════════════╗
    ║  Root login está desabilitado por       ║
    ║  segurança. Use "sudo" como admin.      ║
    ║  Exemplo: sudo systemctl reboot         ║
    ╚═════════════════════════════════════════╝
  '';
}
