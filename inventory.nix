rec {
  release = "25.05";

  networks = {
    home = {
      ssid = "frizzlesnizzle";
      passwordSecret = "home/password";
    };
  };

  hosts = {
    vm = {
      hostname = "vm-snowman";
      system = "x86_64-linux";
      mutableUsers = false;
      profiles = [ "qemu-guest" ];
      users = [ "bas" ];
      availableRoles = [ "bas" "ssh" ];
    };

    dorkbones = {
      hostname = "dorkbones";
      system = "x86_64-linux";
      mutableUsers = false;
      users = [ "bas" "ha" ];
      hardware.boot.firmware = "efi";
      compatibility = true;

      extraModules = [
        ./hosts/dorkbones.nix
        ./hosts/dorkbones/boot.nix
        ./modules/hyprland-host.nix
        ./modules/nvidia.nix
        ./modules/gaming.nix
        ./modules/openwebui.nix
        ({ ... }: { roles.gaming.enable = true; })
      ];

      wifi = {
        mode = "roaming";
        networks = [ "home" ];
      };

      bootstrap.usb = {
        enable = true;
        label = "SNOWMAN_KEY";
        path = "/mnt/snowman";
        keyFile = "snowman.key";
        fsType = "vfat";
      };
    };

    rpi4 = {
      hostname = "rpi4";
      system = "aarch64-linux";
      mutableUsers = false;
      hardware.boot.firmware = "raspberry-pi";
      compatibility = true;

      wifi = {
        mode = "roaming";
        networks = [ "home" ];
      };

      availableRoles = [ "bas" "secrets" "dev" "dotfiles" "ssh" ];
      users = [ "bas" ];

      extraModules = [ ./hosts/rpi4.nix ./modules/home-assistant.nix ];
    };
  };

  users = {
    bas = {
      uid = 1000;
      homeManaged = true;
      groups = [ "wheel" ];
      shell = "zsh";
      face = ./users/faces/bas.jpg;
      sshPubKeyFiles = [
        ./users/keys/bas-arch.pub
        ./users/keys/papershift-laptop.pub
        ./users/keys/bas-mbp.pub
        ./users/keys/bas-dorkbones.pub
        ./users/keys/home-assistant-pi.pub
        ./users/keys/ha-rpi.pub
      ];

      # initialPassword = "snowman";
      secrets = {
        sopsFile = ./users/secrets/bas_secrets.yml;
        keys = [ "password_hash" "openai_api_key" "gemini_api_key" ];
        userPasswordHashKey = "password_hash";
      };

      envFile = ./users/env/bas;

      roles = {
        bas.enable = true;
        desktop.enable = true;
        dev.enable = true;
        dev-heavy.enable = true;
        gaming.enable = true;
        hyprland.enable = true;
        lsp.enable = true;
        secrets.enable = true;
        ssh.enable = true;

        dotfiles = {
          enable = true;
          dir = "Developer/dotfiles";

          linkMap = {
            "bin" = "bin/bin";
            ".fzf" = "fzf/.fzf";
            ".config/ghostty" = "ghostty/.config/ghostty";
            ".gitconfig" = "git/.gitconfig";
            # ".config/autostart" = "hyprland/.config/autostart";
            ".config/hypr" = "hyprland/.config/hypr";
            ".config/swaync" = "swaync/.config/swaync";
            ".config/MangoHud" = "mangohud/.config/MangoHud";
            ".config/nvim" = "nvim/.config/nvim";
            ".config/starship.toml" = "starship/.config/starship.toml";
            ".zshrc" = "zsh/.zshrc";
            ".zsh" = "zsh/.zsh";
            # ".config/systemd" = "systemd/.config/systemd"; <- TODO: Translate services to home-manager configs (the files are owned by root)
            ".tmux.conf" = "tmux/.tmux.conf";
            "tmux" = "tmux/tmux";
            ".config/tmuxinator" = "tmuxinator/.config/tmuxinator";
            "wallpapers" = "wallpapers/wallpapers";
            "darkling" = "darkling/darkling";
            "lockscreens" = "lockscreens/lockscreens";
            ".config/waybar" = "waybar/.config/waybar";
            ".config/wofi" = "wofi/.config/wofi";
          };
        };
      };
    };

    ha = {
      uid = 1100;
      groups = [ ];
      shell = "bash";
      isSystemUser = true;

      sshPubKeyFiles = [ ./users/keys/ha-rpi.pub ];
      roles = { };
    };
  };
}
