{ lib, config, pkgs, ... }:
let
  cfg = config.roles.papershift;
  homeDir = config.home.homeDirectory;
  configFlake = "${homeDir}/snowman-config";

  # Runtime directories
  pulseRuntime = "${homeDir}/.local/state/pulse";
  coreRuntime = "${homeDir}/.local/state/core";

  mkScript = name: script: pkgs.writeShellScriptBin name "set -euo pipefail\n${script}";

  # Helper to load .env files (clean, reusable)
  loadEnvFile = envPath: ''
    if [ -f "${envPath}" ]; then
      set -a
      while IFS='=' read -r key value; do
        [ -n "$key" ] && [ "''${key:0:1}" != "#" ] && export "$key=$value"
      done < <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "${envPath}")
      set +a
    fi
  '';

  # Infrastructure management helpers
  mkInfraManager = { name, runtime, port ? 54329, redisPort ? 6381 }:
    mkScript "${name}-ensure-infra" ''
      mkdir -p "${runtime}/postgres-socket" "${runtime}/redis"

      if [ ! -f "${runtime}/postgres/PG_VERSION" ]; then
        echo "[${name}] initializing postgres"
        ${pkgs.postgresql}/bin/initdb -D "${runtime}/postgres" >/dev/null
      fi

      if ! ${pkgs.postgresql}/bin/pg_isready -h "${runtime}/postgres-socket" -p ${toString port} >/dev/null 2>&1; then
        echo "[${name}] starting postgres"
        ${pkgs.postgresql}/bin/pg_ctl -D "${runtime}/postgres" stop -m fast >/dev/null 2>&1 || true
        rm -f "${runtime}/postgres-socket/.s.PGSQL.${toString port}"*
        ${pkgs.postgresql}/bin/pg_ctl -D "${runtime}/postgres" \
          -l "${runtime}/postgres.log" \
          -o "-k ${runtime}/postgres-socket -p ${toString port} -c listen_addresses=" \
          start >/dev/null
      fi

      if ! ${pkgs.redis}/bin/redis-cli -p ${toString redisPort} ping >/dev/null 2>&1; then
        echo "[${name}] starting redis"
        [ -f "${runtime}/redis.pid" ] && kill "$(cat "${runtime}/redis.pid")" 2>/dev/null || true
        ${pkgs.redis}/bin/redis-server --daemonize yes --port ${toString redisPort} \
          --dir "${runtime}/redis" --pidfile "${runtime}/redis.pid" --logfile "${runtime}/redis.log"
      fi
    '';

  pulseEnsureInfra = mkInfraManager { name = "pulse"; runtime = pulseRuntime; };
  coreEnsureInfra = mkInfraManager { name = "core"; runtime = coreRuntime; };

  # Generic devShell wrapper
  mkDevShell = { name, shell, envSetup ? "", cmd, ensureInfra ? null }:
    mkScript name (
      lib.optionalString (ensureInfra != null) "${ensureInfra}/bin/${ensureInfra.name}\n" +
      ''
        exec nix develop "${configFlake}#${shell}" -c bash <<'DEV_SCRIPT'
          ${envSetup}
          ${cmd}
        DEV_SCRIPT
      ''
    );

  # Pulse environment setup (reusable)
  pulseEnvSetup = ''
    export PGHOST="$HOME/.local/state/pulse/postgres-socket"
    export PGPORT="54329"
    export PGUSER="$(whoami)"
    export POSTGRES_HOST="$HOME/.local/state/pulse/postgres-socket"
    export POSTGRES_PORT="54329"
    export POSTGRES_USER="$(whoami)"
    export REDIS_URL="redis://127.0.0.1:6381/0"

    ${loadEnvFile "$HOME/Developer/papershift/pulse/.env"}

    cd "$HOME/Developer/papershift/pulse/backend"
  '';

  coreEnvSetup = ''
    export PGHOST="$HOME/.local/state/core/postgres-socket"
    export PGPORT="54329"
    cd "$HOME/Developer/papershift/shift_app"
  '';

