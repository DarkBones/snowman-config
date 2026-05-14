rec {
  release = "25.05";

  networks = {
    home = {
      ssid = "home/ssid";
      passwordSecret = "home/password";
    };
    s10 = {
      ssid = "s10/ssid";
      passwordSecret = "s10/password";
    };
  };

  hosts = {
    vm = {
      hostname = "vm-snowman";
      system = "x86_64-linux";
      mutableUsers = false;
      profiles = [ "qemu-guest" ];
      users = [ "bas" ];
      availableRoles = [
        "bas"
        "ssh"
      ];
    };

    dorkbones = {
      hostname = "dorkbones";
      system = "x86_64-linux";
      mutableUsers = false;
      users = [
        "bas"
        "ha"
        "notify"
        "speak"
      ];
      hardware.boot.firmware = "efi";
      compatibility = true;

      extraModules = [
        ./hosts/dorkbones.nix
        ./hosts/dorkbones/boot.nix
        ./modules/reverse-proxy.nix
        ./modules/linux-workstation-base.nix
        ./modules/tailscale.nix
        ./modules/desktop-notify-ssh.nix
        ./modules/desktop-speak-ssh.nix
        ./modules/openclaw.nix
        ./modules/openclaw-proxy.nix
        ./modules/hyprland-host.nix
        ./modules/nvidia.nix
        ./modules/gaming.nix
        ./modules/alvr.nix
        ./modules/openwebui.nix
        ./modules/searxng.nix
        ./modules/ollama.nix
        ./modules/login-hyprlock.nix
        ./modules/media.nix
        ./modules/plex.nix
        ./modules/audiobookshelf.nix
        ./modules/vpn.nix
        (
          { ... }:
          {
            roles.gaming.enable = true;
            roles.alvr.enable = true;
            services.openclawLocal.enable = true;
            services.openclawLocal.proactiveResearch.enable = true;
            snowman.desktopNotifySsh.enable = true;
            snowman.desktopSpeakSsh.enable = true;
          }
        )
      ];

      availableRoles = [
        "bas"
        "desktop"
        "dev"
        "dev-heavy"
        "gaming"
        "gaming-mods"
        "hyprland"
        "lsp"
        "macos-wm"
        "secrets"
        "searxng"
        "snowman"
        "ssh"
        "taskwarrior"
        "openclaw"
        "video-editing"
        "dotfiles"
      ];

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
      network.home = {
        ipv4 = "192.168.178.63";
        aliases = [
          "ha"
          "pihole"
        ];
      };

      availableRoles = [
        "bas"
        "secrets"
        "dev"
        "dotfiles"
        "ssh"
        "taskwarrior"
      ];
      users = [ "bas" ];

      extraModules = [
        ./hosts/rpi4.nix
        ./modules/tailscale.nix
        ./modules/home-assistant.nix
        ./modules/pihole.nix
        ./modules/taskserver.nix
      ];
    };

    mbp = {
      hostname = "mbp";
      system = "aarch64-darwin";
      users = [ "bas" ];

      availableRoles = [
        "bas"
        "desktop"
        "dev"
        "dev-heavy"
        "lsp"
        "dotfiles"
        "searxng"
        "snowman"
        "ssh"
        "taskwarrior"
        "macos-wm"
      ];

      extraModules = [ ];
    };

    papershift-mbp = {
      hostname = "papershift-mbp";
      system = "aarch64-darwin";
      users = [ "bas" ];

      localAccountNames = {
        bas = "Bas";
      };

      availableRoles = [
        "bas"
        "desktop"
        "dev"
        "dev-heavy"
        "lsp"
        "dotfiles"
        "searxng"
        "snowman"
        "ssh"
        "taskwarrior"
        "papershift"
        "macos-wm"
      ];

      extraHomeModules = [
        ./home/modules/tailscale.nix
      ];
    };
  };

  users = {
    bas = {
      uid = 1000;
      homeManaged = true;
      groups = [
        "wheel"
        "media"
        "adbusers"
        "networkmanager"
      ];
      shell = "zsh";
      face = ./users/faces/bas.jpg;
      sshPubKeyFiles = [
        ./users/keys/papershift-laptop.pub
        ./users/keys/bas-mbp.pub
        ./users/keys/bas-dorkbones.pub
        ./users/keys/home-assistant-pi.pub
        ./users/keys/ha-rpi.pub
      ];

      # initialPassword = "snowman";
      secrets = {
        sopsFile = ./users/secrets/bas_secrets.yml;
        keys = [
          "password_hash"
          "openai_api_key"
          "openrouter_api_key"
          "anthropic_api_key"
          "elevenlabs_api_key"
          "gemini_api_key"
          "youtube_api_key"
          "openclaw_gateway_token"
          "openclaw_telegram_bot_token"
          "home_assistant_long_lived_token"
          "taskwarrior_sync_encryption_secret"
          "taskwarrior_sync_client_id"
          "nzb_geek_username"
          "nzb_geek_key"
        ];
        userPasswordHashKey = "password_hash";
      };

      envFile = ./users/env/bas;

      roles = {
        bas.enable = true;
        desktop.enable = true;
        dev.enable = true;
        dev-heavy.enable = true;
        gaming.enable = true;
        gaming-mods.enable = true;
        hyprland.enable = true;
        lsp.enable = true;
        macos-wm.enable = true;
        papershift.enable = true;
        secrets.enable = true;
        searxng.enable = true;
        snowman.enable = true;
        ssh.enable = true;
        taskwarrior.enable = true;
        openclaw.enable = true;
        video-editing = {
          enable = true;

          # If this file exists locally, the role installs DaVinci Resolve.
          # If it does not exist, the role stays enabled and emits a warning.
          # Example:
          # davinciResolve = {
          #   localZipPath = "/home/bas/.local/share/installers/DaVinci_Resolve_20.3.2_Linux.zip";
          # };
        };

        dotfiles = {
          enable = true;
          dir = "~/Developer/dotfiles";

          linkMap = {
            ".config/ghostty" = "ghostty/.config/ghostty";
            ".config/darkling" = "darkling/darkling";
            ".config/fastfetch" = "fastfetch/.config/fastfetch";
            ".config/hypr" = "hyprland/.config/hypr";
            ".config/karabiner" = "karabiner/.config/karabiner";
            ".config/MangoHud" = "mangohud/.config/MangoHud";
            ".config/nvim" = "nvim/.config/nvim";
            ".config/opencode.json" = "opencode/.config/opencode.json";
            ".config/raycast" = "raycast/.config/raycast";
            ".config/skhd" = "skhd/.config/skhd";
            ".config/sketchybar" = "sketchybar/.config/sketchybar";
            ".config/starship.toml" = "starship/.config/starship.toml";
            ".config/swaync" = "swaync/.config/swaync";
            ".config/tmuxinator" = "tmuxinator/.config/tmuxinator";
            ".config/waybar" = "waybar/.config/waybar";
            ".config/wofi" = "wofi/.config/wofi";
            ".config/yabai" = "yabai/.config/yabai";
            ".fzf" = "fzf/.fzf";
            ".gitconfig" = "git/.gitconfig";
            ".tmux.conf" = "tmux/.tmux.conf";
            ".zsh" = "zsh/.zsh";
            ".zshrc" = "zsh/.zshrc";
            "bin" = "bin/bin";
            "darkling" = "darkling/darkling";
            "lockscreens" = "lockscreens/lockscreens";
            "tmux" = "tmux/tmux";
            "wallpapers" = "wallpapers/wallpapers";
            # ".config/autostart" = "hyprland/.config/autostart";
            # ".config/systemd" = "systemd/.config/systemd"; <- TODO: Translate services to home-manager configs (the files are owned by root)
            ".zen/profiles.ini" = "zen/profiles.ini";
            ".zen/bas/user.js" = "zen/shared/user.js";
            ".zen/bas/chrome" = "zen/shared/chrome";
            ".zen/bas/zen-keyboard-shortcuts.json" = "zen/shared/zen-keyboard-shortcuts.json";
            ".zen/bas/zen-themes.json" = "zen/shared/zen-themes.json";
            ".zen/private/user.js" = "zen/shared/user.js";
            ".zen/private/chrome" = "zen/shared/chrome";
            ".zen/private/zen-keyboard-shortcuts.json" = "zen/shared/zen-keyboard-shortcuts.json";
            ".zen/private/zen-themes.json" = "zen/shared/zen-themes.json";
          };
        };
      };
    };

    ha = {
      uid = 1100;
      groups = [ ];
      shell = "bash";
      isSystemUser = true;

      sshPubKeyFiles = [
        ./users/keys/ha-rpi.pub
        ./users/keys/bas-dorkbones.pub
      ];
      roles = { };
    };

    notify = {
      uid = 1101;
      groups = [ ];
      shell = "bash";
      isSystemUser = true;

      sshPubKeyFiles = [
        ./users/keys/papershift-laptop.pub
        ./users/keys/bas-mbp.pub
        ./users/keys/bas-dorkbones.pub
        ./users/keys/home-assistant-pi.pub
        ./users/keys/ha-rpi.pub
      ];
      roles = { };
    };

    speak = {
      uid = 1102;
      groups = [ ];
      shell = "bash";
      isSystemUser = true;

      sshPubKeyFiles = [
        ./users/keys/bas-dorkbones.pub
        ./users/keys/home-assistant-pi.pub
        ./users/keys/ha-rpi.pub
      ];
      roles = { };
    };
  };
}
