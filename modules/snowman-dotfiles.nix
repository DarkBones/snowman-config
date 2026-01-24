{ pkgs, currentHost, ... }:
let
  defaultFlakePath = "/home/bas/snowman-config";

  snowmanDotfiles = pkgs.writeShellScriptBin "snowman-dotfiles" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    MODE_FILE="/etc/snowman/dotfiles-mode"
    ANCHOR="$HOME/.snowman-dotfiles-root"
    DEFAULT_FLAKE_FILE="/etc/snowman/flake"

    die() { echo "error: $*" >&2; exit 1; }

    DEFAULT_FLAKE="$(cat "$DEFAULT_FLAKE_FILE" 2>/dev/null || true)"

    FLAKE_REF="''${SNOWMAN_FLAKE:-''${DEFAULT_FLAKE:-${defaultFlakePath}}}"

    # If HM gave a literal "$HOME/..." string, expand it manually.
    if [[ "$FLAKE_REF" == "\$HOME/"* ]]; then
      FLAKE_REF="$HOME/''${FLAKE_REF#\$HOME/}"
    fi

    # Expand "~/" too
    if [[ "$FLAKE_REF" == "~/"* ]]; then
      FLAKE_REF="$HOME/''${FLAKE_REF#~/}"
    fi

    # Canonicalize local absolute paths
    if [[ "$FLAKE_REF" == /* ]]; then
      FLAKE_REF="$(readlink -f "$FLAKE_REF")"
      [[ -e "$FLAKE_REF" ]] || die "flake path not found: $FLAKE_REF"
    fi

    status() {
      if [ -L "$ANCHOR" ]; then
        local target
        target="$(readlink -f "$ANCHOR" 2>/dev/null || true)"
        case "$target" in
          "$HOME"/*)    echo "dotfiles: DEV ($ANCHOR → $target)"; return 0 ;;
          /nix/store/*) echo "dotfiles: PROD ($ANCHOR → $target)"; return 0 ;;
          "")           echo "dotfiles: UNKNOWN ($ANCHOR broken)"; return 0 ;;
          *)            echo "dotfiles: UNKNOWN ($ANCHOR → $target)"; return 0 ;;
        esac
      fi

      local declared="UNKNOWN"
      [ -r "$MODE_FILE" ] && declared="$(cat "$MODE_FILE" 2>/dev/null || true)"
      case "$declared" in
        dev)  echo "dotfiles: DEV (declared; anchor missing)" ;;
        prod) echo "dotfiles: PROD (declared; anchor missing)" ;;
        *)    echo "dotfiles: UNKNOWN (no anchor, no declared state)" ;;
      esac
    }

    rebuild_dev() {
      echo "➜ Enabling dotfiles DEV mode (SNOWMAN_DOTFILES_MODE=dev)"
      export SNOWMAN_DOTFILES_MODE=dev
      echo "➜ Rebuilding NixOS for host ${currentHost} using flake: $FLAKE_REF"
      sudo -H -E nixos-rebuild switch --impure --flake "$FLAKE_REF#${currentHost}"
    }

    rebuild_prod() {
      echo "➜ Enabling dotfiles PROD mode (unsetting SNOWMAN_DOTFILES_MODE)"
      unset SNOWMAN_DOTFILES_MODE
      echo "➜ Rebuilding NixOS for host ${currentHost} using flake: $FLAKE_REF"
      sudo -H nixos-rebuild switch --flake "$FLAKE_REF#${currentHost}"
    }

    case "''${1:-}" in
      status) status ;;
      dev) rebuild_dev ;;
      prod|production) rebuild_prod ;;
      ""|-h|--help)
        echo "Usage: snowman-dotfiles [dev|prod|status]"
        echo "Env override: SNOWMAN_FLAKE=/path/or/ref"
        echo "Default file: $DEFAULT_FLAKE_FILE"
        ;;
      *) die "unknown command: $1" ;;
    esac
  '';
in {
  environment.etc."snowman/flake".text = defaultFlakePath + "\n";
  environment.systemPackages = [ snowmanDotfiles ];
}
