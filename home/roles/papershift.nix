{ lib, config, pkgs, ... }:
let
  cfg = config.roles.papershift;
  homeDir = config.home.homeDirectory;

  # Reference to snowman-config flake for devShells
  configFlake = "${homeDir}/snowman-config";

  # Runtime directories
  pulseRuntimeDir = "${homeDir}/.local/state/pulse";
  coreRuntimeDir = "${homeDir}/.local/state/core";

  # Helper to create scripts
  mkScript = name: script: pkgs.writeShellScriptBin name ''
    set -euo pipefail
    ${script}
  '';

  # Infrastructure management for Pulse
  pulseEnsureInfra = mkScript "pulse-ensure-infra" ''
    mkdir -p "${pulseRuntimeDir}/postgres-socket" "${pulseRuntimeDir}/redis"

    if [ ! -f "${pulseRuntimeDir}/postgres/PG_VERSION" ]; then
      echo "[pulse] initializing postgres"
      ${pkgs.postgresql}/bin/initdb -D "${pulseRuntimeDir}/postgres" >/dev/null
    fi

    if ! ${pkgs.postgresql}/bin/pg_isready -h "${pulseRuntimeDir}/postgres-socket" -p 54329 >/dev/null 2>&1; then
      echo "[pulse] starting postgres"
      ${pkgs.postgresql}/bin/pg_ctl -D "${pulseRuntimeDir}/postgres" stop -m fast >/dev/null 2>&1 || true
      rm -f "${pulseRuntimeDir}/postgres-socket/.s.PGSQL.54329" "${pulseRuntimeDir}/postgres-socket/.s.PGSQL.54329.lock"
      ${pkgs.postgresql}/bin/pg_ctl -D "${pulseRuntimeDir}/postgres" \
        -l "${pulseRuntimeDir}/postgres.log" \
        -o "-k ${pulseRuntimeDir}/postgres-socket -p 54329 -c listen_addresses=" \
        start >/dev/null
    fi

    if ! ${pkgs.redis}/bin/redis-cli -p 6381 ping >/dev/null 2>&1; then
      echo "[pulse] starting redis"
      if [ -f "${pulseRuntimeDir}/redis.pid" ]; then
        kill "$(cat "${pulseRuntimeDir}/redis.pid")" >/dev/null 2>&1 || true
        rm -f "${pulseRuntimeDir}/redis.pid"
      fi

      ${pkgs.redis}/bin/redis-server \
        --daemonize yes \
        --port 6381 \
        --dir "${pulseRuntimeDir}/redis" \
        --pidfile "${pulseRuntimeDir}/redis.pid" \
        --logfile "${pulseRuntimeDir}/redis.log"
    fi
  '';

  # Infrastructure management for Core (Linux only)
  coreEnsureInfra = mkScript "core-ensure-infra" ''
    mkdir -p "${coreRuntimeDir}/postgres-socket" "${coreRuntimeDir}/redis"

    if [ ! -f "${coreRuntimeDir}/postgres/PG_VERSION" ]; then
      echo "[core] initializing postgres"
      ${pkgs.postgresql}/bin/initdb -D "${coreRuntimeDir}/postgres" >/dev/null
    fi

    if ! ${pkgs.postgresql}/bin/pg_isready -h "${coreRuntimeDir}/postgres-socket" -p 54329 >/dev/null 2>&1; then
      echo "[core] starting postgres"
      ${pkgs.postgresql}/bin/pg_ctl -D "${coreRuntimeDir}/postgres" stop -m fast >/dev/null 2>&1 || true
      rm -f "${coreRuntimeDir}/postgres-socket/.s.PGSQL.54329" "${coreRuntimeDir}/postgres-socket/.s.PGSQL.54329.lock"
      ${pkgs.postgresql}/bin/pg_ctl -D "${coreRuntimeDir}/postgres" \
        -l "${coreRuntimeDir}/postgres.log" \
        -o "-k ${coreRuntimeDir}/postgres-socket -p 54329 -c listen_addresses=" \
        start >/dev/null
    fi

    if ! ${pkgs.redis}/bin/redis-cli -p 6381 ping >/dev/null 2>&1; then
      echo "[core] starting redis"
      if [ -f "${coreRuntimeDir}/redis.pid" ]; then
        kill "$(cat "${coreRuntimeDir}/redis.pid")" >/dev/null 2>&1 || true
        rm -f "${coreRuntimeDir}/redis.pid"
      fi

      ${pkgs.redis}/bin/redis-server \
        --daemonize yes \
        --port 6381 \
        --dir "${coreRuntimeDir}/redis" \
        --pidfile "${coreRuntimeDir}/redis.pid" \
        --logfile "${coreRuntimeDir}/redis.log"
    fi
  '';

  # Thin wrapper: runs command in devShell from snowman-config flake
  # Note: We need to re-source environment in the command because shellHook
  # environment isn't always preserved with -c
  mkDevCmd = name: shell: cmd: ensureInfra:
    mkScript name ''
      ${lib.optionalString ensureInfra "${pulseEnsureInfra}/bin/pulse-ensure-infra"}
      exec nix develop "${configFlake}#${shell}" -c bash -c '
        # Re-export critical environment variables
        export PGHOST="$HOME/.local/state/pulse/postgres-socket"
        export PGPORT="54329"
        export PGUSER="$(whoami)"
        export POSTGRES_HOST="$HOME/.local/state/pulse/postgres-socket"
        export POSTGRES_PORT="54329"
        export POSTGRES_USER="$(whoami)"
        export REDIS_URL="redis://127.0.0.1:6381/0"

        # Load .env if present
        if [ -f "$HOME/Developer/papershift/pulse/.env" ]; then
          set -a
          source "$HOME/Developer/papershift/pulse/.env"
          set +a
        fi

        cd "$HOME/Developer/papershift/pulse/backend"
        exec ${cmd}
      '
    '';

