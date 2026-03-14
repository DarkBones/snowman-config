{
  lib,
  pkgsUnstable,
  config,
  ...
}:
let
  cfg = config.roles.macos-wm;

  yabaiRc = "${config.home.homeDirectory}/.config/yabai/yabairc";
  skhdRc = "${config.home.homeDirectory}/.config/skhd/skhdrc";
in
{
  options.roles.macos-wm.enable = lib.mkEnableOption "macOS WM stack (yabai/skhd/karabiner)";

  config = lib.mkIf (cfg.enable && pkgsUnstable.stdenv.isDarwin) {
    home.packages = with pkgsUnstable; [
      yabai
      skhd
      karabiner-elements
      sketchybar
      nerd-fonts.jetbrains-mono
    ];

    home.activation.installNerdFonts =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        fonts_dir="$HOME/Library/Fonts"
        fonts_src="${pkgsUnstable.nerd-fonts.jetbrains-mono}/share/fonts"

        mkdir -p "$fonts_dir"
        if [ -d "$fonts_src" ]; then
        find "$fonts_src" -type f -name '*.ttf' -print0 | while IFS= read -r -d $'\\0' font; do
            target="$fonts_dir/$(basename "$font")"
            if [ ! -e "$target" ]; then
              cp "$font" "$target"
            fi
          done
        fi
      '';

    # Launch agents
    launchd.agents.yabai = {
      enable = true;
      config = {
        Label = "org.nix.yabai";
        ProgramArguments = [
          "${pkgsUnstable.yabai}/bin/yabai"
          "--config"
          yabaiRc
        ];
        RunAtLoad = true;
        KeepAlive = true;
        EnvironmentVariables = {
          PATH = "/Users/${config.home.username}/.nix-profile/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/yabai.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/yabai.err.log";
      };
    };

    launchd.agents.skhd = {
      enable = true;
      config = {
        Label = "org.nix.skhd";
        ProgramArguments = [
          "${pkgsUnstable.skhd}/bin/skhd"
          "-c"
          skhdRc
        ];
        RunAtLoad = true;
        KeepAlive = true;

        EnvironmentVariables = {
          PATH = "/Users/${config.home.username}/.nix-profile/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };

        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/skhd.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/skhd.err.log";
      };
    };
  };
}
