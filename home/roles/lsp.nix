{ lib, pkgs, config, ... }:
let cfg = config.roles.lsp;
in {
  options.roles.lsp.enable = lib.mkEnableOption "Lsp role";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      beautysh

      lua-language-server
      stylua
      nil
      nixfmt-rfc-style

      go
      gopls
      gotools

      pyright
      black
      isort

      nodejs
      prettierd
      shellcheck
      shfmt
    ];
  };
}
