{ lib, pkgs, config, inputs, ... }:
let
  cfg = config.roles.openclaw;
  isLinux = pkgs.stdenv.isLinux;
  documentsDir = "${cfg.documentsRepoDir}/documents";
  requiredDocumentFiles = [ "AGENTS.md" "SOUL.md" "TOOLS.md" ];
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
  bundledPluginsSourceDir =
    "${config.programs.openclaw.package}/lib/openclaw/extensions";
  bundledPluginsDistDir =
    "${config.programs.openclaw.package}/lib/openclaw/dist/extensions";
  bundledPluginsRuntimeDir =
    "${config.home.homeDirectory}/.openclaw/bundled-plugins-runtime";
  bundledPluginsRuntimeDistDir = "${bundledPluginsRuntimeDir}/dist";
  bundledPluginsRuntimeExtensionsDir =
    "${bundledPluginsRuntimeDistDir}/extensions";
  openclawScreenshotDir =
    "${config.home.homeDirectory}/.openclaw/media/screenshots";
  openclawPlaybackGain = "0.1";
  openclawServicePath = lib.makeBinPath [
    playAudioLocal
    speakLocal
    youtubeSearchApi
    youtubeWatchHistory
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

  playAudioLocal = pkgs.writeShellApplication {
    name = "play-audio-local";
    runtimeInputs = with pkgs; [ coreutils vlc ];
    text = ''
      set -euo pipefail

      if [ $# -ne 1 ]; then
        echo "usage: play-audio-local <path|MEDIA:path>" >&2
        exit 2
      fi

      input="$1"
      case "$input" in
        MEDIA:*)
          input="''${input#MEDIA:}"
          ;;
      esac

      if [ ! -f "$input" ]; then
        echo "play-audio-local: file not found: $input" >&2
        exit 1
      fi

      exec cvlc --play-and-exit --intf dummy --gain ${openclawPlaybackGain} "$input"
    '';
  };

  speakLocal = pkgs.writeShellApplication {
    name = "speak-local";
    runtimeInputs = with pkgs; [ coreutils curl jq vlc ];
    text = ''
      set -euo pipefail

      if [ $# -lt 1 ]; then
        echo "usage: speak-local <text...>" >&2
        exit 2
      fi

      : "''${ELEVENLABS_API_KEY:?ELEVENLABS_API_KEY is required}"

      text="$*"
      temp_dir="$(mktemp -d /tmp/openclaw-speak-local-XXXXXX)"
      audio_path="$temp_dir/voice.mp3"

      cleanup() {
        rm -rf "$temp_dir"
      }
      trap cleanup EXIT

      curl --silent --show-error --fail \
        --request POST \
        --url "https://api.elevenlabs.io/v1/text-to-speech/WQ6Xb0Hj95La1FFC6b16?output_format=mp3_44100_128" \
        --header "xi-api-key: ''${ELEVENLABS_API_KEY}" \
        --header 'content-type: application/json' \
        --data "$(
          jq -cn \
            --arg text "$text" \
            '{
              text: $text,
              model_id: "eleven_v3",
              apply_text_normalization: "auto",
              language_code: "en",
              voice_settings: {
                stability: 0.5,
                similarity_boost: 0.75,
                style: 0.0,
                use_speaker_boost: true,
                speed: 1.0
              }
            }'
        )" \
        --output "$audio_path"

      exec cvlc --play-and-exit --intf dummy --gain ${openclawPlaybackGain} "$audio_path"
    '';
  };

  youtubeWatchHistory = pkgs.writeShellApplication {
    name = "youtube-watch-history";
    runtimeInputs = with pkgs; [ coreutils findutils gnugrep jq sqlite ];
    text = ''
            set -euo pipefail

            limit="''${1:-25}"
            query="''${2:-}"

            if ! printf '%s\n' "$limit" | grep -Eq '^[0-9]+$'; then
              echo "youtube-watch-history: limit must be a positive integer" >&2
              exit 2
            fi

            if [ "$limit" -lt 1 ]; then
              echo "youtube-watch-history: limit must be at least 1" >&2
              exit 2
            fi

            tmp_jsonl="$(mktemp /tmp/youtube-watch-history-XXXXXX.jsonl)"
            : > "$tmp_jsonl"

            cleanup() {
              rm -f "$tmp_jsonl" /tmp/youtube-watch-history-db-*.sqlite
            }
            trap cleanup EXIT

            collect_db() {
              local browser="$1"
              local source_db="$2"
              local temp_db

              [ -f "$source_db" ] || return 0

              temp_db="$(mktemp /tmp/youtube-watch-history-db-XXXXXX.sqlite)"
              cp "$source_db" "$temp_db"

              if [ "$browser" = "chromium" ]; then
                sqlite3 -readonly "$temp_db" "
                  SELECT json_object(
                    'browser', 'chromium',
                    'url', urls.url,
                    'title', COALESCE(urls.title, null),
                    'visited_at_epoch', CAST((visits.visit_time / 1000000) - 11644473600 AS INTEGER)
                  )
                  FROM visits
                  JOIN urls ON urls.id = visits.url
                  WHERE (
                    urls.url LIKE 'https://www.youtube.com/watch%'
                    OR urls.url LIKE 'https://m.youtube.com/watch%'
                    OR urls.url LIKE 'https://youtu.be/%'
                  )
                  ORDER BY visits.visit_time DESC
                  LIMIT 500;
                " >> "$tmp_jsonl" || true
              else
                sqlite3 -readonly "$temp_db" "
                  SELECT json_object(
                    'browser', '$browser',
                    'url', moz_places.url,
                    'title', COALESCE(moz_places.title, null),
                    'visited_at_epoch', CAST(moz_historyvisits.visit_date / 1000000 AS INTEGER)
                  )
                  FROM moz_historyvisits
                  JOIN moz_places ON moz_places.id = moz_historyvisits.place_id
                  WHERE (
                    moz_places.url LIKE 'https://www.youtube.com/watch%'
                    OR moz_places.url LIKE 'https://m.youtube.com/watch%'
                    OR moz_places.url LIKE 'https://youtu.be/%'
                  )
                  ORDER BY moz_historyvisits.visit_date DESC
                  LIMIT 500;
                " >> "$tmp_jsonl" || true
              fi
            }

            while IFS= read -r db; do
              collect_db "chromium" "$db"
            done < <(
              find "$HOME/.config/chromium" -maxdepth 3 -type f -name History 2>/dev/null
            )

            while IFS= read -r db; do
              collect_db "firefox" "$db"
            done < <(
              find "$HOME/.mozilla/firefox" -maxdepth 3 -type f -name places.sqlite 2>/dev/null
            )

            while IFS= read -r db; do
              collect_db "zen" "$db"
            done < <(
              find "$HOME/.zen" -maxdepth 3 -type f -name places.sqlite 2>/dev/null
            )

            if [ ! -s "$tmp_jsonl" ]; then
              echo "youtube-watch-history: no local YouTube watch history database found" >&2
              exit 1
            fi

            jq_filter="$(cat <<'EOF'
              map(
                . + {
                  visited_at: (.visited_at_epoch | todateiso8601),
                  video_id: (
                    if (.url | test("v=")) then
                      (.url | capture("[?&]v=(?<id>[^&]+)").id)
                    elif (.url | test("youtu\\.be/")) then
                      (.url | capture("youtu\\.be/(?<id>[^?&/]+)").id)
                    else
                      null
                    end
                  )
                }
              )
              | sort_by(.visited_at_epoch)
              | reverse
              | reduce .[] as $item ([]; if any(.[]; .url == $item.url) then . else . + [$item] end)
      EOF
            )"

            if [ -n "$query" ]; then
              jq_filter="$jq_filter | map(select((.title + \" \" + .url) | ascii_downcase | contains(\$query)))"
            fi

            jq_filter="$jq_filter | .[0:\$limit]"

            if [ -n "$query" ]; then
              jq -s --arg query "$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')" --argjson limit "$limit" "$jq_filter" "$tmp_jsonl"
            else
              jq -s --argjson limit "$limit" "$jq_filter" "$tmp_jsonl"
            fi
    '';
  };

  youtubeSearchApi = pkgs.writeShellApplication {
    name = "youtube-search-api";
    runtimeInputs = with pkgs; [ coreutils curl gnugrep jq ];
    text = ''
      set -euo pipefail

      if [ $# -lt 1 ]; then
        echo "usage: youtube-search-api <keywords> [video_type] [limit]" >&2
        exit 2
      fi

      : "''${YOUTUBE_API_KEY:?YOUTUBE_API_KEY is required}"

      keywords="$1"
      video_type="''${2:-Videos}"
      limit="''${3:-25}"

      case "$video_type" in
        Videos)
          search_type="video"
          video_duration=""
          ;;
        Shorts)
          search_type="video"
          video_duration="short"
          ;;
        Channels)
          search_type="channel"
          video_duration=""
          ;;
        Playlists)
          search_type="playlist"
          video_duration=""
          ;;
        *)
          echo "youtube-search-api: invalid video_type: $video_type" >&2
          echo "supported values: Videos, Shorts, Channels, Playlists" >&2
          exit 2
          ;;
      esac

      if ! printf '%s\n' "$limit" | grep -Eq '^[0-9]+$'; then
        echo "youtube-search-api: limit must be a positive integer" >&2
        exit 2
      fi

      if [ "$limit" -lt 1 ]; then
        echo "youtube-search-api: limit must be at least 1" >&2
        exit 2
      fi

      tmp_results="$(mktemp /tmp/youtube-search-api-results-XXXXXX.json)"
      search_body="$(mktemp /tmp/youtube-search-api-search-XXXXXX.json)"
      videos_body="$(mktemp /tmp/youtube-search-api-videos-XXXXXX.json)"
      printf '[]' > "$tmp_results"

      cleanup() {
        rm -f "$tmp_results" "$search_body" "$videos_body"
      }
      trap cleanup EXIT

      total=0
      page_token=""

      while [ "$total" -lt "$limit" ]; do
        remaining=$((limit - total))
        if [ "$remaining" -gt 50 ]; then
          batch_size=50
        else
          batch_size="$remaining"
        fi

        curl_args=(
          --silent
          --show-error
          --output "$search_body"
          --write-out '%{http_code}'
          --get
          "https://www.googleapis.com/youtube/v3/search"
          --data-urlencode "part=snippet"
          --data-urlencode "q=$keywords"
          --data-urlencode "maxResults=$batch_size"
          --data-urlencode "type=$search_type"
          --data-urlencode "key=$YOUTUBE_API_KEY"
        )

        if [ -n "$page_token" ]; then
          curl_args+=( --data-urlencode "pageToken=$page_token" )
        fi

        if [ -n "$video_duration" ]; then
          curl_args+=( --data-urlencode "videoDuration=$video_duration" )
        fi

        http_code="$(curl "''${curl_args[@]}")"
        if [ "$http_code" != "200" ]; then
          jq . "$search_body" 2>/dev/null || cat "$search_body"
          exit 1
        fi

        batch="$(
          jq -c '
            [
              .items[]
              | {
                  id: (
                    .id.videoId
                    // .id.channelId
                    // .id.playlistId
                    // ""
                  ),
                  kind: (
                    .id.kind
                    // ""
                    | sub("^youtube#"; "")
                  ),
                  title: (.snippet.title // ""),
                  description: (.snippet.description // ""),
                  channel: (.snippet.channelTitle // ""),
                  published_at: (.snippet.publishedAt // ""),
                  url: (
                    if .id.videoId then
                      "https://www.youtube.com/watch?v=" + .id.videoId
                    elif .id.channelId then
                      "https://www.youtube.com/channel/" + .id.channelId
                    elif .id.playlistId then
                      "https://www.youtube.com/playlist?list=" + .id.playlistId
                    else
                      ""
                    end
                  )
                }
            ]
          ' "$search_body"
        )"

        jq -c --argjson batch "$batch" '. + $batch' "$tmp_results" > "$tmp_results.next"
        mv "$tmp_results.next" "$tmp_results"

        total="$(jq 'length' "$tmp_results")"
        page_token="$(jq -r '.nextPageToken // empty' "$search_body")"

        if [ -z "$page_token" ]; then
          break
        fi
      done

      if [ "$search_type" = "video" ]; then
        video_ids="$(
          jq -r '.[].id | select(length > 0)' "$tmp_results" | paste -sd, -
        )"

        if [ -n "$video_ids" ]; then
          http_code="$(
            curl \
              --silent \
              --show-error \
              --output "$videos_body" \
              --write-out '%{http_code}' \
              --get "https://www.googleapis.com/youtube/v3/videos" \
              --data-urlencode "part=statistics,contentDetails" \
              --data-urlencode "id=$video_ids" \
              --data-urlencode "maxResults=50" \
              --data-urlencode "key=$YOUTUBE_API_KEY"
          )"

          if [ "$http_code" = "200" ]; then
            jq '
              . as $results
              | (
                  input
                  | .items
                  | map({
                      key: .id,
                      value: {
                        view_count: (.statistics.viewCount // null),
                        duration: (.contentDetails.duration // null)
                      }
                    })
                  | from_entries
                ) as $video_meta
              | $results
              | map(. + ($video_meta[.id] // {}))
            ' "$tmp_results" "$videos_body" > "$tmp_results.next"
            mv "$tmp_results.next" "$tmp_results"
          fi
        fi
      fi

      jq '.[0:'"$limit"']' "$tmp_results"
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
    home.packages = [
      playAudioLocal
      searxngSearch
      speakLocal
      youtubeSearchApi
      youtubeWatchHistory
      pkgs.cron
      pkgs.python3
      pkgs.python3Packages.pip
    ];
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
          description =
            "Send a plain Telegram message through the Telegram Bot API.";
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
          description =
            "Capture a screenshot from the current Wayland desktop on dorkbones.";
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
        {
          name = "speak-local";
          description =
            "Generate speech with OpenClaw TTS and play it through dorkbones speakers.";
          mode = "inline";
          body = ''
            Use this skill when the user wants to hear speech locally on this machine.

            Run:
            `speak-local <text to say>`

            Before you run it, shape the text for speech:
            - Prefer natural, narrative phrasing over flat prose.
            - Prefer short Eleven v3 audio tags when they help delivery, like `[whispers]`, `[curious]`, `[sighs]`, or `[excited]`.
            - Use light punctuation for pacing: commas, em dashes, ellipses, and occasional short quoted beats.
            - Do not use SSML break tags like `<break ... />`; Eleven v3 relies on punctuation and audio tags instead.
            - Do not overload the text with lots of tags or stage directions.
            - Normalize awkward speech inputs before playback: expand URLs, slash commands, timestamps, file paths, and dense numbers into how a human would naturally say them.
            - If a pronunciation is wrong, try a more phonetic spelling or a simpler alias.

            Keep the spoken text concise and performance-ready. Rewrite it slightly for delivery when that improves the result, unless the user explicitly wants exact wording.

            This skill already handles TTS generation and local playback on dorkbones speakers.

            Do not use the generic `tts` tool for this. The goal is immediate local playback.
          '';
        }
        {
          name = "python-project-env";
          description =
            "Set up and use a project-local Python virtualenv for Python work inside the OpenClaw workspace.";
          mode = "inline";
          body = ''
            Use this skill whenever you need to install Python dependencies or run a Python project inside the OpenClaw workspace.

            The system Python on this machine is Nix-managed. Do not run bare `pip install ...` against the system interpreter.

            Default workflow:
            1. Change into the target project directory.
            2. Create a local virtualenv if `.venv` does not exist:
               `python -m venv .venv`
            3. Activate it:
               `source .venv/bin/activate`
            4. Upgrade pip inside the virtualenv:
               `python -m pip install -U pip`
            5. Install dependencies inside the virtualenv:
               `python -m pip install -r requirements.txt`

            Rules:
            - Prefer `python -m pip ...` over bare `pip ...`.
            - Keep the virtualenv inside the project as `.venv`.
            - If the project uses a different dependency file or tool, adapt, but still keep installs inside `.venv` unless the project explicitly requires something else.
            - If a command needs the environment, run it from an activated `.venv` or call `.venv/bin/python` directly.
          '';
        }
        {
          name = "youtube-search-api-skill";
          description =
            "Search YouTube directly through the YouTube Data API and return structured results for videos, Shorts, channels, or playlists.";
          mode = "inline";
          body = ''
            Use this skill to search YouTube directly with the YouTube Data API.

            Run:
            `youtube-search-api "<keywords>" [Videos|Shorts|Channels|Playlists] [limit]`

            Inputs:
            - `keywords`: required search string
            - `video_type`: optional, defaults to `Videos`
            - `limit`: optional, defaults to `25`

            Behavior:
            - The local command uses `curl` against the YouTube Data API.
            - It returns structured JSON directly on success.
            - `Shorts` is implemented as YouTube videos filtered with `videoDuration=short`.
            - For video searches, it also includes view counts and durations when available.

            Before running:
            - Check `YOUTUBE_API_KEY`.
            - If the key is missing, stop and ask the user to configure `youtube_api_key`.

            Error handling:
            - If the API returns an authorization or quota error, report it directly.
            - For empty or weak results, reformulate the query once and run the command again if the user asked for active searching.
          '';
        }
        {
          name = "youtube-watch-history";
          description =
            "Read local browser history and return recently visited YouTube watch URLs from this machine.";
          mode = "inline";
          body = ''
            Use this skill when the task depends on what the user actually watched recently on this machine.

            Run:
            `youtube-watch-history [limit] [query]`

            Examples:
            - `youtube-watch-history`
            - `youtube-watch-history 10`
            - `youtube-watch-history 20 "openclaw"`

            Behavior:
            - The local command scans Chromium, Firefox, and Zen history databases if present.
            - It returns structured JSON for recent YouTube watch-page visits.
            - Prefer this skill over inference when the user asks what they watched or whether a result matches recent viewing activity.

            If no local browser history database is found, report that directly.
          '';
        }
      ];

      config = {
        models.mode = "replace";

        agents.defaults.model = {
          primary = "openrouter/openai/gpt-5.2";
          fallbacks = [ ];
        };

        agents.defaults.imageModel = {
          primary = "openai/gpt-5-mini";
          fallbacks = [ "anthropic/claude-opus-4-5" ];
        };

        messages.tts = {
          auto = "tagged";
          mode = "final";
          provider = "elevenlabs";
          maxTextLength = 4000;
          timeoutMs = 30000;
          providers = {
            elevenlabs = {
              apiKey = {
                source = "env";
                provider = "default";
                id = "ELEVENLABS_API_KEY";
              };
            };
          };
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

        if [ -r /run/secrets/elevenlabs_api_key ]; then
          printf 'ELEVENLABS_API_KEY=%s\n' "$(tr -d '\n' < /run/secrets/elevenlabs_api_key)" >> "$env_file"
          printf 'XI_API_KEY=%s\n' "$(tr -d '\n' < /run/secrets/elevenlabs_api_key)" >> "$env_file"
        fi

        if [ -r /run/secrets/youtube_api_key ]; then
          printf 'YOUTUBE_API_KEY=%s\n' "$(tr -d '\n' < /run/secrets/youtube_api_key)" >> "$env_file"
        fi

        if [ -r /run/secrets/openclaw_telegram_bot_token ]; then
          printf 'TELEGRAM_BOT_TOKEN=%s\n' "$(tr -d '\n' < /run/secrets/openclaw_telegram_bot_token)" >> "$env_file"
        fi

        printf 'SEARXNG_BASE_URL=%s\n' "http://127.0.0.1:8888" >> "$env_file"
      '';

    home.activation.openclawDocuments =
      lib.hm.dag.entryAfter [ "writeBoundary" ] (''
        documents_dir="${documentsDir}"
        workspace_dir="${workspaceDir}"

        if [ ! -d "$documents_dir" ]; then
          echo "OpenClaw documents directory not found: $documents_dir" >&2
          echo "Create a private checkout there, or override roles.openclaw.documentsRepoDir." >&2
          exit 1
        fi

        mkdir -p "$workspace_dir"
      '' + lib.concatMapStrings (name: ''
        if [ ! -f "$documents_dir/${name}" ]; then
          echo "Missing OpenClaw document: $documents_dir/${name}" >&2
          exit 1
        fi
      '') requiredDocumentFiles + lib.concatMapStrings (name: ''
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
      '') documentFiles);

    home.activation.openclawLocalSkills =
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
                skills_dir="${workspaceDir}/skills"

                for skill_name in goplaces linux-screenshot searxng-search speak-local telegram-send youtube-search-api-skill youtube-watch-history; do
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

                mkdir -p "$skills_dir/speak-local"
                cat > "$skills_dir/speak-local/run.sh" <<'EOF'
        #!/usr/bin/env bash
        set -euo pipefail
        exec speak-local "$@"
        EOF
                chmod 755 "$skills_dir/speak-local/run.sh"

                mkdir -p "$skills_dir/youtube-search-api-skill"
                cat > "$skills_dir/youtube-search-api-skill/run.sh" <<'EOF'
        #!/usr/bin/env bash
        set -euo pipefail
        exec youtube-search-api "$@"
        EOF
                chmod 755 "$skills_dir/youtube-search-api-skill/run.sh"

                mkdir -p "$skills_dir/youtube-watch-history"
                cat > "$skills_dir/youtube-watch-history/run.sh" <<'EOF'
        #!/usr/bin/env bash
        set -euo pipefail
        exec youtube-watch-history "$@"
        EOF
                chmod 755 "$skills_dir/youtube-watch-history/run.sh"
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
    systemd.user.services.openclaw-gateway.Service.Environment = [
      "OPENCLAW_BUNDLED_PLUGINS_DIR=${bundledPluginsRuntimeExtensionsDir}"
      "PATH=${openclawServicePath}:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
    ];
  };
}
