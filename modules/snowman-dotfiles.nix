{ pkgs, currentHost, ... }:
let
  mode =
    if builtins.getEnv "SNOWMAN_DOTFILES_MODE" == "dev" then "dev" else "prod";
in {
  environment.etc."snowman/dotfiles-mode".text = mode + "\n";

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "snowman-dotfiles" ''
      set -euo pipefail

      MODE_FILE="/etc/snowman/dotfiles-mode"
      ANCHOR="$HOME/.snowman-dotfiles-root"

      show_help() {
          echo "Usage: snowman-dotfiles [dev|prod|status]"
          echo ""
          echo "  dev     - Enable dev mode (mutable symlinks managed by HM)"
          echo "  prod    - Enable prod mode (immutable store links managed by HM)"
          echo "  status  - Show declared + effective mode (via anchor link)"
          exit 0
      }

      effective_mode() {
          if [ ! -L "$ANCHOR" ]; then
              echo "UNKNOWN ($ANCHOR missing)"
              return 0
          fi

          local target
          target="$(readlink -f "$ANCHOR" 2>/dev/null || true)"

          case "$target" in
              "$HOME"/*)
                  echo "DEV ($ANCHOR → $target)"
                  ;;
              /nix/store/*)
                  echo "PROD ($ANCHOR → $target)"
                  ;;
              "")
                  echo "UNKNOWN ($ANCHOR broken)"
                  ;;
              *)
                  echo "UNKNOWN ($ANCHOR → $target)"
                  ;;
          esac
      }

      status() {
          local declared="UNKNOWN"
          local effective=""
          local target=""

          # Read declared state (fallback)
          if [ -r "$MODE_FILE" ]; then
              declared="$(cat "$MODE_FILE" 2>/dev/null || true)"
          fi

          # Try effective state via anchor
          if [ -L "$ANCHOR" ]; then
              target="$(readlink -f "$ANCHOR" 2>/dev/null || true)"
              case "$target" in
                  "$HOME"/*)
                      echo "dotfiles: DEV ($ANCHOR → $target)"
                      return 0
                      ;;
                  /nix/store/*)
                      echo "dotfiles: PROD ($ANCHOR → $target)"
                      return 0
                      ;;
                  "")
                      echo "dotfiles: UNKNOWN ($ANCHOR broken)"
                      return 0
                      ;;
                  *)
                      echo "dotfiles: UNKNOWN ($ANCHOR → $target)"
                      return 0
                      ;;
              esac
          fi

          # No anchor → fall back to declared state
          case "$declared" in
              dev)
                  echo "dotfiles: DEV (declared; anchor missing)"
                  ;;
              prod)
                  echo "dotfiles: PROD (declared; anchor missing)"
                  ;;
              *)
                  echo "dotfiles: UNKNOWN (no anchor, no declared state)"
                  ;;
          esac
      }

      if [ "$#" -eq 0 ]; then show_help; fi

      MODE="$1"

      case "$MODE" in
          status)
              status
              exit 0
              ;;
          dev)
              echo "➜ Enabling dotfiles DEV mode (SNOWMAN_DOTFILES_MODE=dev)"
              export SNOWMAN_DOTFILES_MODE=dev
              echo "➜ Rebuilding NixOS for host ${currentHost}..."
              sudo -H -E nixos-rebuild switch --impure --flake ".#${currentHost}"
              ;;
          prod | production)
              echo "➜ Enabling dotfiles PROD mode (unsetting SNOWMAN_DOTFILES_MODE)"
              unset SNOWMAN_DOTFILES_MODE
              echo "➜ Rebuilding NixOS for host ${currentHost}..."
              sudo -H nixos-rebuild switch --flake ".#${currentHost}"
              ;;
          *)
              show_help
              ;;
      esac
    '')
  ];
}
