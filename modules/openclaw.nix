{ config, lib, pkgs, ... }:
let
  cfg = config.services.openclawLocal;

  stateDir = "/var/lib/openclaw";
  sshDir = "${stateDir}/.ssh";
  sshPrivateKeyPath = "${sshDir}/id_ed25519";
  sshPublicKeyPath = "${sshPrivateKeyPath}.pub";
  sshKnownHostsPath = "${sshDir}/known_hosts";
  repoMountDir = "${stateDir}/repo";
  workspaceDir = "${stateDir}/workspace";
  workspaceScriptsDir = "${workspaceDir}/scripts";
  whatsappAuthDir = "${stateDir}/whatsapp/main";
  bundledPluginsRuntimeDir = "${stateDir}/bundled-plugins-runtime";
  bundledPluginsRuntimeDistDir = "${bundledPluginsRuntimeDir}/dist";
  bundledPluginsRuntimeExtensionsDir =
    "${bundledPluginsRuntimeDistDir}/extensions";
  openclawScreenshotDir = "${stateDir}/media/screenshots";
  repoDir = cfg.repoDir;
  documentsDir = "${repoDir}/documents";
  customSkillsDir = "${repoDir}/custom/skills";
  customScriptsDir = "${repoDir}/custom/scripts";
  openclawConfigPath = "${stateDir}/openclaw.json";
  syncStampPath = "${stateDir}/.sync-stamp";
  requiredDocumentFiles = [ "AGENTS.md" "SOUL.md" "TOOLS.md" ];
  optionalDocumentFiles = [
    "IDENTITY.md"
    "USER.md"
    "LORE.md"
    "HEARTBEAT.md"
    "PROMPTING-EXAMPLES.md"
  ];
  documentFiles = requiredDocumentFiles ++ optionalDocumentFiles;
  telegramTokenPath = "${stateDir}/telegram-bot-token";

  bundledPluginsSourceDir = "${pkgs.openclaw-gateway}/lib/openclaw/extensions";
  openclawPackageRoot = "${pkgs.openclaw-gateway}/lib/openclaw";

  openclawPlaybackGain = "0.1";

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

  openclawSync = pkgs.writeShellApplication {
    name = "openclaw-sync";
    runtimeInputs = with pkgs; [ coreutils systemd ];
    text = ''
      set -euo pipefail

      if [ "$(id -u)" -ne 0 ]; then
        echo "openclaw-sync: run with sudo" >&2
        exit 1
      fi

      systemctl restart openclaw-prepare.service
      systemctl restart openclaw.service
      printf 'OpenClaw synced and restarted.\n'
    '';
  };

  openclawSyncStatus = pkgs.writeShellApplication {
    name = "openclaw-sync-status";
    runtimeInputs = with pkgs; [ coreutils findutils gnugrep ];
    text = ''
      set -euo pipefail

      repo_dir="${repoDir}"
      stamp_path="${syncStampPath}"

      if [ ! -d "$repo_dir" ]; then
        echo "missing-repo: $repo_dir"
        exit 1
      fi

      if [ ! -f "$stamp_path" ]; then
        echo "out-of-sync: no sync stamp"
        exit 1
      fi

      stamp="$(tr -d '\n' < "$stamp_path")"
      if ! printf '%s\n' "$stamp" | grep -Eq '^[0-9]+$'; then
        echo "out-of-sync: invalid sync stamp"
        exit 1
      fi

      if find \
        "$repo_dir/documents" \
        "$repo_dir/custom/skills" \
        "$repo_dir/custom/scripts" \
        -type f \
        -newermt "@$stamp" \
        -print -quit 2>/dev/null | grep -q .; then
        echo "out-of-sync"
        exit 1
      fi

      echo "in-sync"
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
      : "''${OPENCLAW_ELEVENLABS_VOICE_ID:?OPENCLAW_ELEVENLABS_VOICE_ID is required}"

      text="$*"
      temp_dir="$(mktemp -d /tmp/openclaw-speak-local-XXXXXX)"
      audio_path="$temp_dir/voice.mp3"

      cleanup() {
        rm -rf "$temp_dir"
      }
      trap cleanup EXIT

      curl --silent --show-error --fail \
        --request POST \
        --url "https://api.elevenlabs.io/v1/text-to-speech/''${OPENCLAW_ELEVENLABS_VOICE_ID}?output_format=mp3_44100_128" \
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

  linuxScreenshot = pkgs.writeShellApplication {
    name = "linux-screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gnugrep
      gnused
      grim
      slurp
      systemd
    ];
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

  openclawServicePath = lib.makeBinPath [
    openclawSync
    openclawSyncStatus
    linuxScreenshot
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
    pkgs.sqlite
    pkgs.systemd
    pkgs.vlc
    pkgs.openssh
  ];

  skills = [
    {
      name = "searxng-search";
      description = "Search the web through the local SearxNG instance.";
      command = "searxng-search";
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
      command = "telegram-send";
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
      command = "linux-screenshot";
      body = ''
        Use the `linux-screenshot` CLI when the user asks what is on the screen, asks you to inspect the desktop UI, or explicitly requests a screenshot from this machine.

        Default to a full-screen capture:
        `linux-screenshot`

        Only use region mode when the user explicitly wants a cropped selection and can interact with the desktop:
        `linux-screenshot --region`

        The command prints `MEDIA:/var/lib/openclaw/media/screenshots/...png`.

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
      command = "speak-local";
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
      name = "youtube-search-api-skill";
      description =
        "Search YouTube directly through the YouTube Data API and return structured results for videos, Shorts, channels, or playlists.";
      command = "youtube-search-api";
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
      command = "youtube-watch-history";
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

  skillFiles = builtins.listToAttrs (map (skill: {
    name = skill.name;
    value = pkgs.writeText "openclaw-skill-${skill.name}.md" ''
      ---
      name: ${skill.name}
      description: ${skill.description}
      ---

      ${skill.body}
    '';
  }) skills);

  openclawConfigTemplate = pkgs.writeText "openclaw-system-template.json"
    (builtins.toJSON {
    agents.defaults = {
      workspace = workspaceDir;
      model = {
        primary = "router/openai/gpt-5.1-codex-mini";
        fallbacks = [ ];
      };
      imageModel = {
        primary = "openai/gpt-5-mini";
        fallbacks = [ "anthropic/claude-opus-4-5" ];
      };
    };

    messages.tts = {
      auto = "tagged";
      mode = "final";
      provider = "elevenlabs";
      maxTextLength = 4000;
      timeoutMs = 30000;
      elevenlabs = {
        baseUrl = "https://api.elevenlabs.io";
        voiceId = "__OPENCLAW_ELEVENLABS_VOICE_ID__";
        modelId = "eleven_v3";
        applyTextNormalization = "auto";
        languageCode = "en";
        voiceSettings = {
          stability = 0.5;
          similarityBoost = 0.75;
          style = 0.0;
          useSpeakerBoost = true;
          speed = 1.0;
        };
      };
    };

    tools.exec = {
      host = "gateway";
      security = "allowlist";
      ask = "on-miss";
      pathPrepend = [
        "${linuxScreenshot}/bin"
        "${playAudioLocal}/bin"
        "${speakLocal}/bin"
        "${youtubeSearchApi}/bin"
        "${youtubeWatchHistory}/bin"
        "${searxngSearch}/bin"
        "${telegramSend}/bin"
        "${pkgs.openssh}/bin"
        "/run/current-system/sw/bin"
      ];
    };

    models = {
      mode = "replace";
      providers.router = {
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
      tokenFile = telegramTokenPath;
      allowFrom = [ "*" ];
      dmPolicy = "open";
      groupPolicy = "disabled";
    };
    });
in {
  options.services.openclawLocal = {
    enable = lib.mkEnableOption "hardened local OpenClaw gateway service";

    repoDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/bas/Developer/openclaw";
      description = ''
        Optional private checkout that contains authored OpenClaw documents,
        custom skills, and scripts. If missing, OpenClaw still starts with
        fallback docs and any previously projected runtime content.
      '';
    };

    operatorUser = lib.mkOption {
      type = lib.types.str;
      default = "bas";
      description = ''
        Local operator account that should be able to inspect the OpenClaw
        state directory and manage the shared handoff directory.
      '';
    };

    sharedDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/bas/.openclaw-share";
      description = ''
        Writable handoff directory inside the operator's home. OpenClaw gets
        access to this path even with ProtectHome enabled, so workspace symlinks
        can point here when you intentionally want to share writable files.
      '';
    };

    elevenLabsVoiceId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "WQ6Xb0Hj95La1FFC6b16";
      description = ''
        ElevenLabs voice ID injected into the runtime environment as
        OPENCLAW_ELEVENLABS_VOICE_ID and rendered into the OpenClaw config.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.openclaw = { };

    users.users.openclaw = {
      isSystemUser = true;
      group = "openclaw";
      home = stateDir;
      createHome = true;
      shell = pkgs.bash;
    };

    users.users.${cfg.operatorUser}.extraGroups = [ "openclaw" ];

    systemd.services.openclaw-prepare = {
      description = "Prepare hardened OpenClaw state, workspace, and runtime";
      wantedBy = [ "multi-user.target" ];
      before = [ "openclaw.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
        UMask = "0077";
        BindReadOnlyPaths = [ "${repoDir}:${repoMountDir}" ];
      };
      script = ''
        set -euo pipefail

        state_dir=${stateDir}
        workspace_dir=${workspaceDir}
        skills_dir="$workspace_dir/skills"
        scripts_dir="${workspaceScriptsDir}"
        env_file="$state_dir/openclaw.env"
        approvals_dir="$state_dir/.openclaw"
        approvals_file="$approvals_dir/exec-approvals.json"
        ssh_dir="${sshDir}"
        ssh_private_key="${sshPrivateKeyPath}"
        ssh_public_key="${sshPublicKeyPath}"
        ssh_known_hosts="${sshKnownHostsPath}"
        telegram_token_file="${telegramTokenPath}"
        config_file="${openclawConfigPath}"
        shared_dir="${cfg.sharedDir}"
        repo_dir="${repoDir}"
        repo_mount_dir="${repoMountDir}"
        documents_dir="$repo_mount_dir/documents"
        custom_skills_dir="$repo_mount_dir/custom/skills"
        custom_scripts_dir="$repo_mount_dir/custom/scripts"
        runtime_dir=${bundledPluginsRuntimeDir}
        dist_root=${bundledPluginsRuntimeDistDir}
        dist_dir=${bundledPluginsRuntimeExtensionsDir}
        package_root=${openclawPackageRoot}
        source_dir=${bundledPluginsSourceDir}

        install -d -m 2770 -o ${cfg.operatorUser} -g openclaw \
          "$state_dir" \
          "$approvals_dir" \
          "$ssh_dir" \
          "$workspace_dir" \
          "$skills_dir" \
          "$scripts_dir" \
          ${whatsappAuthDir} \
          ${openclawScreenshotDir}
        install -d -m 2770 -o ${cfg.operatorUser} -g openclaw "$shared_dir"

        : > "$env_file"
        chmod 0600 "$env_file"
        chown openclaw:openclaw "$env_file"

        chmod 0700 "$ssh_dir"
        chown openclaw:openclaw "$ssh_dir"
        if [ ! -f "$ssh_private_key" ]; then
          ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f "$ssh_private_key"
        fi
        chown openclaw:openclaw "$ssh_private_key" "$ssh_public_key"
        chmod 0600 "$ssh_private_key"
        chmod 0644 "$ssh_public_key"
        touch "$ssh_known_hosts"
        chown openclaw:openclaw "$ssh_known_hosts"
        chmod 0644 "$ssh_known_hosts"

        append_secret() {
          local env_name="$1"
          local secret_path="$2"

          if [ -r "$secret_path" ]; then
            printf '%s=%s\n' "$env_name" "$(${pkgs.coreutils}/bin/tr -d '\n' < "$secret_path")" >> "$env_file"
          fi
        }

        append_secret OPENCLAW_GATEWAY_TOKEN ${config.sops.secrets.openclaw_gateway_token.path}
        append_secret OPENAI_API_KEY ${config.sops.secrets.openai_api_key.path}
        append_secret ANTHROPIC_API_KEY ${config.sops.secrets.anthropic_api_key.path}
        append_secret OPENROUTER_API_KEY ${config.sops.secrets.openrouter_api_key.path}
        append_secret ELEVENLABS_API_KEY ${config.sops.secrets.elevenlabs_api_key.path}
        append_secret XI_API_KEY ${config.sops.secrets.elevenlabs_api_key.path}
        append_secret YOUTUBE_API_KEY ${config.sops.secrets.youtube_api_key.path}
        append_secret TELEGRAM_BOT_TOKEN ${config.sops.secrets.openclaw_telegram_bot_token.path}
        ${lib.optionalString (cfg.elevenLabsVoiceId != null) ''
          printf 'OPENCLAW_ELEVENLABS_VOICE_ID=%s\n' '${cfg.elevenLabsVoiceId}' >> "$env_file"
        ''}
        printf 'SEARXNG_BASE_URL=%s\n' "http://127.0.0.1:8888" >> "$env_file"
        chown openclaw:openclaw "$env_file"

        install -m 0400 -o openclaw -g openclaw \
          ${config.sops.secrets.openclaw_telegram_bot_token.path} \
          "$telegram_token_file"

        voice_id=""
        if [ -r "$env_file" ]; then
          voice_id="$(sed -n 's/^OPENCLAW_ELEVENLABS_VOICE_ID=//p' "$env_file" | head -n1)"
        fi
        if [ -z "$voice_id" ]; then
          echo "openclaw-prepare: OPENCLAW_ELEVENLABS_VOICE_ID is missing; TTS voice selection may fail." >&2
        fi
        sed "s/__OPENCLAW_ELEVENLABS_VOICE_ID__/$voice_id/g" ${openclawConfigTemplate} > "$config_file"
        chown openclaw:openclaw "$config_file"
        chmod 0640 "$config_file"

        if [ -f "$approvals_file" ]; then
          ${pkgs.jq}/bin/jq '
            .version = 1
            | .defaults = ((.defaults // {}) + {
                security: "allowlist",
                ask: "on-miss",
                askFallback: "deny",
                autoAllowSkills: true
              })
            | .agents = (.agents // {})
          ' "$approvals_file" > "$approvals_file.tmp"
          mv "$approvals_file.tmp" "$approvals_file"
        else
          printf '%s\n' \
            '{' \
            '  "version": 1,' \
            '  "defaults": {' \
            '    "security": "allowlist",' \
            '    "ask": "on-miss",' \
            '    "askFallback": "deny",' \
            '    "autoAllowSkills": true' \
            '  },' \
            '  "agents": {}' \
            '}' \
            > "$approvals_file"
        fi
        chown openclaw:openclaw "$approvals_file"
        chmod 0660 "$approvals_file"

        if [ -d "$documents_dir" ]; then
          ${lib.concatMapStrings (name: ''
            if [ ! -f "$documents_dir/${name}" ]; then
              echo "openclaw-prepare: missing document in repo: $documents_dir/${name}" >&2
            fi
          '') requiredDocumentFiles}
        else
          echo "openclaw-prepare: repo not found at $repo_dir; using fallback runtime docs and existing custom content if present." >&2
        fi

        write_fallback_doc() {
          local path="$1"
          local content="$2"
          if [ ! -e "$path" ]; then
            printf '%s\n' "$content" > "$path"
            chown openclaw:openclaw "$path"
            chmod 0660 "$path"
          fi
        }

        ${lib.concatMapStrings (name: ''
          if [ -f "$documents_dir/${name}" ]; then
            cp "$documents_dir/${name}" "$workspace_dir/${name}"
            chown openclaw:openclaw "$workspace_dir/${name}"
            chmod 0660 "$workspace_dir/${name}"
          elif [ -e "$workspace_dir/${name}" ]; then
            :
          else
            rm -f "$workspace_dir/${name}"
          fi
        '') documentFiles}

        write_fallback_doc "$workspace_dir/AGENTS.md" '# AGENTS.md'
        write_fallback_doc "$workspace_dir/SOUL.md" '# SOUL.md'
        write_fallback_doc "$workspace_dir/TOOLS.md" '# TOOLS.md'

        rm -rf "$skills_dir"
        install -d -m 2770 -o ${cfg.operatorUser} -g openclaw "$skills_dir"
        install -d -m 2770 -o ${cfg.operatorUser} -g openclaw "$scripts_dir"

        ${lib.concatMapStrings (skill: ''
          install -d -m 2770 -o ${cfg.operatorUser} -g openclaw "$skills_dir/${skill.name}"
          cp ${skillFiles.${skill.name}} "$skills_dir/${skill.name}/SKILL.md"
          chown openclaw:openclaw "$skills_dir/${skill.name}/SKILL.md"
          chmod 0660 "$skills_dir/${skill.name}/SKILL.md"
          printf '%s\n' \
            '#!/usr/bin/env bash' \
            'set -euo pipefail' \
            'exec ${skill.command} "$@"' \
            > "$skills_dir/${skill.name}/run.sh"
          chown openclaw:openclaw "$skills_dir/${skill.name}/run.sh"
          chmod 0750 "$skills_dir/${skill.name}/run.sh"
        '') skills}

        if [ -d "$custom_scripts_dir" ]; then
          rm -f "$scripts_dir"/*
          while IFS= read -r source_script; do
            script_name="$(basename "$source_script")"
            cp "$source_script" "$scripts_dir/$script_name"
            chown openclaw:openclaw "$scripts_dir/$script_name"
            chmod 0750 "$scripts_dir/$script_name"
          done < <(find "$custom_scripts_dir" -mindepth 1 -maxdepth 1 -type f)
        fi

        if [ -d "$custom_skills_dir" ]; then
          while IFS= read -r source_skill_dir; do
            skill_name="$(basename "$source_skill_dir")"
            rm -rf "$skills_dir/$skill_name"
            cp -r --no-preserve=mode "$source_skill_dir" "$skills_dir/$skill_name"
            chown -R openclaw:openclaw "$skills_dir/$skill_name"
            find "$skills_dir/$skill_name" -type d -exec chmod 2770 {} +
            find "$skills_dir/$skill_name" -type f -exec chmod 0660 {} +
            if [ -f "$skills_dir/$skill_name/run.sh" ]; then
              chmod 0750 "$skills_dir/$skill_name/run.sh"
            fi
          done < <(find "$custom_skills_dir" -mindepth 1 -maxdepth 1 -type d)
        fi

        if [ -e "$runtime_dir" ]; then
          chmod -R u+w "$runtime_dir" || true
        fi
        rm -rf "$runtime_dir"
        install -d -m 2770 -o ${cfg.operatorUser} -g openclaw "$dist_root"
        cp -r --no-preserve=mode "$package_root/dist/." "$dist_root/"
        ln -sfn "$package_root/node_modules" "$runtime_dir/node_modules"

        for plugin_dir in "$dist_dir"/*; do
          [ -d "$plugin_dir" ] || continue

          plugin_name="$(basename "$plugin_dir")"
          source_plugin_dir="$source_dir/$plugin_name"
          runtime_plugin_dir="$dist_dir/$plugin_name"
          manifest="$source_plugin_dir/openclaw.plugin.json"
          runtime_setup="$plugin_dir/setup-entry.js"

          [ -f "$manifest" ] || continue

          install -d -m 2770 -o ${cfg.operatorUser} -g openclaw "$runtime_plugin_dir"
          cp "$manifest" "$runtime_plugin_dir/openclaw.plugin.json"

          if [ -f "$runtime_setup" ]; then
            printf '%s\n' \
              '{' \
              "  \"name\": \"@openclaw/$plugin_name-runtime\"," \
              '  "private": true,' \
              '  "type": "module",' \
              '  "openclaw": {' \
              '    "extensions": ["./index.js"],' \
              '    "setupEntry": "./setup-entry.js"' \
              '  }' \
              '}' \
              > "$runtime_plugin_dir/package.json"
          else
            printf '%s\n' \
              '{' \
              "  \"name\": \"@openclaw/$plugin_name-runtime\"," \
              '  "private": true,' \
              '  "type": "module",' \
              '  "openclaw": {' \
              '    "extensions": ["./index.js"]' \
              '  }' \
              '}' \
              > "$runtime_plugin_dir/package.json"
          fi
        done

        find "$state_dir" \
          \( -path "$repo_mount_dir" -o -path "$repo_mount_dir/*" \) -prune \
          -o ! -type l -exec chgrp openclaw {} +
        find "$state_dir" \
          \( -path "$repo_mount_dir" -o -path "$repo_mount_dir/*" \) -prune \
          -o ! -type l -type d -exec chown ${cfg.operatorUser}:openclaw {} +
        find "$state_dir" \
          \( -path "$repo_mount_dir" -o -path "$repo_mount_dir/*" \) -prune \
          -o ! -type l -type d -exec chmod 2770 {} +
        find "$state_dir" \
          \( -path "$repo_mount_dir" -o -path "$repo_mount_dir/*" \) -prune \
          -o ! -type l -type f -exec chmod 0660 {} +
        chmod 0600 "$env_file" "$telegram_token_file"
        date +%s > "${syncStampPath}"
        chown ${cfg.operatorUser}:openclaw "${syncStampPath}"
        chmod 0660 "${syncStampPath}"
      '';
    };

    systemd.services.openclaw = {
      description = "OpenClaw gateway";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "openclaw-prepare.service" ];
      requires = [ "openclaw-prepare.service" ];
      serviceConfig = {
        User = "openclaw";
        Group = "openclaw";
        WorkingDirectory = stateDir;
        Environment = [
          "HOME=${stateDir}"
          "OPENCLAW_CONFIG_PATH=${openclawConfigPath}"
          "OPENCLAW_STATE_DIR=${stateDir}"
          "OPENCLAW_NIX_MODE=1"
          "OPENCLAW_BUNDLED_PLUGINS_DIR=${bundledPluginsRuntimeExtensionsDir}"
          "PATH=${openclawServicePath}:/run/current-system/sw/bin"
        ];
        EnvironmentFile = "-${stateDir}/openclaw.env";
        ExecStart =
          "${pkgs.openclaw-gateway}/bin/openclaw gateway --port 18789";
        Restart = "always";
        RestartSec = "1s";
        UMask = "0077";

        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectClock = true;
        ProtectHostname = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        RemoveIPC = true;
        CapabilityBoundingSet = [ "" ];
        AmbientCapabilities = [ "" ];
        BindReadOnlyPaths = [ "${repoDir}:${repoMountDir}" ];
        BindPaths = [ cfg.sharedDir ];
        RestrictAddressFamilies =
          [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
        ReadWritePaths = [ stateDir cfg.sharedDir ];
      };
    };

    environment.systemPackages = [ openclawSync openclawSyncStatus ];
  };
}
