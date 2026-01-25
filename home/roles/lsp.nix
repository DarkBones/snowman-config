{ lib, pkgs, pkgsUnstable, config, ... }:
let cfg = config.roles.lsp;
in {
  options.roles.lsp.enable = lib.mkEnableOption "Lsp role";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs;
      [
        beautysh
        lua-language-server
        stylua
        nil
        alejandra
        nixfmt-rfc-style
        go
        gopls
        gotools
        pyright
        black
        isort
        shellcheck
        shfmt
        vscode-langservers-extracted
        prettierd
      ] ++ [ pkgsUnstable.nodejs_24 ];
  };
}
