{ pkgs, pkgsUnstable }:
let codeiumTools = with pkgs; [ curl gzip util-linux coreutils ];
in pkgs.symlinkJoin {
  name = "neovim";
  paths = [ pkgsUnstable.neovim ];
  buildInputs = [ pkgs.makeWrapper ];

  postBuild = ''
    wrapProgram "$out/bin/nvim" \
      --prefix PATH : ${
        pkgs.lib.makeBinPath
        (codeiumTools ++ [ pkgs.python3 pkgs.nodejs_22 pkgs.unzip ])
      }
  '';
}
