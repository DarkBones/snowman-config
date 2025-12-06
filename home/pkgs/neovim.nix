{ pkgs, pkgsUnstable }:
pkgs.symlinkJoin {
  name = "neovim";
  paths = [ pkgsUnstable.neovim ];
  buildInputs = [ pkgs.makeWrapper ];

  postBuild = ''
    wrapProgram "$out/bin/nvim" \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [ pkgs.python3 pkgs.nodejs_22 pkgs.unzip ]
      }
  '';
}
