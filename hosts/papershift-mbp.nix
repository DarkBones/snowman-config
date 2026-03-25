{ pkgs, config, lib, ... }:
let
  homeDir =
    config.home-manager.users.bas.home.homeDirectory or (if pkgs.stdenv.isDarwin then
      "/Users/bas"
    else
      "/home/bas");

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

  agentPython = pkgs.python3.withPackages (ps: [
    ps.fastapi
    ps.httpx
    ps.langchain
    ps.markdown2
    ps.openai
    ps."openai-agents"
    ps.pypdf2
    ps."python-docx"
    ps."python-dotenv"
    ps.uvicorn
    ps."weaviate-client"
    ps.debugpy
  ]);

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

    if ! ${pkgs.postgresql}/bin/pg_isready -h "${pgSocketDir}" -p "${
      toString pgPort
    }" >/dev/null 2>&1; then
      echo "[pulse] starting postgres"
      ${pkgs.postgresql}/bin/pg_ctl -D "${pgData}" stop -m fast >/dev/null 2>&1 || true
      rm -f "${pgSocketDir}/.s.PGSQL.${
        toString pgPort
      }" "${pgSocketDir}/.s.PGSQL.${toString pgPort}.lock"
      ${pkgs.postgresql}/bin/pg_ctl \
        -D "${pgData}" \
        -l "${pgLog}" \
        -o "-k ${pgSocketDir} -p ${toString pgPort}" \
        start >/dev/null
    fi

    if ! ${pkgs.redis}/bin/redis-cli -p ${
      toString redisPort
    } ping >/dev/null 2>&1; then
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

  pulseFrontendBootstrap =
    pkgs.writeShellScriptBin "pulse-frontend-bootstrap" ''
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
in {
  home-manager.users.bas.home.packages = [
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
  ] ++ lib.optionals pkgs.stdenv.isLinux [
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
  ];
}