in
{
  options.roles.papershift.enable = lib.mkEnableOption "Papershift role";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      # Editor tooling
      ruby_3_4 solargraph rubocop
      typescript typescript-language-server vue-language-server astro-language-server
      eslint prettier prettierd

      # Infrastructure
      postgresql redis pulseEnsureInfra

      # Pulse backend
      (mkDevShell {
        name = "pulse-shell";
        shell = "pulse-backend";
        envSetup = pulseEnvSetup;
        cmd = "exec ${pkgs.zsh}/bin/zsh -i";
        ensureInfra = pulseEnsureInfra;
      })
      (mkDevShell {
        name = "pulse-backend-dev";
        shell = "pulse-backend";
        envSetup = pulseEnvSetup;
        cmd = "exec bin/rails s";
        ensureInfra = pulseEnsureInfra;
      })
      (mkDevShell {
        name = "pulse-api-dev";
        shell = "pulse-backend";
        envSetup = pulseEnvSetup;
        cmd = "./lib/scripts/entrypoint.sh\nexec bin/web";
        ensureInfra = pulseEnsureInfra;
      })
      (mkDevShell {
        name = "pulse-anycable-dev";
        shell = "pulse-backend";
        envSetup = pulseEnvSetup + "\nexport ANYCABLE_RPC_HOST=0.0.0.0:50051";
        cmd = "exec bin/anycable";
        ensureInfra = pulseEnsureInfra;
      })
      (mkDevShell {
        name = "pulse-sidekiq-dev";
        shell = "pulse-backend";
        envSetup = pulseEnvSetup;
        cmd = "exec bin/worker";
        ensureInfra = pulseEnsureInfra;
      })
      (mkDevShell {
        name = "pulse-bootstrap";
        shell = "pulse-backend";
        envSetup = pulseEnvSetup;
        cmd = "bundle config set build.ds9 --use-system-libraries && bundle install && bin/rails db:create db:prepare";
        ensureInfra = pulseEnsureInfra;
      })

      # Pulse frontend
      (mkDevShell {
        name = "pulse-frontend-shell";
        shell = "pulse-frontend";
        envSetup = "cd $HOME/Developer/papershift/pulse/frontend";
        cmd = "exec ${pkgs.zsh}/bin/zsh -i";
      })
      (mkDevShell {
        name = "pulse-frontend-dev";
        shell = "pulse-frontend";
        envSetup = "cd $HOME/Developer/papershift/pulse/frontend";
        cmd = "exec pnpm dev";
      })
      (mkScript "pulse-frontend-bootstrap" ''
        mkdir -p "$HOME/.local/share/pnpm" "$HOME/.cache"
        exec nix develop "${configFlake}#pulse-frontend" -c bash -c '
          export PNPM_HOME="$HOME/.local/share/pnpm"
          export PNPM_STORE_DIR="$HOME/.local/share/pnpm/store"
          cd "$HOME/Developer/papershift/pulse/frontend"
          exec env NPM_CONFIG_USERCONFIG=/dev/null pnpm install
        '
      '')

      # Pulse agent
      (mkScript "pulse-agent-dev" ''
        exec nix develop "${configFlake}#pulse-agent" -c bash <<'AGENT_SCRIPT'
          ${loadEnvFile "$HOME/Developer/papershift/pulse/.env"}
          cd "$HOME/Developer/papershift/pulse/agent"
          exec uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
        AGENT_SCRIPT
      '')

      # Pulse WebSocket (requires anycable-go)
      (mkScript "pulse-ws-dev" ''
        ${pulseEnsureInfra}/bin/pulse-ensure-infra
        if ! command -v anycable-go >/dev/null 2>&1; then
          echo "[pulse] anycable-go not installed; skipping websocket server" >&2
          exit 1
        fi
        exec anycable-go --host 0.0.0.0 --port 8080 --path /cable \
          --redis_url "redis://127.0.0.1:6381/0" --rpc_host 127.0.0.1:50051
      '')

      # Pulse infrastructure control
      (mkScript "pulse-pg-stop" "${pkgs.postgresql}/bin/pg_ctl -D ${pulseRuntime}/postgres stop -m fast || true")
      (mkScript "pulse-redis-stop" "[ -f ${pulseRuntime}/redis.pid ] && kill $(cat ${pulseRuntime}/redis.pid) 2>/dev/null || true")

      # Process orchestrator (works on all platforms)
      (mkScript "pulse-dev" ''
        config_file="$(mktemp)"
        trap 'rm -f "$config_file"' EXIT

        # Add websocket if anycable-go is available
        ws_line=""
        command -v anycable-go >/dev/null 2>&1 && ws_line=$'  ws:\n    command: pulse-ws-dev\n'

        # Add chrome only on Linux (requires chromium)
        chrome_line=""
        ${lib.optionalString pkgs.stdenv.isLinux ''chrome_line=$'  chrome:\n    command: pulse-chrome-dev\n' ''}

        cat > "$config_file" <<EOF
        version: "0.5"
        processes:
          frontend:
            command: pulse-frontend-dev
          api:
            command: pulse-api-dev
          agent:
            command: pulse-agent-dev
          sidekiq:
            command: pulse-sidekiq-dev
          anycable:
            command: pulse-anycable-dev
        ''${chrome_line}''${ws_line}
        EOF
        exec ${pkgs.process-compose}/bin/process-compose -f "$config_file" up
      '')

    ] ++ lib.optionals pkgs.stdenv.isLinux [
      # Chrome dev server (Linux only - requires chromium)
      (mkScript "pulse-chrome-dev" ''
        mkdir -p "${pulseRuntime}/chrome"
        exec ${pkgs.chromium}/bin/chromium --headless --disable-gpu --no-first-run \
          --remote-debugging-address=0.0.0.0 --remote-debugging-port=9222 \
          --user-data-dir="${pulseRuntime}/chrome"
      '')
      # Core backend (Linux only)
      coreEnsureInfra

      (mkScript "core-shell" ''
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix develop "${configFlake}#core-backend" -c bash -c '
          ${coreEnvSetup}
          exec ${pkgs.zsh}/bin/zsh -i
        '
      '')

      (mkScript "core-bootstrap" ''
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix develop "${configFlake}#core-backend" -c bash -c '
          if [ -z "''${BUNDLE_GEMS__RAILSLTS__COM:-}" ]; then
            echo "[core] missing RailsLTS auth" >&2
            exit 1
          fi
          ${coreEnvSetup}
          bundle config set gems.railslts.com "$BUNDLE_GEMS__RAILSLTS__COM"
          bundle install
          bundle exec rails db:create db:migrate
        '
      '')

      (mkScript "core-web-dev" ''
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix develop "${configFlake}#core-backend" -c bash -c '
          ${coreEnvSetup}
          exec bundle exec rails server -b 0.0.0.0 -p 3000
        '
      '')

      (mkScript "core-sidekiq-dev" ''
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix develop "${configFlake}#core-backend" -c bash -c '
          ${coreEnvSetup}
          exec bundle exec sidekiq -C config/sidekiq_all.yml
        '
      '')

      (mkScript "core-sidekiq-assignments-dev" ''
        ${coreEnsureInfra}/bin/core-ensure-infra
        exec nix develop "${configFlake}#core-backend" -c bash -c '
          ${coreEnvSetup}
          exec bundle exec sidekiq -C config/sidekiq_assignments.yml
        '
      '')

      (mkScript "core-rubocop-format" ''
        [ "$#" -ne 1 ] && { echo "usage: core-rubocop-format <file>" >&2; exit 2; }
        tmpfile="$(mktemp)"
        trap 'rm -f "$tmpfile"' EXIT
        cat > "$tmpfile"
        exec nix develop "${configFlake}#core-backend" -c bash -c "
          ${coreEnvSetup}
          bundle exec rubocop -a --except Style/NegatedIf,Style/IfUnlessModifier,Style/GuardClause \
            -f quiet --stderr --stdin '$1' < '$tmpfile'
        "
      '')

      (mkScript "core-pg-stop" "${pkgs.postgresql}/bin/pg_ctl -D ${coreRuntime}/postgres stop -m fast || true")
      (mkScript "core-redis-stop" "[ -f ${coreRuntime}/redis.pid ] && kill $(cat ${coreRuntime}/redis.pid) 2>/dev/null || true")

      # Core orchestrator (Linux only)
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
