{ pkgs, config, ... }:
let
  homeDir =
    config.home-manager.users.bas.home.homeDirectory or (if pkgs.stdenv.isDarwin then
      "/Users/bas"
    else
      "/home/bas");

  root = "${homeDir}/Developer/papershift";
  pulseRoot = "${root}/pulse";
  backendRoot = "${pulseRoot}/backend";

  runtimeDir = "${homeDir}/.local/state/pulse";

  pgData = "${runtimeDir}/postgres";
  pgSocketDir = "${runtimeDir}/postgres-socket";
  pgLog = "${runtimeDir}/postgres.log";
  pgPort = 54329;

  redisDir = "${runtimeDir}/redis";
  redisLog = "${runtimeDir}/redis.log";
  redisPidFile = "${runtimeDir}/redis.pid";
  redisPort = 6381;

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
      ];

      shellHook = "
        export PULSE_ROOT='${pulseRoot}'
        export LANG='en_US.UTF-8'

        export PGDATA='${pgData}'
        export PGHOST='${pgSocketDir}'
        export PGPORT='${toString pgPort}'
        export PGUSER='bas'

        export REDIS_URL='redis://127.0.0.1:${toString redisPort}/0'

        mkdir -p '${pgSocketDir}' '${redisDir}'
        cd '${backendRoot}'

        echo 'Pulse shell ready at ${backendRoot}'
        echo \"ruby: $(command -v ruby)\"
        echo \"bundle: $(command -v bundle)\"
        echo \"node: $(command -v node)\"
        echo \"pnpm: $(command -v pnpm)\"
        echo \"pkg-config: $(command -v pkg-config)\"
        echo \"pg_config: $(command -v pg_config)\"
        echo \"PGHOST: $PGHOST\"
        echo \"PGPORT: $PGPORT\"
        echo \"REDIS_URL: $REDIS_URL\"
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

    # --- Postgres: initialize once ---
    if [ ! -f "${pgData}/PG_VERSION" ]; then
      echo "[pulse] initializing postgres cluster at ${pgData}"
      ${pkgs.postgresql}/bin/initdb -D "${pgData}" >/dev/null
    fi

    # --- Postgres: reuse if healthy, else restart ---
    if ${pkgs.postgresql}/bin/pg_isready -h "${pgSocketDir}" -p "${
      toString pgPort
    }" >/dev/null 2>&1; then
      echo "[pulse] postgres already running"
    else
      echo "[pulse] ensuring postgres is running"

      ${pkgs.postgresql}/bin/pg_ctl -D "${pgData}" stop -m fast >/dev/null 2>&1 || true
      rm -f "${pgSocketDir}/.s.PGSQL.${
        toString pgPort
      }" "${pgSocketDir}/.s.PGSQL.${toString pgPort}.lock"

      ${pkgs.postgresql}/bin/pg_ctl \
        -D "${pgData}" \
        -l "${pgLog}" \
        -o "-k ${pgSocketDir} -p ${toString pgPort}" \
        start >/dev/null

      ${pkgs.postgresql}/bin/pg_isready -h "${pgSocketDir}" -p "${
        toString pgPort
      }" >/dev/null
      echo "[pulse] postgres started"
    fi

    # --- Redis: reuse if healthy, else restart ---
    if ${pkgs.redis}/bin/redis-cli -p ${
      toString redisPort
    } ping >/dev/null 2>&1; then
      echo "[pulse] redis already running"
    else
      echo "[pulse] ensuring redis is running"

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

      ${pkgs.redis}/bin/redis-cli -p ${toString redisPort} ping >/dev/null
      echo "[pulse] redis started"
    fi
  '';

  pulseBootstrap = pkgs.writeShellScriptBin "pulse-bootstrap" ''
    set -euo pipefail
    ${pulseEnsureInfra}/bin/pulse-ensure-infra
    exec nix-shell "${pulseShellNix}" --command '
      cd "${backendRoot}"
      bundle install
      bin/rails db:create
      bin/rails db:prepare
    '
  '';
in {
  home-manager.users.bas.home.packages = [
    pulseEnsureInfra
    pulseBootstrap

    (pkgs.writeShellScriptBin "pulse-shell" ''
      set -euo pipefail
      ${pulseEnsureInfra}/bin/pulse-ensure-infra
      exec nix-shell "${pulseShellNix}" --command '${pkgs.bashInteractive}/bin/bash -i'
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
  ];
}
