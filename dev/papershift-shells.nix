# Development shells for Papershift projects
# Consumed by the main flake.nix
{ nixpkgs, nixpkgs-23_11 }:

let
  forSystems = f: nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] f;

  mkPkgs = system: import nixpkgs {
    inherit system;
    config.allowUnfree = true;
    config.allowUnsupportedSystem = true;
  };

  mkCorePkgs = system: import nixpkgs-23_11 {
    inherit system;
    config.allowUnfree = true;
    config.permittedInsecurePackages = [ "ruby-2.7.8" "openssl-1.1.1w" ];
  };
in
forSystems (system:
  let
    pkgs = mkPkgs system;
    corePkgs = mkCorePkgs system;
  in
  {
    pulse-backend = pkgs.mkShell {
      buildInputs = with pkgs; [
        libyaml openssl postgresql vips zlib libffi nghttp2 protobuf
        ruby_3_4 nodejs_22 pnpm redis
      ];

      nativeBuildInputs = with pkgs; [
        pkg-config autoconf automake libtool cmake clang gnumake
      ];

      shellHook = ''
        # Fix google-protobuf and ds9 build on macOS
        export CFLAGS="-Wno-error=format-security -Wno-error=incompatible-pointer-types-discards-qualifiers"
        export CXXFLAGS="-Wno-error=format-security -Wno-error=incompatible-pointer-types-discards-qualifiers"
        export NIX_CFLAGS_COMPILE="-Wno-error=format-security -Wno-error=incompatible-pointer-types-discards-qualifiers"
        export MAKEFLAGS="CFLAGS=-Wno-error=format-security -Wno-error=incompatible-pointer-types-discards-qualifiers"

        # Postgres/Redis config
        export PGDATA="$HOME/.local/state/pulse/postgres"
        export PGHOST="$HOME/.local/state/pulse/postgres-socket"
        export PGPORT="54329"
        export PGUSER="$USER"

        export POSTGRES_HOST="$HOME/.local/state/pulse/postgres-socket"
        export POSTGRES_PORT="54329"
        export POSTGRES_USER="$USER"

        export REDIS_URL="redis://127.0.0.1:6381/0"

        # API/service URLs
        export API_URL="http://127.0.0.1:3000"
        export AGENT_URL="http://127.0.0.1:8001"
        export CHROME_HOST="127.0.0.1"
        export ANYCABLE_RPC_HOST="127.0.0.1:50051"

        export VITE_API_URL="http://127.0.0.1:3000"
        export VITE_CABLE_URL="ws://127.0.0.1:8081/cable"

        # Bundler config
        export BUNDLE_PATH="$HOME/Developer/papershift/pulse/.bundle/vendor"
        export BUNDLE_BIN="$HOME/Developer/papershift/pulse/.bundle/bin"

        export PULSE_ROOT="$HOME/Developer/papershift/pulse"
        export LANG="en_US.UTF-8"

        # Note: .env is loaded by wrapper scripts with proper parsing
        # No need to load here to avoid double-loading

        cd "$HOME/Developer/papershift/pulse/backend"
      '';
    };

    pulse-frontend = pkgs.mkShell {
      packages = with pkgs; [ nodejs_22 pnpm git zsh ];

      shellHook = ''
        export PULSE_ROOT="$HOME/Developer/papershift/pulse"
        export LANG="en_US.UTF-8"

        export PNPM_HOME="$HOME/.local/share/pnpm"
        export PNPM_STORE_DIR="$PNPM_HOME/store"
        export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
        export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"

        # Override WebSocket URL (process-compose uses 8080, so we use 8081)
        export VITE_CABLE_URL="ws://127.0.0.1:8081/cable"

        cd "$HOME/Developer/papershift/pulse/frontend"
      '';
    };

    pulse-agent = pkgs.mkShell {
      packages = [
        (pkgs.python3.withPackages (ps: with ps; [
          fastapi httpx langdetect langchain langchain-core
          langchain-text-splitters markdown2 openai
          openai-agents pypdf python-docx python-dotenv
          uvicorn debugpy weaviate-client
        ]))
      ];

      shellHook = ''
        export PULSE_ROOT="$HOME/Developer/papershift/pulse"
        export LANG="en_US.UTF-8"

        # Note: .env is loaded by the wrapper script with proper parsing
        # No need to load here to avoid double-loading

        cd "$HOME/Developer/papershift/pulse/agent"
      '';
    };

    core-backend = corePkgs.mkShell {
      buildInputs = with corePkgs; [
        imagemagick libffi libxml2 libxslt libyaml
        openssl postgresql shared-mime-info zlib
        ruby_2_7 nodejs redis
      ];

      nativeBuildInputs = with corePkgs; [ pkg-config ]
        ++ pkgs.lib.optionals corePkgs.stdenv.isLinux [ gcc ];

      shellHook = ''
        export SHIFT_APP_ROOT="$HOME/Developer/papershift/shift_app"
        export LANG="en_US.UTF-8"

        export PGDATA="$HOME/.local/state/core/postgres"
        export PGHOST="$HOME/.local/state/core/postgres-socket"
        export PGPORT="54329"
        export PGUSER="$USER"
        export PGPASS=""

        export POSTGRESQL_DATABASE="shift_app_development"
        export POSTGRESQL_USERNAME="$USER"
        export POSTGRESQL_PASSWORD=""
        export POSTGRESQL_HOST="$HOME/.local/state/core/postgres-socket"
        export POSTGRESQL_PORT="54329"
        export POSTGRESQL_POOL="5"

        export REDISCLOUD_URL="redis://127.0.0.1:6381/0"

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

        cd "$HOME/Developer/papershift/shift_app"
      '';
    };
  }
)
