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
    home.packages = [ searxngSearch ];
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
          '';
        }
      ];

      config = {
        agents.defaults.model = {
          primary = "openai/gpt-5.1-codex";
          fallbacks = [ "openai/gpt-5.4" ];
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

    home.activation.openclawWhatsApp =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${whatsappAuthDir}"
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
      [ "OPENCLAW_BUNDLED_PLUGINS_DIR=${bundledPluginsRuntimeExtensionsDir}" ];
  };
}
