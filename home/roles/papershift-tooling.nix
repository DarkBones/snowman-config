{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.roles.papershift;

  homeDir = config.home.homeDirectory;
  coreEnabled = !pkgs.stdenv.isDarwin;

  root = "${homeDir}/Developer/papershift";
  pulseRoot = "${root}/pulse";
  backendRoot = "${pulseRoot}/backend";
  frontendRoot = "${pulseRoot}/frontend";
  agentRoot = "${pulseRoot}/agent";

  runtimeDir = "${homeDir}/.local/state/pulse";

  pgData = "${runtimeDir}/postgres";
  pgSocketDir = "${runtimeDir}/postgres-socket";
  pgLog = "${runtimeDir}/postgres.log";
  pgPort = 54329;

  redisDir = "${runtimeDir}/redis";
  redisLog = "${runtimeDir}/redis.log";
  redisPidFile = "${runtimeDir}/redis.pid";
  redisPort = 6381;

  pnpmHome = "${homeDir}/.local/share/pnpm";
  pnpmStoreDir = "${pnpmHome}/store";
  xdgDataHome = "${homeDir}/.local/share";
  xdgCacheHome = "${homeDir}/.cache";

  pulseEnv = pkgs.writeText "pulse-env.sh" ''
    if [ -f "${pulseRoot}/.env" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          ""|\#*) continue
        esac

        key=''${line%%=*}
        value=''${line#*=}
        key="$(${pkgs.coreutils}/bin/printf '%s' "$key" | ${pkgs.coreutils}/bin/tr -d '[:space:]')"
        value="$(${pkgs.coreutils}/bin/printf '%s' "$value" | ${pkgs.gnused}/bin/sed 's/^[[:space:]]*//')"
        value="$(${pkgs.coreutils}/bin/printf '%s' "$value" | ${pkgs.gnused}/bin/sed -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//')"

        if [ -n "$key" ]; then
          export "$key=$value"
        fi
      done < "${pulseRoot}/.env"
    fi

    export PULSE_ROOT="${pulseRoot}"
    export LANG="en_US.UTF-8"

    export PGDATA="${pgData}"
    export PGHOST="${pgSocketDir}"
    export PGPORT="${toString pgPort}"
    export PGUSER="bas"

    export POSTGRES_HOST="${pgSocketDir}"
    export POSTGRES_PORT="${toString pgPort}"
    export POSTGRES_USER="bas"

    export REDIS_URL="redis://127.0.0.1:${toString redisPort}/0"

    export API_URL="http://127.0.0.1:3000"
    export AGENT_URL="http://127.0.0.1:8001"
    export CHROME_HOST="127.0.0.1"
    export ANYCABLE_RPC_HOST="127.0.0.1:50051"

    export VITE_API_URL="http://127.0.0.1:3000"
    export VITE_CABLE_URL="ws://127.0.0.1:8080/cable"
  '';

  agentPython = pkgs.python3.withPackages (
    ps:
    [
      ps.fastapi
      ps.httpx
      ps.langchain
      ps.markdown2
      ps.openai
      ps."openai-agents"
      ps.pypdf
      ps."python-docx"
      ps."python-dotenv"
      ps.uvicorn
      ps.debugpy
    ]
    ++ lib.optionals (!pkgs.stdenv.isDarwin) [ ps."weaviate-client" ]
  );

  pulseShellNix = pkgs.writeText "pulse-shell.nix" ''
    { pkgs ? import ${pkgs.path} {
        system = "${pkgs.stdenv.hostPlatform.system}";
        config.allowUnfree = true;
      }
    }:

    pkgs.mkShell {
      nativeBuildInputs = with pkgs; [
        pkg-config
      ];

      buildInputs = with pkgs; [
        libyaml
        openssl
        postgresql
        vips
        zlib
        libffi
      ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
        gcc
      ];

      packages = with pkgs; [
        ruby_3_4
        nodejs_22
        pnpm
        redis
        gnumake
        git
        zsh
      ];

      shellHook = "
        . '${pulseEnv}'
        mkdir -p '${pgSocketDir}' '${redisDir}'
        cd '${backendRoot}'
      ";
    }
  '';

  pulseEnsureInfra = pkgs.writeShellScriptBin "pulse-ensure-infra" ''
    set -euo pipefail

    export PGDATA="${pgData}"
    export PGHOST="${pgSocketDir}"
    export PGPORT="${toString pgPort}"
    export PGUSER="bas"

    mkdir -p "${runtimeDir}" "${pgSocketDir}" "${redisDir}"

    if [ ! -f "${pgData}/PG_VERSION" ]; then
      echo "[pulse] initializing postgres"
      ${pkgs.postgresql}/bin/initdb -D "${pgData}" >/dev/null
    fi

    if ! ${pkgs.postgresql}/bin/pg_isready -h "${pgSocketDir}" -p "${toString pgPort}" >/dev/null 2>&1; then
      echo "[pulse] starting postgres"
      ${pkgs.postgresql}/bin/pg_ctl -D "${pgData}" stop -m fast >/dev/null 2>&1 || true
      rm -f "${pgSocketDir}/.s.PGSQL.${toString pgPort}" "${pgSocketDir}/.s.PGSQL.${toString pgPort}.lock"
      ${pkgs.postgresql}/bin/pg_ctl \
        -D "${pgData}" \
        -l "${pgLog}" \
        -o "-k ${pgSocketDir} -p ${toString pgPort} -c listen_addresses=" \
        start >/dev/null
    fi

    if ! ${pkgs.redis}/bin/redis-cli -p ${toString redisPort} ping >/dev/null 2>&1; then
      echo "[pulse] starting redis"
      if [ -f "${redisPidFile}" ]; then
        kill "$(cat "${redisPidFile}")" >/dev/null 2>&1 || true
        rm -f "${redisPidFile}"
      fi

      ${pkgs.redis}/bin/redis-server \
        --daemonize yes \
        --port ${toString redisPort} \
        --dir "${redisDir}" \
        --pidfile "${redisPidFile}" \
        --logfile "${redisLog}"
    fi
  '';

  pulseBootstrap = pkgs.writeShellScriptBin "pulse-bootstrap" ''
    set -euo pipefail
    ${pulseEnsureInfra}/bin/pulse-ensure-infra
    exec nix-shell "${pulseShellNix}" --command '
      . "${pulseEnv}"
      cd "${backendRoot}"
      bundle install
      bin/rails db:create
      bin/rails db:prepare
    '
  '';

  frontendShellNix = pkgs.writeText "pulse-frontend-shell.nix" ''
    { pkgs ? import ${pkgs.path} {
        system = "${pkgs.stdenv.hostPlatform.system}";
        config.allowUnfree = true;
      }
    }:

    pkgs.mkShell {
      packages = with pkgs; [
        nodejs_22
        pnpm
        git
        zsh
      ];

      shellHook = "
        export PULSE_ROOT='${pulseRoot}'
        export LANG='en_US.UTF-8'
        cd '${frontendRoot}'
      ";
    }
  '';

  pulseFrontendBootstrap = pkgs.writeShellScriptBin "pulse-frontend-bootstrap" ''
    set -euo pipefail
    mkdir -p "${xdgDataHome}" "${xdgCacheHome}" "${pnpmHome}" "${pnpmStoreDir}"
    exec nix-shell "${frontendShellNix}" --command '
      cd "${frontendRoot}"
      exec env \
        -u PNPM_HOME \
        XDG_DATA_HOME="${xdgDataHome}" \
        XDG_CACHE_HOME="${xdgCacheHome}" \
        PNPM_HOME="${pnpmHome}" \
        PNPM_STORE_DIR="${pnpmStoreDir}" \
        NPM_CONFIG_USERCONFIG=/dev/null \
        pnpm install
    '
  '';

  pulseFrontendShell = pkgs.writeShellScriptBin "pulse-frontend-shell" ''
    set -euo pipefail
    mkdir -p "${xdgDataHome}" "${xdgCacheHome}" "${pnpmHome}" "${pnpmStoreDir}"
    exec nix-shell "${frontendShellNix}" --command '
      cd "${frontendRoot}"
      exec env \
        -u PNPM_HOME \
        XDG_DATA_HOME="${xdgDataHome}" \
        XDG_CACHE_HOME="${xdgCacheHome}" \
        PNPM_HOME="${pnpmHome}" \
        PNPM_STORE_DIR="${pnpmStoreDir}" \
        NPM_CONFIG_USERCONFIG=/dev/null \
        ${pkgs.zsh}/bin/zsh -i
    '
  '';

  pulseFrontendDev = pkgs.writeShellScriptBin "pulse-frontend-dev" ''
    set -euo pipefail
    mkdir -p "${xdgDataHome}" "${xdgCacheHome}" "${pnpmHome}" "${pnpmStoreDir}"
    exec nix-shell "${frontendShellNix}" --command '
      cd "${frontendRoot}"
      exec env \
        -u PNPM_HOME \
        XDG_DATA_HOME="${xdgDataHome}" \
        XDG_CACHE_HOME="${xdgCacheHome}" \
        PNPM_HOME="${pnpmHome}" \
        PNPM_STORE_DIR="${pnpmStoreDir}" \
        NPM_CONFIG_USERCONFIG=/dev/null \
        pnpm dev
    '
  '';

  pulseBackendDev = pkgs.writeShellScriptBin "pulse-backend-dev" ''
    set -euo pipefail
    ${pulseEnsureInfra}/bin/pulse-ensure-infra
    exec nix-shell "${pulseShellNix}" --command '
      . "${pulseEnv}"
      cd "${backendRoot}"
      bin/rails s
    '
  '';

  pulseApiDev = pkgs.writeShellScriptBin "pulse-api-dev" ''
    set -euo pipefail
    ${pulseEnsureInfra}/bin/pulse-ensure-infra
    exec nix-shell "${pulseShellNix}" --command '
      . "${pulseEnv}"
      cd "${backendRoot}"
      ./lib/scripts/entrypoint.sh
      exec bin/web
    '
  '';

  pulseAnycableDev = pkgs.writeShellScriptBin "pulse-anycable-dev" ''
    set -euo pipefail
    ${pulseEnsureInfra}/bin/pulse-ensure-infra
    exec nix-shell "${pulseShellNix}" --command '
      . "${pulseEnv}"
      export ANYCABLE_RPC_HOST="0.0.0.0:50051"
      cd "${backendRoot}"
      exec bin/anycable
    '
  '';

  pulseSidekiqDev = pkgs.writeShellScriptBin "pulse-sidekiq-dev" ''
    set -euo pipefail
    ${pulseEnsureInfra}/bin/pulse-ensure-infra
    exec nix-shell "${pulseShellNix}" --command '
      . "${pulseEnv}"
      cd "${backendRoot}"
      exec bin/worker
    '
  '';

  pulseAgentDev = pkgs.writeShellScriptBin "pulse-agent-dev" ''
    set -euo pipefail
    . "${pulseEnv}"
    cd "${agentRoot}"
    exec ${agentPython}/bin/uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
  '';

  pulseWsDev = pkgs.writeShellScriptBin "pulse-ws-dev" ''
    set -euo pipefail
    . "${pulseEnv}"

    if ! command -v anycable-go >/dev/null 2>&1; then
      echo "[pulse] anycable-go is not installed; skipping websocket server" >&2
      echo "[pulse] install an anycable-go binary on PATH to enable ws://localhost:8080/cable" >&2
      exit 1
    fi

    exec anycable-go \
      --host 0.0.0.0 \
      --port 8080 \
      --path /cable \
      --redis_url "$REDIS_URL" \
      --rpc_host 127.0.0.1:50051
  '';

  core = lib.optionalAttrs coreEnabled (
    let
      corePkgs = import inputs.nixpkgs-23_11 {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "ruby-2.7.8"
          "openssl-1.1.1w"
        ];
      };

      coreRoot = "${root}/shift_app";
      coreRuntimeDir = "${homeDir}/.local/state/core";

      corePgData = "${coreRuntimeDir}/postgres";
      corePgSocketDir = "${coreRuntimeDir}/postgres-socket";
      corePgLog = "${coreRuntimeDir}/postgres.log";
      corePgPort = 54329;

      coreRedisDir = "${coreRuntimeDir}/redis";
      coreRedisLog = "${coreRuntimeDir}/redis.log";
      coreRedisPidFile = "${coreRuntimeDir}/redis.pid";
      coreRedisPort = 6381;

      coreEnv = pkgs.writeText "core-env.sh" ''
        export SHIFT_APP_ROOT="${coreRoot}"
        export LANG="en_US.UTF-8"

        export PGDATA="${corePgData}"
        export PGHOST="${corePgSocketDir}"
        export PGPORT="${toString corePgPort}"
        export PGUSER="bas"
        export PGPASS=""

        export POSTGRESQL_DATABASE="shift_app_development"
        export POSTGRESQL_USERNAME="bas"
        export POSTGRESQL_PASSWORD=""
        export POSTGRESQL_HOST="${corePgSocketDir}"
        export POSTGRESQL_PORT="${toString corePgPort}"
        export POSTGRESQL_POOL="5"

        export REDISCLOUD_URL="redis://127.0.0.1:${toString coreRedisPort}/0"

        export RAILS_ENV="development"
        export PORT="3000"
        export HOST="localhost:3000"
        export SIDEKIQ_CONCURRENCY="5"
        export ASSIGNMENTS_SIDEKIQ_CONCURRENCY="1"
        export SIDEKIQ_USERNAME="sidekiq"
        export SIDEKIQ_PASSWORD="sidekiq"
        export ENABLE_BULLET="false"
        export FREEDESKTOP_MIME_TYPES_PATH="${corePkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml"
        export STATION_APP_PUSHER_ID="local-station"
        export STATION_APP_PUSHER_SECRET="local-station-secret"
        export PLAN_APP_PUSHER_ID="local-plan"
        export PLAN_APP_PUSHER_SECRET="local-plan-secret"
        export SEGMENT_API_KEY="local-segment-key"

        if [ -n "''${RAILSLTS_KEY_DEV:-}" ] && [ -z "''${BUNDLE_GEMS__RAILSLTS__COM:-}" ]; then
          export BUNDLE_GEMS__RAILSLTS__COM="$RAILSLTS_KEY_DEV"
        fi
      '';

      coreShellNix = pkgs.writeText "core-shell.nix" ''
        { pkgs ? import ${corePkgs.path} {
            system = "${corePkgs.stdenv.hostPlatform.system}";
            config.allowUnfree = true;
            config.permittedInsecurePackages = [
              "ruby-2.7.8"
              "openssl-1.1.1w"
            ];
          }
        }:

        pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            pkg-config
          ];

          buildInputs = with pkgs; [
            imagemagick
            libffi
            libxml2
            libxslt
            libyaml
            openssl
            postgresql
            shared-mime-info
            zlib
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            gcc
          ];

          packages = with pkgs; [
            ruby_2_7
            nodejs
            redis
            gnumake
            git
            zsh
          ];

          shellHook = "
            . '${coreEnv}'
            mkdir -p '${corePgSocketDir}' '${coreRedisDir}'
            cd '${coreRoot}'
          ";
        }
      '';

      coreEnsureInfra = pkgs.writeShellScriptBin "core-ensure-infra" ''
        set -euo pipefail

        export PGDATA="${corePgData}"
        export PGHOST="${corePgSocketDir}"
        export PGPORT="${toString corePgPort}"
        export PGUSER="bas"

        mkdir -p "${coreRuntimeDir}" "${corePgSocketDir}" "${coreRedisDir}"

        if [ ! -f "${corePgData}/PG_VERSION" ]; then
          echo "[core] initializing postgres"
          ${pkgs.postgresql}/bin/initdb -D "${corePgData}" >/dev/null
        fi

        if ! ${pkgs.postgresql}/bin/pg_isready -h "${corePgSocketDir}" -p "${toString corePgPort}" >/dev/null 2>&1; then
          echo "[core] starting postgres"
          ${pkgs.postgresql}/bin/pg_ctl -D "${corePgData}" stop -m fast >/dev/null 2>&1 || true
          rm -f "${corePgSocketDir}/.s.PGSQL.${toString corePgPort}" "${corePgSocketDir}/.s.PGSQL.${toString corePgPort}.lock"
          ${pkgs.postgresql}/bin/pg_ctl \
            -D "${corePgData}" \
            -l "${corePgLog}" \
            -o "-k ${corePgSocketDir} -p ${toString corePgPort} -c listen_addresses=" \
            start >/dev/null
        fi

        if ! ${pkgs.redis}/bin/redis-cli -p ${toString coreRedisPort} ping >/dev/null 2>&1; then
          echo "[core] starting redis"
          if [ -f "${coreRedisPidFile}" ]; then
            kill "$(cat "${coreRedisPidFile}")" >/dev/null 2>&1 || true
            rm -f "${coreRedisPidFile}"
          fi

          ${pkgs.redis}/bin/redis-server \
            --daemonize yes \
            --port ${toString coreRedisPort} \
            --dir "${coreRedisDir}" \
            --pidfile "${coreRedisPidFile}" \
            --logfile "${coreRedisLog}"
        fi
      '';

      coreBootstrap = pkgs.writeShellScriptBin "core-bootstrap" ''
        set -euo pipefail
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix-shell "${coreShellNix}" --command '
          . "${coreEnv}"
          export STATION_APP_PUSHER_ID="''${STATION_APP_PUSHER_ID:-local-station}"
          export STATION_APP_PUSHER_SECRET="''${STATION_APP_PUSHER_SECRET:-local-station-secret}"
          export PLAN_APP_PUSHER_ID="''${PLAN_APP_PUSHER_ID:-local-plan}"
          export PLAN_APP_PUSHER_SECRET="''${PLAN_APP_PUSHER_SECRET:-local-plan-secret}"
          export SEGMENT_API_KEY="''${SEGMENT_API_KEY:-local-segment-key}"
          cd "${coreRoot}"

          if [ -z "''${BUNDLE_GEMS__RAILSLTS__COM:-}" ]; then
            echo "[core] missing RailsLTS auth. Export RAILSLTS_KEY_DEV or BUNDLE_GEMS__RAILSLTS__COM first." >&2
            exit 1
          fi

          bundle config set gems.railslts.com "$BUNDLE_GEMS__RAILSLTS__COM"
          bundle install
          bundle exec rails db:create
          bundle exec rails db:migrate
        '
      '';

      coreWebDev = pkgs.writeShellScriptBin "core-web-dev" ''
        set -euo pipefail
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix-shell "${coreShellNix}" --command '
          . "${coreEnv}"
          export STATION_APP_PUSHER_ID="''${STATION_APP_PUSHER_ID:-local-station}"
          export STATION_APP_PUSHER_SECRET="''${STATION_APP_PUSHER_SECRET:-local-station-secret}"
          export PLAN_APP_PUSHER_ID="''${PLAN_APP_PUSHER_ID:-local-plan}"
          export PLAN_APP_PUSHER_SECRET="''${PLAN_APP_PUSHER_SECRET:-local-plan-secret}"
          export SEGMENT_API_KEY="''${SEGMENT_API_KEY:-local-segment-key}"
          cd "${coreRoot}"
          exec bundle exec rails server -b 0.0.0.0 -p "$PORT"
        '
      '';

      coreSidekiqDev = pkgs.writeShellScriptBin "core-sidekiq-dev" ''
        set -euo pipefail
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix-shell "${coreShellNix}" --command '
          . "${coreEnv}"
          export STATION_APP_PUSHER_ID="''${STATION_APP_PUSHER_ID:-local-station}"
          export STATION_APP_PUSHER_SECRET="''${STATION_APP_PUSHER_SECRET:-local-station-secret}"
          export PLAN_APP_PUSHER_ID="''${PLAN_APP_PUSHER_ID:-local-plan}"
          export PLAN_APP_PUSHER_SECRET="''${PLAN_APP_PUSHER_SECRET:-local-plan-secret}"
          export SEGMENT_API_KEY="''${SEGMENT_API_KEY:-local-segment-key}"
          cd "${coreRoot}"
          exec bundle exec sidekiq -C config/sidekiq_all.yml
        '
      '';

      coreSidekiqAssignmentsDev = pkgs.writeShellScriptBin "core-sidekiq-assignments-dev" ''
        set -euo pipefail
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix-shell "${coreShellNix}" --command '
          . "${coreEnv}"
          export STATION_APP_PUSHER_ID="''${STATION_APP_PUSHER_ID:-local-station}"
          export STATION_APP_PUSHER_SECRET="''${STATION_APP_PUSHER_SECRET:-local-station-secret}"
          export PLAN_APP_PUSHER_ID="''${PLAN_APP_PUSHER_ID:-local-plan}"
          export PLAN_APP_PUSHER_SECRET="''${PLAN_APP_PUSHER_SECRET:-local-plan-secret}"
          export SEGMENT_API_KEY="''${SEGMENT_API_KEY:-local-segment-key}"
          cd "${coreRoot}"
          exec bundle exec sidekiq -C config/sidekiq_assignments.yml
        '
      '';

      coreShell = pkgs.writeShellScriptBin "core-shell" ''
        set -euo pipefail
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix-shell "${coreShellNix}" --command '. "${coreEnv}"; ${pkgs.zsh}/bin/zsh -i'
      '';

      coreRubocopFormat = pkgs.writeShellScriptBin "core-rubocop-format" ''
        set -euo pipefail

        if [ "$#" -ne 1 ]; then
          echo "usage: core-rubocop-format <project-relative-file>" >&2
          exit 2
        fi

        relpath="$1"
        tmpfile="$(mktemp)"
        trap 'rm -f "$tmpfile"' EXIT
        cat > "$tmpfile"

        exec nix-shell "${coreShellNix}" --command "
          . '${coreEnv}'
          cd '${coreRoot}'
          bundle exec rubocop -a \
            --except Style/NegatedIf,Style/IfUnlessModifier,Style/GuardClause \
            -f quiet --stderr --stdin '$relpath' < '$tmpfile'
        "
      '';

      corePgStop = pkgs.writeShellScriptBin "core-pg-stop" ''
        ${pkgs.postgresql}/bin/pg_ctl -D "${corePgData}" stop -m fast || true
      '';

      coreRedisStop = pkgs.writeShellScriptBin "core-redis-stop" ''
        if [ -f "${coreRedisPidFile}" ]; then
          kill "$(cat "${coreRedisPidFile}")" || true
          rm -f "${coreRedisPidFile}"
        fi
      '';

      coreDev = pkgs.writeShellScriptBin "core-dev" ''
        set -euo pipefail

        config_file="$(mktemp)"
        trap 'rm -f "$config_file"' EXIT

        ${pkgs.coreutils}/bin/cat > "$config_file" <<EOF
        version: "0.5"
        processes:
          web:
            command: core-web-dev
          sidekiq:
            command: core-sidekiq-dev
          sidekiq_assignments:
            command: core-sidekiq-assignments-dev
        EOF

        exec ${pkgs.process-compose}/bin/process-compose -f "$config_file" up
      '';
    in
    {
      inherit
        coreBootstrap
        coreDev
        coreEnsureInfra
        corePgStop
        coreRedisStop
        coreRubocopFormat
        coreShell
        coreSidekiqAssignmentsDev
        coreSidekiqDev
        coreWebDev
        ;
    }
  );
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.postgresql
      pulseEnsureInfra
      pulseBootstrap
      pulseFrontendBootstrap
      pulseFrontendShell
      pulseFrontendDev
      pulseBackendDev
      pulseApiDev
      pulseAnycableDev
      pulseSidekiqDev
      pulseAgentDev
      pulseWsDev

      (pkgs.writeShellScriptBin "pulse-shell" ''
        set -euo pipefail
        ${pulseEnsureInfra}/bin/pulse-ensure-infra
        exec nix-shell "${pulseShellNix}" --command '. "${pulseEnv}"; ${pkgs.zsh}/bin/zsh -i'
      '')

      (pkgs.writeShellScriptBin "pulse-pg-stop" ''
        ${pkgs.postgresql}/bin/pg_ctl -D "${pgData}" stop -m fast || true
      '')

      (pkgs.writeShellScriptBin "pulse-redis-stop" ''
        if [ -f "${redisPidFile}" ]; then
          kill "$(cat "${redisPidFile}")" || true
          rm -f "${redisPidFile}"
        fi
      '')
    ]
    ++ lib.optionals coreEnabled [
      core.coreEnsureInfra
      core.coreBootstrap
      core.coreWebDev
      core.coreSidekiqDev
      core.coreSidekiqAssignmentsDev
      core.coreShell
      core.coreRubocopFormat
      core.corePgStop
      core.coreRedisStop
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      (pkgs.writeShellScriptBin "pulse-chrome-dev" ''
        set -euo pipefail
        mkdir -p "${runtimeDir}/chrome"
        exec ${pkgs.chromium}/bin/chromium \
          --headless \
          --disable-gpu \
          --no-first-run \
          --remote-debugging-address=0.0.0.0 \
          --remote-debugging-port=9222 \
          --user-data-dir="${runtimeDir}/chrome"
      '')

      (pkgs.writeShellScriptBin "pulse-dev" ''
        set -euo pipefail

        config_file="$(mktemp)"
        trap 'rm -f "$config_file"' EXIT

        ws_process=""
        if command -v anycable-go >/dev/null 2>&1; then
          ws_process=$'  ws:\n    command: pulse-ws-dev\n'
        else
          echo "[pulse] anycable-go is not installed; starting without websocket server" >&2
        fi

        ${pkgs.coreutils}/bin/cat > "$config_file" <<EOF
        version: "0.5"
        processes:
          frontend:
            command: pulse-frontend-dev
          api:
            command: pulse-api-dev
          agent:
            command: pulse-agent-dev
          chrome:
            command: pulse-chrome-dev
          sidekiq:
            command: pulse-sidekiq-dev
          anycable:
            command: pulse-anycable-dev
        $ws_process
        EOF

        exec ${pkgs.process-compose}/bin/process-compose -f "$config_file" up
      '')

      core.coreDev
    ];
  };
}
