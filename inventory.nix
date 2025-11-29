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
      system = "x86_64-linux";
      mutableUsers = false;
      profiles = [ "qemu-guest" ];
      users = [ "bas" ];
      availableRoles = [ "bas" "ssh" ];
    };
  };

  dorkbones = {
    system = "x86_64-linux";
    mutableUsers = false;
    users = [ "bas" ];

    wifi = {
      mode = "static-wifi";
      networks = [ "home" ];
    };

    bootstrap.usb = {
      enable = true;
      label = "SNOWMANKEY";
      path = "/mnt/snowman";
      keyFile = "snowman.key";
      fsType = "vfat";
    };
  };

  rpi4 = {
    system = "aarch64-linux";
    mutableUsers = true;

    wifi = {
      mode = "static-wifi";
      # interface = "wlan0";
      # useDHCP = true;
      networks = [ "home" ];
    };

    secrets = {
      sopsFile = ./hosts/secrets/rpi4_secrets.yml;

      items = {
        wifi_ssid = {
          # path inside the YAML
          key = "wifi_ssid";
          # file owner/group/mode for the concrete secret file
          owner = "root";
          group = "root";
          mode = "0444";
        };

        wifi_password = {
          key = "wifi_password";
          owner = "root";
          group = "root";
          mode = "0444";
        };
      };
    };

    availableRoles = [ "bas" "secrets" "dev" "dotfiles" "ssh" ];

    users = [ "bas" ];
  };

  users = {
    bas = {
      uid = 1000;
      homeManaged = true;
      groups = [ "wheel" ];
      shell = "zsh";
      sshPubKeyFiles = [ ./users/keys/bas-arch.pub ]; # TODO: Add macbook's public key

      secrets = {
        sopsFile = ./users/secrets/bas_secrets.yml;
        keys = [ "password_hash" "test" "openai_api_key" ];
        userPasswordHashKey = "password_hash";
      };

      envFile = ./users/env/bas.nix;

      roles = {
        bas.enable = true;
        dev.enable = true;
        dev-heavy.enable = false;
        ssh.enable = true;
        secrets.enable = true;

        dotfiles = {
          enable = true;

          # Pinned mode (reproducible; uses flake input)
          # default = "username" # Defaults to `home.username` if omitted
          sourceKey = "bas"; # TODO: Remove line and above comment if working

          linkMap = {
            ".config/nvim" = "nvim/.config/nvim";
            ".zsh" = "zsh/.zsh";
            ".zshrc" = "zsh/.zshrc";
            "tmux" = "tmux/tmux";
            ".tmux.conf" = "tmux/.tmux.conf";
          };
        };
      };
    };
  };
}
