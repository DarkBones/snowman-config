{
  description = "A new Snowman user configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowman = {
      url = "github:DarkBones/snowman/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add your pinned dotfiles here, e.g.:
    bas-dotfiles = {
      url = "github:DarkBones/dotfiles";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, home-manager, sops-nix, snowman, disko, ... }@inputs:
    let
      lib = nixpkgs.lib;

      # This is YOUR inventory, not snowman's
      inv = import ./inventory.nix;

      # This is you map your dotfile inputs
      dotfilesSources = { bas = inputs.bas-dotfiles; };

      # Standard Snowman setup
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
        inherit home-manager inv sops-nix dotfilesSources disko;
        pkgsUnstable = makePkgsUnstable attrs.system;
        modulesPath = "${nixpkgs}/nixos/modules";
        currentHost = name;

        extraHomeImports = [ ./home/roles ];
      };

      mkHost = name: attrs:
        let hwFile = ./hosts/${name}-hardware-configuration.nix;
        in lib.nixosSystem {
          system = attrs.system;
          specialArgs = mkNixosSpecialArgs name attrs;
          modules = [
            # Snowman engine
            snowman.nixosModules.default

            # Home Manager integration
            home-manager.nixosModules.home-manager

            # Per-host wrapper that:
            #  - imports the hardware config
            #  - asserts that it exists
            ({ lib, ... }: {
              imports = lib.optional (builtins.pathExists hwFile) hwFile;

              assertions = [{
                assertion = builtins.pathExists hwFile;
                message = ''
                  ❌ Snowman: Hardware configuration missing for host "${name}".

                  Expected file:
                    hosts/${name}-hardware-configuration.nix

                  Fix:
                    On the machine this NixOS install is running on, execute:

                      ./bin/snowman-import-hardware ${name}

                    This will copy /etc/nixos/hardware-configuration.nix
                    into the correct location in your Snowman config repo.

                    Then re-run:

                      sudo nixos-rebuild switch --flake .#${name}
                '';
              }];
            })
          ] ++ (attrs.extraModules or [ ]);
        };
    in { nixosConfigurations = lib.mapAttrs mkHost inv.hosts; };
}
