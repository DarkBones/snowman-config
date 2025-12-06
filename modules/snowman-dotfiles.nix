
{ pkgs, currentHost, ... }:
let
  flakeDir = "/home/bas/snowman-config";
in
{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "snowman-dotfiles" ''
      set -euo pipefail

      DEV_NVIM="$HOME/Developer/dotfiles/nvim/.config/nvim"
      TARGET_NVIM="$HOME/.config/nvim"

      if [ "$#" -eq 0 ]; then
        if [ -L "$TARGET_NVIM" ]; then
          target="$(readlink -f "$TARGET_NVIM" 2>/dev/null || true)"

          if [ -n "$target" ] && [ "$target" = "$DEV_NVIM" ]; then
            echo "Current Snowman dotfiles mode: DEV"
            echo "  $TARGET_NVIM -> $target"
          else
            echo "Current Snowman dotfiles mode: PROD"
            echo "  $TARGET_NVIM -> ${target:-(unresolvable symlink)}"
          fi
        elif [ -e "$TARGET_NVIM" ]; then
          echo "Current Snowman dotfiles mode: UNKNOWN"
          echo "  $TARGET_NVIM exists but is not a symlink"
        else
          echo "Current Snowman dotfiles mode: UNKNOWN"
          echo "  $TARGET_NVIM does not exist"
        fi

        echo
        echo "Usage:"
        echo "  snowman-dotfiles dev   # enable dev mode (impure eval, link to repo)"
        echo "  snowman-dotfiles prod  # enable prod mode (pure eval, nix store)"
        exit 0
      fi

      MODE="$1"

      case "$MODE" in
        dev)
          echo "➜ Enabling dotfiles DEV mode (SNOWMAN_DOTFILES_MODE=dev)"
          export SNOWMAN_DOTFILES_MODE=dev
          ;;

        prod|production)
          echo "➜ Enabling dotfiles PROD mode (unsetting SNOWMAN_DOTFILES_MODE)"
          unset SNOWMAN_DOTFILES_MODE

          # Make sure ~/.config/nvim is clean before HM recreates it
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

      if [ "$MODE" = "dev" ]; then
        sudo -E nixos-rebuild switch --impure --flake "${flakeDir}#${currentHost}"

        if [ -d "$DEV_NVIM" ]; then
          echo "➜ Linking $TARGET_NVIM -> $DEV_NVIM (dev mode)"
          rm -rf "$TARGET_NVIM"
          ln -s "$DEV_NVIM" "$TARGET_NVIM"
        else
          echo "⚠ DEV nvim dir '$DEV_NVIM' does not exist, skipping link." >&2
        fi
      else
        sudo nixos-rebuild switch --flake "${flakeDir}#${currentHost}"
      fi
    '')
  ];
}

