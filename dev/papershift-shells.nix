# Development shells for Papershift projects
# Consumed by the main flake.nix
{ nixpkgs, nixpkgs-23_11 }:

let
  forSystems = f: nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] f;
  inherit (nixpkgs.lib) concatStringsSep;

  mkPkgs =
    system:
    import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      config.allowUnsupportedSystem = true;
    };

  mkCorePkgs =
    system:
    import nixpkgs-23_11 {
      inherit system;
      config.allowUnfree = true;
      config.permittedInsecurePackages = [
        "ruby-2.7.8"
        "openssl-1.1.1w"
      ];
    };
in
forSystems (
  system:
  let
    pkgs = mkPkgs system;
    corePkgs = mkCorePkgs system;
    mkExports =
      attrs:
      concatStringsSep "\n" (
        builtins.map (name: ''export ${name}="${attrs.${name}}"'') (builtins.attrNames attrs)
      );
    mkShellHook =
      exports: cwd: extra:
      ''
        ${mkExports exports}
      ''
      + (if extra == "" then "" else "\n${extra}\n")
      + ''
        cd "${cwd}"
      '';
    rubyBundleEnv =
      {
        projectRoot,
        quietRubyWarnings ? false,
      }:
      ''
        export BUNDLE_PATH="${projectRoot}/.bundle/vendor"
        export BUNDLE_DISABLE_SHARED_GEMS="true"
        unset BUNDLE_BIN GEM_HOME GEM_PATH
        ${nixpkgs.lib.optionalString quietRubyWarnings ''
          case " ''${RUBYOPT:-} " in
            *" -W0 "*) ;;
            *) export RUBYOPT="-W0 ''${RUBYOPT:-}" ;;
          esac
        ''}
      '';

    pulseRoot = "$HOME/Developer/papershift/pulse";
    pulseCommonExports = {
      PULSE_ROOT = pulseRoot;
      LANG = "en_US.UTF-8";
    };

    pulseBackendStateDir = "$HOME/.local/state/pulse";
    pulseBackendCommonExports = pulseCommonExports // {
      PGDATA = "${pulseBackendStateDir}/postgres";
      PGHOST = "${pulseBackendStateDir}/postgres-socket";
      PGPORT = "54329";
      PGUSER = "$USER";
      POSTGRES_HOST = "${pulseBackendStateDir}/postgres-socket";
      POSTGRES_PORT = "54329";
      POSTGRES_USER = "$USER";
    };

    pulseFrontendCommonExports = pulseCommonExports // {
      PNPM_HOME = "$HOME/.local/share/pnpm";
      PNPM_STORE_DIR = "$PNPM_HOME/store";
      XDG_DATA_HOME = "\${XDG_DATA_HOME:-$HOME/.local/share}";
      XDG_CACHE_HOME = "\${XDG_CACHE_HOME:-$HOME/.cache}";
    };

    coreStateDir = "$HOME/.local/state/core";
    coreBackendCommonExports = {
      SHIFT_APP_ROOT = "$HOME/Developer/papershift/shift_app";
      LANG = "en_US.UTF-8";
      PGDATA = "${coreStateDir}/postgres";
      PGHOST = "${coreStateDir}/postgres-socket";
      PGPORT = "54329";
      PGUSER = "$USER";
      PGPASS = "";
      POSTGRESQL_HOST = "${coreStateDir}/postgres-socket";
      POSTGRESQL_PORT = "54329";
    };

    qoveryPackage = pkgs.symlinkJoin {
      name = "qovery-with-alias";
      paths = [ pkgs.qovery-cli ];
      postBuild = ''
        ln -s $out/bin/qovery-cli $out/bin/qovery
      '';
    };

    papershiftCliPackages = with pkgs; [
      qoveryPackage
    ];
  in
  {
    pulse-backend = pkgs.mkShell {
      buildInputs =
        papershiftCliPackages
        ++ (with pkgs; [
          libyaml
          openssl
          postgresql
          vips
          zlib
          libffi
          nghttp2
          protobuf
          ruby_3_4
          nodejs_22
          pnpm
          redis
        ]);

      nativeBuildInputs = with pkgs; [
        pkg-config
        autoconf
        automake
        libtool
        cmake
        clang
        gnumake
      ];

      shellHook = mkShellHook pulseBackendCommonExports "${pulseRoot}/backend" ''
        # Fix google-protobuf and ds9 build on macOS
        export CFLAGS="-Wno-error=format-security -Wno-error=incompatible-pointer-types-discards-qualifiers"
        export CXXFLAGS="-Wno-error=format-security -Wno-error=incompatible-pointer-types-discards-qualifiers"
        export NIX_CFLAGS_COMPILE="-Wno-error=format-security -Wno-error=incompatible-pointer-types-discards-qualifiers"
        export MAKEFLAGS="CFLAGS=-Wno-error=format-security -Wno-error=incompatible-pointer-types-discards-qualifiers"

        export REDIS_URL="redis://127.0.0.1:6381/0"

        # API/service URLs
        export API_URL="http://127.0.0.1:3000"
        export AGENT_URL="http://127.0.0.1:8001"
        export CHROME_HOST="127.0.0.1"
        export ANYCABLE_RPC_HOST="127.0.0.1:50051"

        export VITE_API_URL="http://127.0.0.1:3000"
        export VITE_CABLE_URL="ws://127.0.0.1:8081/cable"

        ${rubyBundleEnv {
          projectRoot = pulseRoot;
          quietRubyWarnings = true;
        }}

        # Note: .env is loaded by wrapper scripts with proper parsing
        # No need to load here to avoid double-loading
      '';
    };

    pulse-frontend = pkgs.mkShell {
      packages =
        papershiftCliPackages
        ++ (with pkgs; [
          nodejs_22
          pnpm
          git
          zsh
        ]);

      shellHook = mkShellHook pulseFrontendCommonExports "${pulseRoot}/frontend" ''
        # Override WebSocket URL (process-compose uses 8080, so we use 8081)
        export VITE_CABLE_URL="ws://127.0.0.1:8081/cable"
      '';
    };

    pulse-agent = pkgs.mkShell {
      packages = papershiftCliPackages ++ [
        (pkgs.python3.withPackages (
          ps: with ps; [
            fastapi
            httpx
            langdetect
            langchain
            langchain-core
            langchain-text-splitters
            markdown2
            openai
            openai-agents
            pypdf
            python-docx
            python-dotenv
            uvicorn
            debugpy
            weaviate-client
          ]
        ))
      ];

      shellHook = mkShellHook pulseCommonExports "${pulseRoot}/agent" ''
        # Note: .env is loaded by the wrapper script with proper parsing
        # No need to load here to avoid double-loading
      '';
    };

    core-backend = corePkgs.mkShell {
      buildInputs = [
        pkgs.qovery-cli
      ]
      ++ (with corePkgs; [
        imagemagick
        libffi
        libxml2
        libxslt
        libyaml
        openssl
        postgresql
        shared-mime-info
        zlib
        ruby_2_7
        nodejs
        redis
      ]);

      nativeBuildInputs =
        with corePkgs;
        [ pkg-config ] ++ pkgs.lib.optionals corePkgs.stdenv.isLinux [ gcc ];

      shellHook = mkShellHook coreBackendCommonExports "$HOME/Developer/papershift/shift_app" ''
        export POSTGRESQL_DATABASE="shift_app_development"
        export POSTGRESQL_USERNAME="$USER"
        export POSTGRESQL_PASSWORD=""
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

        ${rubyBundleEnv { projectRoot = "$HOME/Developer/papershift/shift_app"; }}

        if [ -n "''${RAILSLTS_KEY_DEV:-}" ] && [ -z "''${BUNDLE_GEMS__RAILSLTS__COM:-}" ]; then
          export BUNDLE_GEMS__RAILSLTS__COM="$RAILSLTS_KEY_DEV"
        fi
      '';
    };
  }
)
