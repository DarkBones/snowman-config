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
      users = [ "bas" ];
      hardware.boot.firmware = "efi";

      extraModules = [
        ./hosts/dorkbones.nix
        ./hosts/dorkbones/boot.nix
        ./modules/hyprland-host.nix
        ./modules/nvidia.nix
      ];

      wifi = { mode = "roaming"; };

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
      sshPubKeyFiles = [
        ./users/keys/bas-arch.pub
        ./users/keys/papershift-laptop.pub
      ]; # TODO: Add macbook's public key

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
        dev-heavy.enable = false;
        hyprland.enable = true;
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
            ".config/autostart" = "hyprland/.config/autostart";
            ".config/hypr" = "hyprland/.config/hypr";
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
            ".config/waybar" = "waybar/.config/waybar";
            ".config/wofi" = "wofi/.config/wofi";
            # TODO: zen
          };
        };
      };
    };
  };
}
