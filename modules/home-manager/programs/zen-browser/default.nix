{
  pkgs,
  ...
}:
{
  /*
   Autor: RAGton
   Descrição: Configuração do Zen Browser como navegador principal via Flatpak.
  */

  # O Zen Browser é instalado via Flatpak (veja services/flatpak)
  # Aqui apenas garantimos que ele será o navegador padrão

  xdg.mimeApps.defaultApplications = {
    "text/html" = "app.zen_browser.zen.desktop";
    "x-scheme-handler/http" = "app.zen_browser.zen.desktop";
    "x-scheme-handler/https" = "app.zen_browser.zen.desktop";
    "x-scheme-handler/ftp" = "app.zen_browser.zen.desktop";
    "application/xhtml+xml" = "app.zen_browser.zen.desktop";
    "application/x-extension-htm" = "app.zen_browser.zen.desktop";
    "application/x-extension-html" = "app.zen_browser.zen.desktop";
    "application/x-extension-shtml" = "app.zen_browser.zen.desktop";
    "application/x-extension-xhtml" = "app.zen_browser.zen.desktop";
    "application/x-extension-xht" = "app.zen_browser.zen.desktop";
  };

  # Documentação:
  # - O Zen Browser será instalado via Flatpak pelo módulo services/flatpak
  # - Este módulo apenas define o Zen como navegador padrão para os principais tipos de arquivos e protocolos web
}
