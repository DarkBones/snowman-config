{ config, lib, pkgs, ... }: {
  home.username = lib.mkDefault "bas";
  home.homeDirectory = lib.mkDefault "/home/bas";
  home.stateVersion = lib.mkDefault "25.05";

  imports = [ ./roles ./overrides ];

  roles.desktop.enable = lib.mkDefault true;
  roles.hyprland.enable = lib.mkDefault true;
  roles.dotfiles.enable = lib.mkDefault true;

  programs.home-manager.enable = true;
}