in {
  options.roles.papershift.enable = lib.mkEnableOption "Papershift role";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      # Editor tooling and language servers
      ruby_3_4
      solargraph
      rubocop
      typescript
      typescript-language-server
      vue-language-server
      astro-language-server
      eslint
      prettier
      prettierd

      # Infrastructure (always available)
      postgresql
      redis

      # Infrastructure management helpers
      pulseEnsureInfra

      # Pulse backend commands (thin wrappers to devShells)
      (mkScript "pulse-shell" ''
        ${pulseEnsureInfra}/bin/pulse-ensure-infra
        exec nix develop "${configFlake}#pulse-backend" -c bash -c '
          export PGHOST="$HOME/.local/state/pulse/postgres-socket"
          export PGPORT="54329"
          export PGUSER="$(whoami)"
          export POSTGRES_HOST="$HOME/.local/state/pulse/postgres-socket"
          export POSTGRES_PORT="54329"
          export POSTGRES_USER="$(whoami)"
          export REDIS_URL="redis://127.0.0.1:6381/0"

          # Load .env if present
          if [ -f "$HOME/Developer/papershift/pulse/.env" ]; then
            set -a
            source "$HOME/Developer/papershift/pulse/.env"
            set +a
          fi

          cd "$HOME/Developer/papershift/pulse/backend"
          exec ${pkgs.zsh}/bin/zsh -i
        '
      '')
      (mkDevCmd "pulse-backend-dev" "pulse-backend" "bin/rails s" true)
      (mkDevCmd "pulse-api-dev" "pulse-backend"
        "./lib/scripts/entrypoint.sh && exec bin/web" true)
      (mkDevCmd "pulse-anycable-dev" "pulse-backend"
        "export ANYCABLE_RPC_HOST=0.0.0.0:50051 && exec bin/anycable" true)
      (mkDevCmd "pulse-sidekiq-dev" "pulse-backend" "bin/worker" true)
      (mkDevCmd "pulse-bootstrap" "pulse-backend" ''
        bundle config set build.ds9 --use-system-libraries
        bundle install
        bin/rails db:create
        bin/rails db:prepare
      '' true)

      # Pulse frontend commands
      (mkScript "pulse-frontend-shell" ''
        exec nix develop "${configFlake}#pulse-frontend" -c bash -c '
          cd "$HOME/Developer/papershift/pulse/frontend"
          exec ${pkgs.zsh}/bin/zsh -i
        '
      '')
      (mkScript "pulse-frontend-dev" ''
        exec nix develop "${configFlake}#pulse-frontend" -c bash -c '
          cd "$HOME/Developer/papershift/pulse/frontend"
          exec pnpm dev
        '
      '')
      (mkScript "pulse-frontend-bootstrap" ''
        mkdir -p "$HOME/.local/share/pnpm" "$HOME/.cache"
        exec nix develop "${configFlake}#pulse-frontend" -c bash -c '
          export XDG_DATA_HOME="$HOME/.local/share"
          export XDG_CACHE_HOME="$HOME/.cache"
          export PNPM_HOME="$HOME/.local/share/pnpm"
          export PNPM_STORE_DIR="$HOME/.local/share/pnpm/store"
          cd "$HOME/Developer/papershift/pulse/frontend"
          exec env NPM_CONFIG_USERCONFIG=/dev/null pnpm install
        '
      '')

      # Pulse agent commands
      (mkScript "pulse-agent-dev" ''
        exec nix develop "${configFlake}#pulse-agent" -c bash -c '
          # Load .env if present
          if [ -f "$HOME/Developer/papershift/pulse/.env" ]; then
            set -a
            source "$HOME/Developer/papershift/pulse/.env"
            set +a
          fi
          cd "$HOME/Developer/papershift/pulse/agent"
          exec uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
        '
      '')

      # WebSocket server (requires anycable-go binary on PATH)
      (mkScript "pulse-ws-dev" ''
        . "${pulseEnsureInfra}/bin/pulse-ensure-infra"

        if ! command -v anycable-go >/dev/null 2>&1; then
          echo "[pulse] anycable-go is not installed; skipping websocket server" >&2
          echo "[pulse] install an anycable-go binary on PATH to enable ws://localhost:8080/cable" >&2
          exit 1
        fi

        exec anycable-go \
          --host 0.0.0.0 \
          --port 8080 \
          --path /cable \
          --redis_url "redis://127.0.0.1:6381/0" \
          --rpc_host 127.0.0.1:50051
      '')

      # Infrastructure stop commands
      (mkScript "pulse-pg-stop"
        "${pkgs.postgresql}/bin/pg_ctl -D ${pulseRuntimeDir}/postgres stop -m fast || true")
      (mkScript "pulse-redis-stop" ''
        if [ -f "${pulseRuntimeDir}/redis.pid" ]; then
          kill "$(cat "${pulseRuntimeDir}/redis.pid")" >/dev/null 2>&1 || true
          rm -f "${pulseRuntimeDir}/redis.pid"
        fi
      '')
    ] ++ lib.optionals pkgs.stdenv.isLinux [
      # Core commands (Linux only)
      coreEnsureInfra

      (mkScript "core-shell" ''
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix develop "${configFlake}#core-backend" -c bash -c '
          export PGHOST="$HOME/.local/state/core/postgres-socket"
          export PGPORT="54329"
          cd "$HOME/Developer/papershift/shift_app"
          exec ${pkgs.zsh}/bin/zsh -i
        '
      '')

      (mkScript "core-bootstrap" ''
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix develop "${configFlake}#core-backend" -c bash -c '
          if [ -z "''${BUNDLE_GEMS__RAILSLTS__COM:-}" ]; then
            echo "[core] missing RailsLTS auth. Export RAILSLTS_KEY_DEV or BUNDLE_GEMS__RAILSLTS__COM first." >&2
            exit 1
          fi

          export PGHOST="$HOME/.local/state/core/postgres-socket"
          export PGPORT="54329"
          cd "$HOME/Developer/papershift/shift_app"

          bundle config set gems.railslts.com "$BUNDLE_GEMS__RAILSLTS__COM"
          bundle install
          bundle exec rails db:create
          bundle exec rails db:migrate
        '
      '')

      (mkScript "core-web-dev" ''
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix develop "${configFlake}#core-backend" -c bash -c '
          export PGHOST="$HOME/.local/state/core/postgres-socket"
          export PGPORT="54329"
          cd "$HOME/Developer/papershift/shift_app"
          exec bundle exec rails server -b 0.0.0.0 -p 3000
        '
      '')

      (mkScript "core-sidekiq-dev" ''
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix develop "${configFlake}#core-backend" -c bash -c '
          export PGHOST="$HOME/.local/state/core/postgres-socket"
          export PGPORT="54329"
          cd "$HOME/Developer/papershift/shift_app"
          exec bundle exec sidekiq -C config/sidekiq_all.yml
        '
      '')

      (mkScript "core-sidekiq-assignments-dev" ''
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix develop "${configFlake}#core-backend" -c bash -c '
          export PGHOST="$HOME/.local/state/core/postgres-socket"
          export PGPORT="54329"
          cd "$HOME/Developer/papershift/shift_app"
          exec bundle exec sidekiq -C config/sidekiq_assignments.yml
        '
      '')

      (mkScript "core-rubocop-format" ''
        if [ "$#" -ne 1 ]; then
          echo "usage: core-rubocop-format <project-relative-file>" >&2
          exit 2
        fi

        relpath="$1"
        tmpfile="$(mktemp)"
        trap 'rm -f "$tmpfile"' EXIT
        cat > "$tmpfile"

        exec nix develop "${configFlake}#core-backend" -c bash -c "
          cd \"$HOME/Developer/papershift/shift_app\"
          exec bundle exec rubocop -a \
            --except Style/NegatedIf,Style/IfUnlessModifier,Style/GuardClause \
            -f quiet --stderr --stdin '$relpath' < '$tmpfile'
        "
      '')

      (mkScript "core-pg-stop"
        "${pkgs.postgresql}/bin/pg_ctl -D ${coreRuntimeDir}/postgres stop -m fast || true")

      (mkScript "core-redis-stop" ''
        if [ -f "${coreRuntimeDir}/redis.pid" ]; then
          kill "$(cat "${coreRuntimeDir}/redis.pid")" >/dev/null 2>&1 || true
          rm -f "${coreRuntimeDir}/redis.pid"
        fi
      '')

      # Process compose orchestrators
      (mkScript "pulse-dev" ''
        config_file="$(mktemp)"
        trap 'rm -f "$config_file"' EXIT

        ws_process=""
        if command -v anycable-go >/dev/null 2>&1; then
          ws_process=$'  ws:\n    command: pulse-ws-dev\n'
        else
          echo "[pulse] anycable-go is not installed; starting without websocket server" >&2
        fi

        cat > "$config_file" <<EOF
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

      (mkScript "pulse-chrome-dev" ''
        mkdir -p "${pulseRuntimeDir}/chrome"
        exec ${pkgs.chromium}/bin/chromium \
          --headless \
          --disable-gpu \
          --no-first-run \
          --remote-debugging-address=0.0.0.0 \
          --remote-debugging-port=9222 \
          --user-data-dir="${pulseRuntimeDir}/chrome"
      '')

      (mkScript "core-dev" ''
        config_file="$(mktemp)"
        trap 'rm -f "$config_file"' EXIT

        cat > "$config_file" <<EOF
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
      '')
    ];
  };
}
