{
  description = "DarkBones' Snowman Body";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-23_11.url = "github:NixOS/nixpkgs/nixos-23.11";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    awww.url = "git+https://codeberg.org/LGFae/awww";
    ollama-src = {
      url = "github:ollama/ollama/v0.20.2";
      flake = false;
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        home-manager.follows = "home-manager";
      };
    };

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowman = {
      url = "github:DarkBones/snowman";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bas-dotfiles = {
      url = "github:DarkBones/dotfiles/move-files-from-papershift-laptop";
      flake = false;
    };

    stylix = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-openclaw = {
      url = "github:openclaw/nix-openclaw";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, snowman, disko, zen-browser
    , stylix, ... }@inputs:
    let
      lib = nixpkgs.lib;

      inv = import ./inventory.nix;

      dotfilesSources = { bas = inputs.bas-dotfiles; };

      makePkgs = system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

      makePkgsUnstable = system:
        import inputs.nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };

      mkNixosSpecialArgs = name: attrs: {
        inherit inputs home-manager inv sops-nix dotfilesSources disko;
        pkgsUnstable = makePkgsUnstable attrs.system;
        modulesPath = "${nixpkgs}/nixos/modules";
        currentHost = name;
        sopsConfigPath = ./.sops.yaml;
        networkSecretsPath = ./networks/secrets.yml;
        extraHomeImports = [ ./home/roles ./home/overrides ];
      };

      mkHost = name: attrs:
        { strictHw ? true, }:
        let
          host = inv.hosts.${name};
          hostName = host.hostname or name;
          hwFile = ./hosts/${hostName}-hardware-configuration.nix;
          hostRoles =
            if host ? availableRoles then host.availableRoles else null;
          managedUsers = builtins.filter
            (user: (inv.users.${user}.homeManaged or false))
            (attrs.users or [ ]);

          hasRole = role: hostRoles == null || lib.elem role hostRoles;
        in lib.nixosSystem {
          system = attrs.system;
          specialArgs = mkNixosSpecialArgs name attrs;
          modules = (lib.optionals (hasRole "desktop") [
            inputs.stylix.nixosModules.stylix
            ./modules/stylix.nix
          ]) ++ [
            ({ inputs, ... }: {
              nixpkgs.overlays = [ inputs.nix-openclaw.overlays.default ];
            })
            snowman.nixosModules.default
            home-manager.nixosModules.home-manager
            ({ currentHost, inv, ... }: {
              home-manager.extraSpecialArgs = {
                inherit inputs inv currentHost;
                hostRoles = if inv.hosts.${currentHost} ? availableRoles then
                  inv.hosts.${currentHost}.availableRoles
                else
                  null;
              };
            })
            ({ lib, ... }: {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users = lib.genAttrs managedUsers (_: {
                  systemd.user.startServices = lib.mkForce true;
                });
              };
            })

            ({ lib, pkgs, ... }: {
              imports = lib.optional (builtins.pathExists hwFile) hwFile;
              home-manager.backupCommand = pkgs.writeShellScript "hm-backup" ''
                set -euo pipefail

                target="$1"
                stamp="$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
                backup="''${target}.backup-''${stamp}"
                i=0

                while [ -e "$backup" ]; do
                  i=$((i + 1))
                  backup="''${target}.backup-''${stamp}-''${i}"
                done

                exec ${pkgs.coreutils}/bin/mv "$target" "$backup"
              '';

              assertions = lib.optionals strictHw [{
                assertion = builtins.pathExists hwFile;
                message = ''
                  Snowman: Hardware configuration missing for host "${name}"
                     (hostname "${hostName}").

                  Expected file:
                    hosts/${hostName}-hardware-configuration.nix

                  Fix:
                    On the machine this NixOS install is running on, execute:

                      ./bin/snowman-import-hardware ${name}

                    Then re-run:

                      sudo nixos-rebuild switch --flake .#${name}
                '';
              }];
            })
          ] ++ (attrs.extraModules or [ ]);
        };

      hostHwFile = name:
        let
          host = inv.hosts.${name};
          hostName = host.hostname or name;
        in ./hosts/${hostName}-hardware-configuration.nix;

      hostsWithHw =
        lib.filterAttrs (name: _: builtins.pathExists (hostHwFile name))
        inv.hosts;

    in {
      nixosConfigurations =
        lib.mapAttrs (name: attrs: mkHost name attrs { strictHw = false; })
        hostsWithHw;

      nixosConfigurationsAll =
        lib.mapAttrs (name: attrs: mkHost name attrs { strictHw = true; })
        inv.hosts;

      # Dev shells for Papershift development
      devShells = lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (system:
        let
          pkgs = makePkgs system;
          pkgsUnstable = makePkgsUnstable system;

          corePkgs = import inputs.nixpkgs-23_11 {
            inherit system;
            config.allowUnfree = true;
            config.permittedInsecurePackages = [ "ruby-2.7.8" "openssl-1.1.1w" ];
          };
        in
        {
          pulse-backend = pkgs.mkShell {
            buildInputs = with pkgs; [
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
            ];

            nativeBuildInputs = with pkgs; [
              pkg-config
              autoconf
              automake
              libtool
              cmake
              clang
              gnumake
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
              export VITE_CABLE_URL="ws://127.0.0.1:8080/cable"

              # Bundler config
              export BUNDLE_PATH="$HOME/Developer/papershift/pulse/.bundle/vendor"
              export BUNDLE_BIN="$HOME/Developer/papershift/pulse/.bundle/bin"

              export PULSE_ROOT="$HOME/Developer/papershift/pulse"
              export LANG="en_US.UTF-8"

              # Load .env from pulse root
              if [ -f "$HOME/Developer/papershift/pulse/.env" ]; then
                while IFS= read -r line || [ -n "$line" ]; do
                  case "$line" in
                    ""|"#"*) continue ;;
                  esac

                  key="''${line%%=*}"
                  value="''${line#*=}"
                  key="$(printf '%s' "$key" | tr -d '[:space:]')"
                  value="$(printf '%s' "$value" | sed 's/^[[:space:]]*//')"
                  value="$(printf '%s' "$value" | sed -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//')"

                  if [ -n "$key" ]; then
                    export "$key=$value"
                  fi
                done < "$HOME/Developer/papershift/pulse/.env"
              fi

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

              cd "$HOME/Developer/papershift/pulse/frontend"
            '';
          };

          pulse-agent = pkgs.mkShell {
            packages = [
              (pkgs.python3.withPackages (ps: with ps; [
                fastapi
                httpx
                langchain
                markdown2
                openai
                "openai-agents"
                pypdf
                "python-docx"
                "python-dotenv"
                uvicorn
                debugpy
              ] ++ lib.optionals pkgs.stdenv.isLinux [ "weaviate-client" ]))
            ];

            shellHook = ''
              export PULSE_ROOT="$HOME/Developer/papershift/pulse"
              export LANG="en_US.UTF-8"

              # Load .env from pulse root
              if [ -f "$HOME/Developer/papershift/pulse/.env" ]; then
                set -a
                source "$HOME/Developer/papershift/pulse/.env"
                set +a
              fi

              cd "$HOME/Developer/papershift/pulse/agent"
            '';
          };

          core-backend = corePkgs.mkShell {
            buildInputs = with corePkgs; [
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
            ];

            nativeBuildInputs = with corePkgs; [ pkg-config ]
              ++ lib.optionals corePkgs.stdenv.isLinux [ gcc ];

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
      );

      homeConfigurations = lib.listToAttrs (lib.concatMap (hostName:
        let host = inv.hosts.${hostName};
        in lib.concatMap (user:
          let
            cfgName = "${user}@${hostName}";
            userCfg = inv.users.${user};
            userRoles = userCfg.roles or { };
            enabledUserRoles =
              lib.filterAttrs (_: roleCfg: roleCfg ? enable && roleCfg.enable)
              userRoles;
            hostRoleFilter = host.availableRoles or null;
            finalRoles = if hostRoleFilter == null then
              enabledUserRoles
            else
              lib.filterAttrs (roleName: _: lib.elem roleName hostRoleFilter)
              enabledUserRoles;
          in [{
            name = cfgName;
            value = inputs.home-manager.lib.homeManagerConfiguration {
              pkgs = makePkgs (host.system or "x86_64-linux");

              extraSpecialArgs = {
                inherit inputs inv sops-nix dotfilesSources disko;
                name = user;
                hostRoles =
                  if host ? availableRoles then host.availableRoles else null;
                pkgsUnstable = makePkgsUnstable (host.system or "x86_64-linux");
                currentHost = hostName;
                sopsConfigPath = ./.sops.yaml;
                networkSecretsPath = ./networks/secrets.yml;
              };

              modules = [
                ({ ... }: { roles = finalRoles; })

                inputs.snowman.homeModules.default
                ./home
                ./home/roles
                ./home/overrides
              ];
            };
          }]) (host.users or (builtins.attrNames inv.users)))
        (builtins.attrNames inv.hosts));
    };
}
