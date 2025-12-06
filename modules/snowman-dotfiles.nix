{ pkgs, currentHost, ... }:
let flakeDir = "/home/bas/snowman-config";
in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "snowman-dotfiles" ''
      set -euo pipefail

      MODE=prod
      if [ $# -ge 1 ]; then
        MODE="$1"
      fi

      DEV_NVIM="$HOME/Developer/dotfiles/nvim/.config/nvim"
      TARGET_NVIM="$HOME/.config/nvim"

      case "$MODE" in
        dev)
          echo "➜ Enabling dotfiles DEV mode (SNOWMAN_DOTFILES_MODE=dev)"
          export SNOWMAN_DOTFILES_MODE=dev
          ;;
        prod|production)
          echo "➜ Enabling dotfiles PROD mode (unsetting SNOWMAN_DOTFILES_MODE)"
          unset SNOWMAN_DOTFILES_MODE

          if [ -e "$TARGET_NVIM" ] || [ -L "$TARGET_NVIM" ]; then
            echo "➜ Removing existing $TARGET_NVIM before prod rebuild"
            rm -rf "$TARGET_NVIM"
          fi
          ;;
        *)
          echo "Usage: snowman-dotfiles [dev|prod]" >&2
          exit 1
          ;;
      esac

      cd ${flakeDir}

      echo "➜ Rebuilding NixOS for host ${currentHost} in $MODE mode..."
      sudo -E nixos-rebuild switch --impure --flake "${flakeDir}#${currentHost}"

      if [ "$MODE" = "dev" ]; then
        if [ -d "$DEV_NVIM" ]; then
          echo "➜ Linking $TARGET_NVIM -> $DEV_NVIM (dev mode)"
          rm -rf "$TARGET_NVIM"
          ln -s "$DEV_NVIM" "$TARGET_NVIM"
        else
          echo "⚠ DEV nvim dir '$DEV_NVIM' does not exist, skipping link." >&2
        fi
      fi
    '')
  ];
}
