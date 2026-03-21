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
        zsh
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
      cd "${backendRoot}"
      bundle install
      bin/rails db:create
      bin/rails db:prepare
    '
  '';

  frontendRoot = "${pulseRoot}/frontend";
  pnpmHome = "${homeDir}/.local/share/pnpm";
  pnpmStoreDir = "${pnpmHome}/store";
  xdgDataHome = "${homeDir}/.local/share";
  xdgCacheHome = "${homeDir}/.cache";

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
in {
  home-manager.users.bas.home.packages = [
    pulseEnsureInfra
    pulseBootstrap
    pulseFrontendBootstrap
    pulseFrontendShell
    pulseFrontendDev

    (pkgs.writeShellScriptBin "pulse-shell" ''
      set -euo pipefail
      ${pulseEnsureInfra}/bin/pulse-ensure-infra
      exec nix-shell "${pulseShellNix}" --command '${pkgs.zsh}/bin/zsh -i'
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
