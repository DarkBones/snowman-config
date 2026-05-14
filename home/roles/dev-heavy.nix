{
  lib,
  pkgs,
  pkgsUnstable,
  config,
  ...
}:
let
  cfg = config.roles.dev-heavy;
in
{
  options.roles.dev-heavy.enable = lib.mkEnableOption "Dev-heavy role";

  config = lib.mkIf cfg.enable {
    home.packages =
      (with pkgsUnstable; [
        aichat
        codex
        gemini-cli
        starship
        claude-code
        opencode
      ])
      ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.bubblewrap ];
  };
}
