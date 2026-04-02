{ lib, pkgs, config, inputs, ... }:
let
  cfg = config.roles.openclaw;
  isLinux = pkgs.stdenv.isLinux;
  documentsDir = builtins.path {
    path = "${config.dotfiles.root}/openclaw/documents";
    name = "openclaw-documents";
  };

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

  options.roles.openclaw.enable = lib.mkEnableOption "OpenClaw role";

  config = lib.mkIf (cfg.enable && isLinux) {
    home.packages = [ searxngSearch ];

    programs.openclaw = {
      enable = true;
      package = pkgs.openclaw-gateway;
      documents = documentsDir;

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

        printf 'SEARXNG_BASE_URL=%s\n' "http://127.0.0.1:8888" >> "$env_file"
      '';

    systemd.user.services.openclaw-gateway.Service.EnvironmentFile =
      "-${config.home.homeDirectory}/.config/openclaw/openclaw.env";
  };
}
