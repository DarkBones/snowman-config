{
  config,
  lib,
  pkgs,
  dotfilesSources,
  name,
  ...
}:
{
  home.username = lib.mkDefault "bas";

  # Linux vs macOS default home dir
  home.homeDirectory = lib.mkDefault (
    if pkgs.stdenv.isDarwin then "/Users/${config.home.username}" else "/home/${config.home.username}"
  );

  home.stateVersion = lib.mkDefault "25.05";

  imports = [
    ./roles
    ./overrides
  ];

  roles.dotfiles.enable = lib.mkDefault true;

  programs.home-manager.enable = true;

  # On standalone Home Manager (especially macOS), session variables like $ROLES
  # are often not sourced automatically if HM doesn't manage the shell.
  # We use .zshenv as a "clean" injection point that shouldn't conflict with dotfiles.
  home.file.".zshenv" = {
    text = lib.mkIf pkgs.stdenv.isDarwin ''
      # Source Home Manager session variables
      if [ -e "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi
    '';
    force = true;
  };

  # macOS login shells often skip .zshrc if they are login shells but not interactive.
  # We ensure .zshrc is sourced to get aliases and themes.
  home.file.".zprofile" = {
    text = lib.mkIf pkgs.stdenv.isDarwin ''
      # Source .zshrc if it exists
      if [ -f "$HOME/.zshrc" ]; then
        . "$HOME/.zshrc"
      fi
    '';
    force = true;
  };
}
