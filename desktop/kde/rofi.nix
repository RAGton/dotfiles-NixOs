{
  pkgs,
  config,
  lib,
  ...
}:
{
  programs.rofi = {
    enable = true;
    theme = lib.mkForce "kryonix";
    extraConfig = {
      modi = "drun,run,window";
      show-icons = true;
      icon-theme = "WhiteSur-dark";
      drun-display-format = "{icon} {name}";
      disable-history = false;
      hide-scrollbar = true;
      display-drun = "   Apps ";
      display-run = "   Run ";
      display-window = " 﩯  Window ";
      sidebar-mode = true;
    };
  };

  xdg.configFile."rofi/kryonix.rasi".text = ''
    * {
        bg: #0b1017aa;
        bg-alt: #1a2233aa;
        fg: #c0caf5ff;
        fg-alt: #6b7280ff;
        accent: #38bdf8ff;
        accent-alt: #38bdf859;
        
        background-color: transparent;
        text-color: @fg;
        border-color: @accent-alt;
    }

    window {
        width: 600px;
        background-color: @bg;
        border: 2px;
        border-radius: 16px;
        padding: 20px;
    }

    prompt {
        text-color: @accent;
        padding: 0px 10px 0px 0px;
    }

    entry {
        placeholder: "Search...";
        placeholder-color: @fg-alt;
    }

    inputbar {
        children: [prompt, entry];
        padding: 10px;
        background-color: @bg-alt;
        border-radius: 8px;
        margin: 0px 0px 15px 0px;
    }

    listview {
        columns: 1;
        lines: 8;
        spacing: 5px;
    }

    element {
        padding: 10px;
        border-radius: 8px;
    }

    element selected {
        background-color: @accent-alt;
        text-color: #ffffff;
    }

    element-text {
        vertical-align: 0.5;
    }

    element-icon {
        size: 24px;
        margin: 0px 10px 0px 0px;
    }
  '';
}
