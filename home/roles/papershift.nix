{
  lib,
  config,
  pkgs,
  pkgsUnstable,
  ...
}:
let
  cfg = config.roles.papershift;
  homeDir = config.home.homeDirectory;
  configFlake = "${homeDir}/snowman-config";
  isDarwin = pkgs.stdenv.isDarwin;

  # Runtime directories
  pulseRuntime = "${homeDir}/.local/state/pulse";
  coreRuntime = "${homeDir}/.local/state/core";

  mkScript = name: script: pkgs.writeShellScriptBin name "set -euo pipefail\n${script}";

  disableLegacyRubyDebuggers = pkgs.writeText "disable-legacy-ruby-debuggers.rb" ''
    module Kernel
      alias_method :snowman_require_without_legacy_debuggers, :require

      def require(name)
        return false if name == "pry-byebug" || name == "byebug"

        snowman_require_without_legacy_debuggers(name)
      end
    end
  '';

  projectRubyEnv =
    {
      projectRoot,
      quietRubyWarnings ? false,
    }:
    ''
      export BUNDLE_PATH="${projectRoot}/.bundle/vendor"
      export BUNDLE_DISABLE_SHARED_GEMS="true"
      unset BUNDLE_BIN GEM_HOME GEM_PATH
      ${lib.optionalString quietRubyWarnings ''
        case " ''${RUBYOPT:-} " in
          *" -W0 "*) ;;
          *) export RUBYOPT="-W0 ''${RUBYOPT:-}" ;;
        esac
      ''}
    '';

  # Helper to load .env files (clean, reusable)
  loadEnvFile = envPath: ''
    if [ -f "${envPath}" ]; then
      set -a
      while IFS='=' read -r key value; do
        if [ -n "$key" ] && [ "''${key:0:1}" != "#" ]; then
          # Strip whitespace from key
          key="''${key#"''${key%%[![:space:]]*}"}"  # leading whitespace
          key="''${key%"''${key##*[![:space:]]}"}"  # trailing whitespace

          # Strip comments from value
          value="''${value%%#*}"

          # Strip leading/trailing whitespace and quotes from value
          value="''${value#"''${value%%[![:space:]]*}"}"  # leading whitespace
          value="''${value%"''${value##*[![:space:]]}"}"  # trailing whitespace
          value="''${value#\'}"  # leading single quote
          value="''${value%\'}"  # trailing single quote
          value="''${value#\"}"  # leading double quote
          value="''${value%\"}"  # trailing double quote

          export "$key=$value"
        fi
      done < <(grep -E '^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=' "${envPath}")
      set +a
    fi
  '';

  # Infrastructure management helpers
  mkInfraManager =
    {
      name,
      runtime,
      port ? 54329,
      redisPort ? 6381,
    }:
    mkScript "${name}-ensure-infra" ''
      mkdir -p "${runtime}/postgres-socket" "${runtime}/redis"

      # Use a lockfile to serialize infrastructure startup across services
      (
        ${pkgs.flock}/bin/flock -x 9

        if [ ! -f "${runtime}/postgres/PG_VERSION" ]; then
          echo "[${name}] initializing postgres"
          [ -d "${runtime}/postgres" ] && rm -rf "${runtime}/postgres"
          if ! ${pkgs.postgresql}/bin/initdb -D "${runtime}/postgres" >/dev/null; then
            echo "[${name}] postgres initialization failed, cleaning up"
            rm -rf "${runtime}/postgres"
            exit 1
          fi
        fi

        if ! ${pkgs.postgresql}/bin/pg_isready -h "${runtime}/postgres-socket" -p ${toString port} >/dev/null 2>&1; then
          echo "[${name}] starting postgres"
          ${pkgs.postgresql}/bin/pg_ctl -D "${runtime}/postgres" stop -m fast >/dev/null 2>&1 || true
          rm -f "${runtime}/postgres-socket/.s.PGSQL.${toString port}"*
          # Close the lock fd before daemon startup so postgres does not inherit it
          # and keep infra.lock held across future pulse-dev restarts.
          (
            exec 9>&-
            ${pkgs.postgresql}/bin/pg_ctl -D "${runtime}/postgres" \
              -l "${runtime}/postgres.log" \
              -o "-k ${runtime}/postgres-socket -p ${toString port} -c listen_addresses=" \
              start >/dev/null
          )
          
          # Wait for socket to appear to ensure next service sees it as ready
          for i in {1..50}; do
            [ -S "${runtime}/postgres-socket/.s.PGSQL.${toString port}" ] && break
            sleep 0.1
          done
        fi

        if ! ${pkgs.redis}/bin/redis-cli -p ${toString redisPort} ping >/dev/null 2>&1; then
          echo "[${name}] starting redis"
          [ -f "${runtime}/redis.pid" ] && kill "$(cat "${runtime}/redis.pid")" 2>/dev/null || true
          # Same for redis: do not let the daemon inherit the lock fd.
          (
            exec 9>&-
            ${pkgs.redis}/bin/redis-server --daemonize yes --port ${toString redisPort} \
              --dir "${runtime}/redis" --pidfile "${runtime}/redis.pid" --logfile "${runtime}/redis.log"
          )
          
          # Wait for redis to be ready
          for i in {1..50}; do
            ${pkgs.redis}/bin/redis-cli -p ${toString redisPort} ping >/dev/null 2>&1 && break
            sleep 0.1
          done
        fi
      ) 9>"${runtime}/infra.lock"
    '';

  pulseEnsureInfra = mkInfraManager {
    name = "pulse";
    runtime = pulseRuntime;
  };
  coreEnsureInfra = mkInfraManager {
    name = "core";
    runtime = coreRuntime;
  };

  darwinPkgs = with pkgsUnstable; [
    slack
    zoom-us
  ];

  # Generic devShell wrapper
  mkDevShell =
    {
      name,
      shell,
      envSetup ? "",
      cmd,
      ensureInfra ? null,
    }:
    mkScript name (
      lib.optionalString (ensureInfra != null) "${ensureInfra}/bin/${ensureInfra.name}\n"
      + ''
        exec nix develop "${configFlake}#${shell}" -c bash <<'DEV_SCRIPT'
          ${envSetup}
          ${cmd}
        DEV_SCRIPT
      ''
    );

  # Pulse environment setup (reusable)
  pulseEnvSetup = ''
    # Load .env first
    ${loadEnvFile "$HOME/Developer/papershift/pulse/.env"}

    # Override with local development settings (after .env so these take precedence)
    export PGHOST="$HOME/.local/state/pulse/postgres-socket"
    export PGPORT="54329"
    export PGUSER="$(whoami)"
    export POSTGRES_HOST="$HOME/.local/state/pulse/postgres-socket"
    export POSTGRES_PORT="54329"
    export POSTGRES_USER="$(whoami)"
    export REDIS_URL="redis://127.0.0.1:6381/0"

    # Override service URLs for local development
    export AGENT_URL="http://127.0.0.1:8001"
    export API_URL="http://127.0.0.1:3000"
    export VITE_CABLE_URL="ws://127.0.0.1:8081/cable"

    ${projectRubyEnv {
      projectRoot = "$HOME/Developer/papershift/pulse";
      quietRubyWarnings = true;
    }}
    cd "$HOME/Developer/papershift/pulse/backend"
  '';

  coreEnvSetup = ''
    export PGHOST="$HOME/.local/state/core/postgres-socket"
    export PGPORT="54329"
    ${projectRubyEnv { projectRoot = "$HOME/Developer/papershift/shift_app"; }}
    cd "$HOME/Developer/papershift/shift_app"
  '';

  # anycable-go binary (not in nixpkgs, fetch from GitHub releases)
  anycable-go = pkgs.stdenv.mkDerivation rec {
    pname = "anycable-go";
    version = "1.5.6";

    src =
      let
        platform =
          if pkgs.stdenv.isDarwin then
            (if pkgs.stdenv.isAarch64 then "darwin-arm64" else "darwin-amd64")
          else
            "linux-amd64";
      in
      pkgs.fetchurl {
        url = "https://github.com/anycable/anycable-go/releases/download/v${version}/anycable-go-${platform}";
        hash =
          if pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64 then
            "sha256-Y4DWpMlkc1/TTtDfaHc8oFCS0+OUrK10/AavNI/7ajY="
          else if pkgs.stdenv.isDarwin then
            "sha256-PLACEHOLDER-DARWIN-AMD64" # Add if needed
          else
            "sha256-2pGD7up4atlcBFz7rBolT+03jphz5W4XXYpepICi//I=";
      };

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -D -m755 $src $out/bin/anycable-go
      runHook postInstall
    '';

    meta = {
      description = "AnyCable Go WebSocket server";
      homepage = "https://github.com/anycable/anycable-go";
      platforms = pkgs.lib.platforms.unix;
    };
  };

in
{
  options.roles.papershift.enable = lib.mkEnableOption "Papershift role";

  config = lib.mkIf cfg.enable {
    home.packages =
      (
        with pkgs;
        [
          # Editor tooling
          ruby_3_4
          ruby-lsp
          solargraph
          rubocop
          typescript
          typescript-language-server
          vue-language-server
          astro-language-server
          eslint
          prettier
          prettierd

          # Infrastructure
          postgresql
          redis
          pulseEnsureInfra
          anycable-go

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
            name = "pulse-api-debug";
            shell = "pulse-backend";
            envSetup = pulseEnvSetup;
            cmd = ''
              export RUBYOPT="-r ${disableLegacyRubyDebuggers} ''${RUBYOPT:-}"
              echo "[pulse-api] Starting with rdbg on port 1234 (attach optional)..."
              exec rdbg --nonstop --open=vscode --host 127.0.0.1 --port 1234 -c -- bundle exec puma -C config/puma.rb
            '';
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
            name = "pulse-sidekiq-debug";
            shell = "pulse-backend";
            envSetup = pulseEnvSetup;
            cmd = ''
              export RUBYOPT="-r ${disableLegacyRubyDebuggers} ''${RUBYOPT:-}"
              echo "[pulse-sidekiq] Starting with rdbg on port 1235 (attach optional)..."
              exec rdbg --nonstop --open=vscode --host 127.0.0.1 --port 1235 -c -- bundle exec sidekiq -C config/sidekiq.yml
            '';
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
            envSetup = ''
              export VITE_CABLE_URL="ws://127.0.0.1:8081/cable"
              cd $HOME/Developer/papershift/pulse/frontend
            '';
            cmd = "exec ${pkgs.zsh}/bin/zsh -i";
          })
          (mkDevShell {
            name = "pulse-frontend-dev";
            shell = "pulse-frontend";
            envSetup = ''
              export VITE_CABLE_URL="ws://127.0.0.1:8081/cable"
              cd $HOME/Developer/papershift/pulse/frontend
            '';
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

          # Pulse agent with debugpy (for neovim DAP)
          (mkScript "pulse-agent-debug" ''
            exec nix develop "${configFlake}#pulse-agent" -c bash <<'AGENT_SCRIPT'
              ${loadEnvFile "$HOME/Developer/papershift/pulse/.env"}
              cd "$HOME/Developer/papershift/pulse/agent"
              echo "[pulse-agent] Starting with debugpy on port 5678 (ready to attach)..."
              exec python -Xfrozen_modules=off -m debugpy --listen 0.0.0.0:5678 -m uvicorn app.main:app --host 0.0.0.0 --port 8001
            AGENT_SCRIPT
          '')

          # Pulse WebSocket (requires anycable-go)
          (mkScript "pulse-ws-dev" ''
            ${pulseEnsureInfra}/bin/pulse-ensure-infra
            if ! command -v anycable-go >/dev/null 2>&1; then
              echo "[pulse] anycable-go not installed; skipping websocket server" >&2
              exit 1
            fi

            # Load .env to get ANYCABLE_JWT_SECRET and other config
            ${loadEnvFile "$HOME/Developer/papershift/pulse/.env"}

            exec anycable-go --host 0.0.0.0 --port 8081 --path /cable \
              --redis_url "redis://127.0.0.1:6381/0" --rpc_host 127.0.0.1:50051 \
              --jwt_id_key jid --jwt_id_enforce --secret "$ANYCABLE_JWT_SECRET" --presets broker --log_level debug
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

            # Always use debug agent (debugpy on port 5678)
            agent_cmd="pulse-agent-debug"

            cat > "$config_file" <<EOF
            version: "0.5"
            processes:
              frontend:
                command: pulse-frontend-dev
              api:
                command: pulse-api-debug
              agent:
                command: $agent_cmd
              sidekiq:
                command: pulse-sidekiq-debug
              anycable:
                command: pulse-anycable-dev
            ''${chrome_line}''${ws_line}
            EOF
            exec ${pkgs.process-compose}/bin/process-compose -f "$config_file" up
          '')
          (mkScript "pulse-debug" ''
            config_file="$(mktemp)"
            trap 'rm -f "$config_file"' EXIT

            ws_line=""
            command -v anycable-go >/dev/null 2>&1 && ws_line=$'  ws:\n    command: pulse-ws-dev\n'

            chrome_line=""
            ${lib.optionalString pkgs.stdenv.isLinux ''chrome_line=$'  chrome:\n    command: pulse-chrome-dev\n' ''}

            agent_cmd="pulse-agent-debug"

            cat > "$config_file" <<EOF
            version: "0.5"
            processes:
              frontend:
                command: pulse-frontend-dev
              api:
                command: pulse-api-debug
              agent:
                command: $agent_cmd
              sidekiq:
                command: pulse-sidekiq-debug
              anycable:
                command: pulse-anycable-dev
            ''${chrome_line}''${ws_line}
            EOF
            exec ${pkgs.process-compose}/bin/process-compose -f "$config_file" up
          '')

        ]
        ++ lib.optionals pkgs.stdenv.isLinux [
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
        ]
      )
      ++ lib.optionals isDarwin darwinPkgs;
  };
}
