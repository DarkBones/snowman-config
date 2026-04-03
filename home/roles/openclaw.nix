{ lib, pkgs, config, inputs, ... }:
let
  cfg = config.roles.openclaw;
  isLinux = pkgs.stdenv.isLinux;
  documentsDir = "${cfg.documentsRepoDir}/documents";
  requiredDocumentFiles = [
    "AGENTS.md"
    "SOUL.md"
    "TOOLS.md"
  ];
  optionalDocumentFiles = [
    "IDENTITY.md"
    "USER.md"
    "LORE.md"
    "HEARTBEAT.md"
    "PROMPTING-EXAMPLES.md"
  ];
  documentFiles = requiredDocumentFiles ++ optionalDocumentFiles;
  workspaceDir = "${config.home.homeDirectory}/.openclaw/workspace";
  whatsappAuthDir = "${config.home.homeDirectory}/.openclaw/whatsapp/main";
  bundledPluginsSourceDir = "${config.programs.openclaw.package}/lib/openclaw/extensions";
  bundledPluginsDistDir = "${config.programs.openclaw.package}/lib/openclaw/dist/extensions";
  bundledPluginsRuntimeDir =
    "${config.home.homeDirectory}/.openclaw/bundled-plugins-runtime";
  bundledPluginsRuntimeDistDir = "${bundledPluginsRuntimeDir}/dist";
  bundledPluginsRuntimeExtensionsDir = "${bundledPluginsRuntimeDistDir}/extensions";
  openclawScreenshotDir = "${config.home.homeDirectory}/.openclaw/media/screenshots";
  openclawServicePath = lib.makeBinPath [
    linuxScreenshot
    searxngSearch
    telegramSend
    pkgs.coreutils
    pkgs.curl
    pkgs.findutils
    pkgs.gnugrep
    pkgs.jq
    pkgs.gnused
    pkgs.grim
    pkgs.slurp
    pkgs.systemd
  ];

  searxngSearch = pkgs.writeShellApplication {
    name = "searxng-search";
    runtimeInputs = with pkgs; [ curl jq ];
    text = ''
      set -euo pipefail

      if [ $# -eq 0 ]; then
        echo "usage: searxng-search <query>" >&2
        exit 2
      fi

      : "''${SEARXNG_BASE_URL:?SEARXNG_BASE_URL is required}"

      query="$*"
      base_url="''${SEARXNG_BASE_URL%/}"
      format="''${SEARXNG_FORMAT:-json}"
      categories="''${SEARXNG_CATEGORIES:-general}"
      limit="''${SEARXNG_LIMIT:-5}"
      language="''${SEARXNG_LANGUAGE:-en-US}"

      response="$(
        curl --silent --show-error --fail \
          --get "$base_url/search" \
          --data-urlencode "q=$query" \
          --data-urlencode "format=$format" \
          --data-urlencode "categories=$categories" \
          --data-urlencode "language=$language"
      )"

      printf '%s' "$response" | jq --arg query "$query" --argjson limit "$limit" '
        .results[:$limit]
        | if length == 0 then
            "No SearxNG results for: \($query)"
          else
            map(
              "- "
              + (.title // "(untitled)")
              + "\n  URL: "
              + (.url // "")
              + (
                  if (.content // "") == "" then
                    ""
                  else
                    "\n  Snippet: " + (.content | gsub("[\r\n\t]+"; " "))
                  end
                )
            )
            | join("\n")
          end
      '
    '';
  };

  telegramSend = pkgs.writeShellApplication {
    name = "telegram-send";
    runtimeInputs = with pkgs; [ coreutils curl jq ];
    text = ''
      set -euo pipefail

      if [ $# -lt 2 ]; then
        echo "usage: telegram-send <chat-id> <text...>" >&2
        exit 2
      fi

      : "''${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN is required}"

      chat_id="$1"
      shift
      text="$*"

      response="$(
        curl --silent --show-error --fail \
          --request POST \
          --url "https://api.telegram.org/bot''${TELEGRAM_BOT_TOKEN}/sendMessage" \
          --header 'content-type: application/json' \
          --data "$(
            jq -cn \
              --arg chat_id "$chat_id" \
              --arg text "$text" \
              '{ chat_id: $chat_id, text: $text }'
          )"
      )"

      printf '%s\n' "$response" | jq .
    '';
  };

  linuxScreenshot = pkgs.writeShellApplication {
    name = "linux-screenshot";
    runtimeInputs = with pkgs; [ coreutils findutils gnugrep gnused grim slurp systemd ];
    text = ''
      set -euo pipefail

      mode="full"
      case "''${1:-}" in
        "")
          ;;
        --full)
          ;;
        --region)
          mode="region"
          ;;
        *)
          echo "usage: linux-screenshot [--full|--region]" >&2
          exit 2
          ;;
      esac

      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

      read_systemd_env() {
        local key="$1"
        systemctl --user show-environment | sed -n "s/^''${key}=//p" | head -n1
      }

      export XDG_RUNTIME_DIR="$runtime_dir"

      if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
        WAYLAND_DISPLAY="$(read_systemd_env WAYLAND_DISPLAY || true)"
      fi
      if [ -z "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        HYPRLAND_INSTANCE_SIGNATURE="$(read_systemd_env HYPRLAND_INSTANCE_SIGNATURE || true)"
      fi

      if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
        socket_path="$(find "$runtime_dir" -maxdepth 1 -type s -name 'wayland-*' | sort | head -n1)"
        if [ -n "$socket_path" ]; then
          WAYLAND_DISPLAY="$(basename "$socket_path")"
        fi
      fi

      if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
        echo "linux-screenshot: no Wayland display found. OpenClaw needs an active graphical session on this machine." >&2
        exit 1
      fi

      export WAYLAND_DISPLAY
      if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        export HYPRLAND_INSTANCE_SIGNATURE
      fi

      out_dir="''${OPENCLAW_SCREENSHOT_DIR:-${openclawScreenshotDir}}"
      mkdir -p "$out_dir"

      timestamp="$(date +%Y%m%d-%H%M%S)"
      target="$out_dir/$timestamp.png"

      if [ "$mode" = "region" ]; then
        geometry="$(slurp)"
        if [ -z "$geometry" ]; then
          echo "linux-screenshot: no region selected." >&2
          exit 1
        fi
        grim -g "$geometry" "$target"
      else
        grim "$target"
      fi

      printf 'Saved screenshot to %s\n' "$target"
      printf 'MEDIA:%s\n' "$target"
    '';
  };
