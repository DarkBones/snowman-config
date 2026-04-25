{
  lib,
  pkgs,
  pkgsUnstable,
  config,
  hostRoles ? [ ],
  ...
}:
let
  hasVideoEditingHost = hostRoles == null || lib.elem "video-editing" hostRoles;
  cfg = config.roles."video-editing";
  localZipPath = cfg.davinciResolve.localZipPath;
  hasDavinciSource = builtins.pathExists localZipPath;
  davinciResolve =
    if hasDavinciSource then
      pkgsUnstable.callPackage ../../pkgs/davinci-resolve-local.nix {
        inherit (cfg.davinciResolve) version;
        inherit localZipPath;
      }
    else
      null;

  resolveTranscode = pkgs.writeShellApplication {
    name = "resolve-transcode";
    runtimeInputs = with pkgs; [
      coreutils
      ffmpeg
      findutils
    ];
    text = ''
      set -euo pipefail

      usage() {
        cat <<'EOF'
      usage: resolve-transcode [options] [directory]

      Convert common video files into Resolve-friendly ProRes MOV files.
      By default, scans the current directory recursively and writes sibling
      files with a "_resolve.mov" suffix.

      options:
        -n, --dry-run         print planned work without converting
        --no-recursive        only scan the top-level directory
        -d, --directory DIR   directory to scan (default: .)
        -s, --suffix SUFFIX   output suffix before .mov (default: _resolve)
        -o, --overwrite       replace existing output files
        --replace-source      replace the source file after successful transcode
        -h, --help            show this help
      EOF
      }

      recursive=1
      dry_run=0
      overwrite=0
      replace_source=0
      suffix="_resolve"
      scan_dir="."

      while [ $# -gt 0 ]; do
        case "$1" in
          -n|--dry-run)
            dry_run=1
            ;;
          --no-recursive)
            recursive=0
            ;;
          -d|--directory)
            [ $# -ge 2 ] || { echo "resolve-transcode: missing value for $1" >&2; exit 2; }
            scan_dir="$2"
            shift
            ;;
          -s|--suffix)
            [ $# -ge 2 ] || { echo "resolve-transcode: missing value for $1" >&2; exit 2; }
            suffix="$2"
            shift
            ;;
          -o|--overwrite)
            overwrite=1
            ;;
          --replace-source)
            replace_source=1
            overwrite=1
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          -*)
            echo "resolve-transcode: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
          *)
            scan_dir="$1"
            ;;
        esac
        shift
      done

      if [ ! -d "$scan_dir" ]; then
        echo "resolve-transcode: directory not found: $scan_dir" >&2
        exit 1
      fi

      if [ -z "$suffix" ]; then
        echo "resolve-transcode: suffix cannot be empty" >&2
        exit 2
      fi

      if [ "$replace_source" -eq 1 ] && [ "$suffix" = "" ]; then
        echo "resolve-transcode: suffix cannot be empty when replacing source" >&2
        exit 2
      fi

      find_args=("$scan_dir")
      if [ "$recursive" -eq 0 ]; then
        find_args+=(-maxdepth 1)
      fi
      find_args+=(
        -type f
        "("
          -iname "*.mov" -o
          -iname "*.mp4" -o
          -iname "*.m4v" -o
          -iname "*.mkv" -o
          -iname "*.avi"
        ")"
        !
        -iname "*''${suffix}.mov"
        !
        -iname "*.part.mov"
        -print0
      )

      count=0
      converted=0
      skipped=0
      failed=0
      replaced=0

      while IFS= read -r -d "" input_path; do
        count=$((count + 1))
        input_dir="$(dirname "$input_path")"
        input_name="$(basename "$input_path")"
        stem="''${input_name%.*}"
        output_path="$input_dir/''${stem}''${suffix}.mov"
        final_output_path="$output_path"

        if [ -e "$output_path" ] && [ "$overwrite" -ne 1 ]; then
          printf 'skip: %s -> %s (exists)\n' "$input_path" "$output_path"
          skipped=$((skipped + 1))
          continue
        fi

        printf 'convert: %s -> %s\n' "$input_path" "$output_path"
        converted=$((converted + 1))

        if [ "$dry_run" -eq 1 ]; then
          continue
        fi

        temp_output_path="$(mktemp "/tmp/resolve-transcode-XXXXXX.mov")"
        if ! ffmpeg -hide_banner -loglevel warning -stats \
          -nostdin \
          -y \
          -i "$input_path" \
          -map 0:v:0 -map 0:a? \
          -c:v prores_ks -profile:v 3 -pix_fmt yuv422p10le \
          -c:a pcm_s16le \
          "$temp_output_path"; then
          printf 'fail: %s\n' "$input_path" >&2
          rm -f "$temp_output_path"
          failed=$((failed + 1))
          continue
        fi

        if [ "$replace_source" -eq 1 ]; then
          rm -f "$input_path"
          final_output_path="$input_dir/$input_name"
          mv -f "$temp_output_path" "$final_output_path"
          replaced=$((replaced + 1))
        else
          mv -f "$temp_output_path" "$output_path"
        fi
      done < <(find "''${find_args[@]}")

      if [ "$count" -eq 0 ]; then
        echo "resolve-transcode: no matching media files found in $scan_dir" >&2
        exit 1
      fi

      printf 'done: scanned=%d converted=%d skipped=%d failed=%d replaced=%d\n' "$count" "$converted" "$skipped" "$failed" "$replaced"
    '';
  };
in
{
  options.roles."video-editing" = {
    enable = lib.mkEnableOption "Video editing role";

    davinciResolve = {
      version = lib.mkOption {
        type = lib.types.str;
        default = "20.3.2";
        description = "DaVinci Resolve version encoded into the Linux installer filename.";
      };

      localZipPath = lib.mkOption {
        type = lib.types.str;
        default = "/home/bas/.local/share/installers/DaVinci_Resolve_20.3.2_Linux.zip";
        example = "/home/bas/.local/share/installers/DaVinci_Resolve_20.3.2_Linux.zip";
        description = "Absolute path to the official DaVinci Resolve Linux zip on the local machine.";
      };
    };
  };

  config = lib.mkIf (hasVideoEditingHost && cfg.enable) {
    warnings = lib.optional (!hasDavinciSource) ''
      bas profile: video-editing role enabled, but DaVinci Resolve installer zip was not found at:
        ${localZipPath}

      To enable DaVinci Resolve on this machine, download:
        DaVinci_Resolve_${cfg.davinciResolve.version}_Linux.zip

      And place it at:
        ${localZipPath}

      The rest of the role remains enabled; DaVinci Resolve is being skipped for this rebuild.
    '';

    home.packages = [
      pkgs.ffmpeg
      resolveTranscode
    ]
    ++ lib.optional hasDavinciSource davinciResolve;
  };
}
