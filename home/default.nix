{ config, lib, pkgs, ... }: {
  home.username = lib.mkDefault "bas";

  # Linux vs macOS default home dir
  home.homeDirectory = lib.mkDefault (if pkgs.stdenv.isDarwin then
    "/Users/${config.home.username}"
  else
    "/home/${config.home.username}");

  home.stateVersion = lib.mkDefault "25.05";

  imports = [ ./roles ./overrides ];

  roles.dotfiles.enable = lib.mkDefault true;

  programs.home-manager.enable = true;
}
