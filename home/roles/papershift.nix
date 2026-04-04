{ lib, config, pkgs, ... }:
let
  cfg = config.roles.papershift;

  papershiftPkgs = with pkgs; [
    # Pulse CI uses Ruby 3.4.x. Core is still on Ruby 2.7.8, which is not
    # available in the current nixpkgs set here, so keep the modern runtime
    # plus editor tooling that works across both repositories.
    ruby_3_4
    solargraph
    rubocop

    # Pulse CI pins Node 22 and pnpm 10 for the frontend and hub workspaces.
    # Do not add duplicate global `node`/`pnpm` binaries because the dev/lsp
    # roles already provide them and Home Manager will reject the collision.
    typescript

    # Editor tooling for TS/Vue/Astro code in Pulse.
    typescript-language-server
    vue-language-server
    astro-language-server

    # CLI quality tools used in CI.
    eslint
    prettier
    prettierd
  ];
in {
  imports = [ ./papershift-tooling.nix ];

  options.roles.papershift.enable = lib.mkEnableOption "Papershift role";

  config = lib.mkIf cfg.enable { home.packages = papershiftPkgs; };
}
