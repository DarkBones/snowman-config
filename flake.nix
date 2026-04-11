{
  description = "DarkBones' Snowman Body";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-23_11.url = "github:NixOS/nixpkgs/nixos-23.11";
    # nixpkgs master for Darwin - has LLVM 19 which supports macOS 26
    nixpkgs-darwin.url = "github:NixOS/nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Master home-manager for Darwin (macOS 26 support with nixpkgs master)
    home-manager-darwin.url = "github:nix-community/home-manager";
    home-manager-darwin.inputs.nixpkgs.follows = "nixpkgs-darwin";

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

      # This is YOUR inventory, not snowman's
      inv = import ./inventory.nix;

      # This is you map your dotfile inputs
      dotfilesSources = { bas = inputs.bas-dotfiles; };

      # Standard Snowman setup
      llvmDarwinNoCheckOverlay = final: prev:
        lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
          llvmPackages_16 = prev.llvmPackages_16.overrideScope' (llvmFinal:
            llvmPrev: {
              llvm = llvmPrev.llvm.overrideAttrs (_old: {
                doCheck = false;
                doInstallCheck = false;
              });
            });
        };

      # Use nixpkgs master for Darwin (has LLVM 19 for macOS 26 support), stable for Linux
      makePkgs = system:
        let
          isDarwin = lib.hasSuffix "-darwin" system;
          selectedNixpkgs = if isDarwin then inputs.nixpkgs-darwin else nixpkgs;
        in import selectedNixpkgs {
          inherit system;
          config.allowUnfree = true;
          config.permittedInsecurePackages = [
            "python3.13-pypdf2-3.0.1"
          ];
          overlays = [ llvmDarwinNoCheckOverlay ];
        };
      makePkgsUnstable = system:
        import inputs.nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
          config.permittedInsecurePackages = [
            "python3.13-pypdf2-3.0.1"
          ];
          overlays = [ llvmDarwinNoCheckOverlay ];
        };

      mkNixosSpecialArgs = name: attrs: {
        inherit inputs home-manager inv sops-nix dotfilesSources disko;
        pkgsUnstable = makePkgsUnstable attrs.system;
        modulesPath = "${nixpkgs}/nixos/modules";
        currentHost = name;
        sopsConfigPath = ./.sops.yaml;
        networkSecretsPath = ./networks/secrets.yml;
        # extraHomeImports = [ ./home/roles ./home/overrides ];
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
                # Snowman's inventory path owns integrated HM user assembly.
                # This layer only overrides NixOS-integrated HM activation.
                users = lib.genAttrs managedUsers (_: {
                  systemd.user.startServices = lib.mkForce true;
                });
              };
            })

            # ./modules/snowman.nix

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
                  ❌ Snowman: Hardware configuration missing for host "${name}"
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

      # Only hosts that already have a committed hardware configuration.
      # This keeps `nix flake check` from failing on machines that aren't NixOS
      # (or on hosts you haven't imported hardware for yet).
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
            system = host.system or "x86_64-linux";
            isDarwin = lib.hasSuffix "-darwin" system;
            # Use master home-manager for Darwin (macOS 26 support)
            hm = if isDarwin then inputs.home-manager-darwin else inputs.home-manager;
          in [{
            name = cfgName;
            value = hm.lib.homeManagerConfiguration {
              pkgs = makePkgs system;

              extraSpecialArgs = {
                inherit inputs inv sops-nix dotfilesSources disko;
                name = user;
                hostRoles =
                  if host ? availableRoles then host.availableRoles else null;
                pkgsUnstable = makePkgsUnstable system;
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