in {
  imports = [ inputs.nix-openclaw.homeManagerModules.openclaw ];

  options.roles.openclaw = {
    enable = lib.mkEnableOption "OpenClaw role";

    documentsRepoDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Developer/openclaw";
      description = ''
        Private checkout that contains the OpenClaw documents directory.
        The workspace files are symlinked from this checkout's documents directory.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && isLinux) {
    home.packages = [ linuxScreenshot searxngSearch ];
    home.file.".openclaw/openclaw.json".force = true;

    programs.openclaw = {
      enable = true;
      package = pkgs.openclaw-gateway;
      documents = null;

      skills = [
        {
          name = "searxng-search";
          description = "Search the web through the local SearxNG instance.";
          mode = "inline";
          body = ''
            Use the `searxng-search` CLI when the user asks to search the web, look something up, find sources, or gather web results.

            Pass the plain-language query directly.

            Prefer this skill over provider-backed web search when the local SearxNG instance should be the source of results.

            When a fetch or search result shows an upstream error page or block page, report it literally.

            If the source says `403 Forbidden`, say `403 Forbidden`.
            If the source says `blocked by network security`, say that.

            Do not invent causes like captchas, bans, rate limits, login walls, anti-bot checks, or API requirements unless the fetched content explicitly says that.

            Distinguish clearly between:
            - direct facts from the fetched content
            - your inferences

            If the fetch failed or was blocked, quote the short relevant line from the response and then explain the practical consequence.
          '';
        }
        {
          name = "telegram-send";
          description = "Send a plain Telegram message through the Telegram Bot API.";
          mode = "inline";
          body = ''
            Use this skill when sending a normal Telegram message.

            Use the `telegram-send` CLI instead of the generic `message` tool.

            Run:
            `telegram-send <telegram-target> <message text>`

            Pass only the Telegram target and the plain text to send.
            Do not use poll-related arguments for a normal check-in.
            Do not use the generic `message` tool for Telegram plain-text sends unless the user explicitly asks for a poll.
          '';
        }
        {
          name = "linux-screenshot";
          description = "Capture a screenshot from the current Wayland desktop on dorkbones.";
          mode = "inline";
          body = ''
            Use the `linux-screenshot` CLI when the user asks what is on the screen, asks you to inspect the desktop UI, or explicitly requests a screenshot from this machine.

            Default to a full-screen capture:
            `linux-screenshot`

            Only use region mode when the user explicitly wants a cropped selection and can interact with the desktop:
            `linux-screenshot --region`

            The command prints `MEDIA:/home/bas/.openclaw/media/screenshots/...png`.

            After capturing, analyze the screenshot with the `image` tool.

            Call the `image` tool with:
            - `image`: the exact saved screenshot path
            - `prompt`: a plain instruction like `Describe exactly what is visible in this screenshot.`

            Do not put the filesystem path inside the `prompt`.
            Do not set the `model` field on the `image` tool call.

            If capture fails because there is no active graphical session, explain that clearly.
          '';
        }
      ];

      config = {
        models.mode = "replace";

        agents.defaults.model = {
          primary = "router/openai/gpt-5.1-codex-mini";
          fallbacks = [ ];
        };

        agents.defaults.imageModel = {
          primary = "openai/gpt-5-mini";
          fallbacks = [ "anthropic/claude-opus-4-5" ];
        };

        models.providers.router = {
          api = "openai-completions";
          baseUrl = "https://openrouter.ai/api/v1";
          auth = "api-key";
          apiKey = {
            source = "env";
            provider = "default";
            id = "OPENROUTER_API_KEY";
          };
          models = [
            {
              id = "auto";
              name = "OpenRouter Auto";
              input = [ "text" "image" ];
            }
            {
              id = "anthropic/claude-sonnet-4";
              name = "Claude Sonnet 4";
              input = [ "text" "image" ];
              reasoning = true;
            }
            {
              id = "openai/gpt-5";
              name = "GPT-5";
              input = [ "text" "image" ];
              reasoning = true;
            }
            {
              id = "openai/gpt-5.1-codex-mini";
              name = "GPT-5.1 Codex Mini";
              input = [ "text" "image" ];
              reasoning = true;
            }
          ];
        };

        gateway = {
          mode = "local";
          auth.mode = "token";
          controlUi = {
            allowedOrigins = [ "http://openclaw" ];
            allowInsecureAuth = true;
            dangerouslyDisableDeviceAuth = true;
          };
        };

        channels.whatsapp = {
          enabled = true;
          defaultAccount = "main";

          accounts.main = {
            enabled = true;
            name = "main";
            authDir = whatsappAuthDir;
            allowFrom = [ "*" ];
            dmPolicy = "open";
            groupPolicy = "disabled";
            sendReadReceipts = false;
          };
        };

        channels.telegram = {
          enabled = true;
          tokenFile = "/run/secrets/openclaw_telegram_bot_token";
          allowFrom = [ "*" ];
          dmPolicy = "open";
          groupPolicy = "disabled";
        };
      };
    };

    home.activation.openclawEnvFile =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        env_dir="$HOME/.config/openclaw"
        env_file="$env_dir/openclaw.env"

        mkdir -p "$env_dir"
        : > "$env_file"
        chmod 600 "$env_file"

        if [ -r /run/secrets/openclaw_gateway_token ]; then
          printf 'OPENCLAW_GATEWAY_TOKEN=%s\n' "$(tr -d '\n' < /run/secrets/openclaw_gateway_token)" >> "$env_file"
        fi

        if [ -r /run/secrets/openai_api_key ]; then
          printf 'OPENAI_API_KEY=%s\n' "$(tr -d '\n' < /run/secrets/openai_api_key)" >> "$env_file"
        fi

        if [ -r /run/secrets/anthropic_api_key ]; then
          printf 'ANTHROPIC_API_KEY=%s\n' "$(tr -d '\n' < /run/secrets/anthropic_api_key)" >> "$env_file"
        fi

        if [ -r /run/secrets/openrouter_api_key ]; then
          printf 'OPENROUTER_API_KEY=%s\n' "$(tr -d '\n' < /run/secrets/openrouter_api_key)" >> "$env_file"
        fi

        if [ -r /run/secrets/openclaw_telegram_bot_token ]; then
          printf 'TELEGRAM_BOT_TOKEN=%s\n' "$(tr -d '\n' < /run/secrets/openclaw_telegram_bot_token)" >> "$env_file"
        fi

        printf 'SEARXNG_BASE_URL=%s\n' "http://127.0.0.1:8888" >> "$env_file"
      '';

    home.activation.openclawDocuments =
      lib.hm.dag.entryAfter [ "writeBoundary" ] (
        ''
          documents_dir="${documentsDir}"
          workspace_dir="${workspaceDir}"

          if [ ! -d "$documents_dir" ]; then
            echo "OpenClaw documents directory not found: $documents_dir" >&2
            echo "Create a private checkout there, or override roles.openclaw.documentsRepoDir." >&2
            exit 1
          fi

          mkdir -p "$workspace_dir"
        ''
        + lib.concatMapStrings (name: ''
          if [ ! -f "$documents_dir/${name}" ]; then
            echo "Missing OpenClaw document: $documents_dir/${name}" >&2
            exit 1
          fi
        '') requiredDocumentFiles
        + lib.concatMapStrings (name: ''
          target="$workspace_dir/${name}"
          source="$documents_dir/${name}"

          if [ -e "$target" ] && [ ! -L "$target" ]; then
            echo "Refusing to replace non-symlink OpenClaw document: $target" >&2
            exit 1
          fi

          if [ -f "$source" ]; then
            ln -sfn "$source" "$target"
          else
            rm -f "$target"
          fi
        '') documentFiles
      );

    home.activation.openclawLocalSkills =
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        skills_dir="${workspaceDir}/skills"

        for skill_name in goplaces linux-screenshot searxng-search telegram-send; do
          skill_file="$skills_dir/$skill_name/SKILL.md"
          [ -L "$skill_file" ] || continue

          source_file="$(readlink -f "$skill_file")"
          rm -f "$skill_file"
          cp "$source_file" "$skill_file"
          chmod 644 "$skill_file"
        done

        mkdir -p "$skills_dir/linux-screenshot"
        cat > "$skills_dir/linux-screenshot/run.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec linux-screenshot "$@"
EOF
        chmod 755 "$skills_dir/linux-screenshot/run.sh"

        mkdir -p "$skills_dir/searxng-search"
        cat > "$skills_dir/searxng-search/run.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec searxng-search "$@"
EOF
        chmod 755 "$skills_dir/searxng-search/run.sh"

        mkdir -p "$skills_dir/goplaces"
        cat > "$skills_dir/goplaces/run.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec goplaces "$@"
EOF
        chmod 755 "$skills_dir/goplaces/run.sh"

        mkdir -p "$skills_dir/telegram-send"
        cat > "$skills_dir/telegram-send/run.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec telegram-send "$@"
EOF
        chmod 755 "$skills_dir/telegram-send/run.sh"
      '';

    home.activation.openclawWhatsApp =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${whatsappAuthDir}"
      '';

    home.activation.openclawMediaDirs =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${openclawScreenshotDir}"
      '';

    home.activation.openclawBundledPlugins =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        source_dir="${bundledPluginsSourceDir}"
        package_root="${config.programs.openclaw.package}/lib/openclaw"
        dist_root="${bundledPluginsRuntimeDistDir}"
        dist_dir="${bundledPluginsRuntimeExtensionsDir}"
        runtime_dir="${bundledPluginsRuntimeDir}"

        if [ -e "$runtime_dir" ]; then
          chmod -R u+w "$runtime_dir" || true
        fi
        rm -rf "$runtime_dir"
        mkdir -p "$dist_root"
        cp -r --no-preserve=mode "$package_root/dist/." "$dist_root/"
        chmod -R u+w "$runtime_dir"
        ln -sfn "$package_root/node_modules" "$runtime_dir/node_modules"

        for plugin_dir in "$dist_dir"/*; do
          [ -d "$plugin_dir" ] || continue

          plugin_name="$(basename "$plugin_dir")"
          source_plugin_dir="$source_dir/$plugin_name"
          runtime_plugin_dir="$dist_dir/$plugin_name"
          manifest="$source_plugin_dir/openclaw.plugin.json"
          runtime_index="$plugin_dir/index.js"
          runtime_setup="$plugin_dir/setup-entry.js"

          [ -f "$manifest" ] || continue
          [ -f "$runtime_index" ] || continue

          mkdir -p "$runtime_plugin_dir"
          cp "$manifest" "$runtime_plugin_dir/openclaw.plugin.json"

          if [ -f "$runtime_setup" ]; then
            cat > "$runtime_plugin_dir/package.json" <<EOF
        {
          "name": "@openclaw/$plugin_name-runtime",
          "private": true,
          "type": "module",
          "openclaw": {
            "extensions": ["./index.js"],
            "setupEntry": "./setup-entry.js"
          }
        }
        EOF
          else
            cat > "$runtime_plugin_dir/package.json" <<EOF
        {
          "name": "@openclaw/$plugin_name-runtime",
          "private": true,
          "type": "module",
          "openclaw": {
            "extensions": ["./index.js"]
          }
        }
        EOF
          fi
        done
      '';

    systemd.user.services.openclaw-gateway.Service.EnvironmentFile =
      "-${config.home.homeDirectory}/.config/openclaw/openclaw.env";
    systemd.user.services.openclaw-gateway.Service.Environment =
      [
        "OPENCLAW_BUNDLED_PLUGINS_DIR=${bundledPluginsRuntimeExtensionsDir}"
        "PATH=${openclawServicePath}:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
  };
}
