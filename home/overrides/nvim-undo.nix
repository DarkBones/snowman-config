{ lib, config, ... }:
let
  dotfilesEnabled = config.roles.dotfiles.enable or false;
in {
  config = lib.mkIf dotfilesEnabled {
    home.activation.ensureNvimUndoDir =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}"
        mkdir -p "$state_dir/nvim/undo"
      '';
  };
}
