# snowman-config (Snowman Body)

This is **bas's personal Snowman body repo** — a NixOS configuration built on top of the
[Snowman framework](https://github.com/DarkBones/snowman).

---

## The Three-Repo Model

Snowman splits concerns across three repos. You will often need to read across all three:

| Repo | Role | Path on disk |
|------|------|-------------|
| `snowman-config` *(this repo)* | **Body** — hosts, users, secrets, inventory, wiring | `~/snowman-config` |
| `snowman` | **Base** — framework engine, core modules | `~/Developer/snowman` |
| `dotfiles` | **Head** — editor, shell, and tool configs | `~/Developer/dotfiles` |

When making changes, be aware which layer owns what. Never edit the Snowman engine
directly unless the task explicitly requires it. Dotfiles changes belong in the dotfiles
repo, not here.

---

## This Repo's Structure

```
snowman-config/
├── flake.nix                  # Main flake — wires inputs and builds nixosConfigurations
├── flake.lock
├── inventory.nix              # Single source of truth: hosts, users, roles, networks
├── .sops.yaml                 # Age key recipients for secret encryption
│
├── hosts/                     # Per-host NixOS configs and hardware configs
│   ├── dorkbones.nix          # Main desktop (Ryzen 7 7800X3D, RTX 4080 Super, NixOS)
│   ├── dorkbones/
│   │   └── boot.nix           # Custom GRUB + cyberre theme
│   ├── dorkbones-hardware-configuration.nix
│   ├── rpi4.nix               # Raspberry Pi 4 (home server, HA, pihole, taskserver)
│   ├── rpi4-hardware-configuration.nix
│   └── secrets/               # Per-host sops-encrypted secrets
│
├── modules/                   # NixOS modules loaded by the Snowman engine
│   ├── nvidia.nix             # NVIDIA driver config (RTX 4080 Super)
│   ├── gaming.nix             # Steam, gamescope, wine, lutris
│   ├── hyprland-host.nix      # System-level Hyprland setup
│   ├── login-hyprlock.nix     # greetd + regreet (replaces SDDM)
│   ├── media.nix              # Sonarr, Radarr, SABnzbd, ACL management
│   ├── plex.nix               # Plex Media Server
│   ├── audiobookshelf.nix     # Audiobook server
│   ├── ollama.nix             # Local LLM inference (pinned v0.17.7)
│   ├── openwebui.nix          # Open WebUI frontend for Ollama
│   ├── vpn.nix                # PIA VPN via NetworkManager + OpenVPN
│   ├── home-assistant.nix     # Home Assistant (runs on rpi4)
│   ├── pihole.nix             # Pi-hole DNS (runs on rpi4)
│   ├── taskserver.nix         # Taskwarrior sync server (runs on rpi4)
│   └── stylix.nix             # Stylix theming (GTK/Qt disabled, custom theme)
│
├── home/                      # Home Manager configuration (user environments)
│   ├── default.nix
│   ├── roles/                 # Reusable user roles (each maps to a home.nix feature set)
│   │   ├── bas.nix            # Core CLI tools (bat, btop, eza, taskwarrior, tmux…)
│   │   ├── desktop.nix        # GUI apps (ghostty, zen-browser, spotify, vlc…)
│   │   ├── dev.nix            # Dev tools (neovim, lazygit, docker, fzf, node…)
│   │   ├── dev-heavy.nix      # Heavy dev extras (starship, aichat, codex)
│   │   ├── gaming.nix         # Gaming home pkgs (mangohud, piper, openrgb…)
│   │   ├── gaming-mods.nix    # Heroic launcher
│   │   ├── hyprland.nix       # Hyprland home config (waybar, wofi, hyprlock…)
│   │   ├── lsp.nix            # Language servers and formatters
│   │   ├── macos-wm.nix       # yabai + skhd + karabiner (macOS only)
│   │   └── dotfiles.nix       # Dotfiles wiring (handled by Snowman engine)
│   ├── overrides/             # One-off home-manager configs that don't fit a role
│   │   ├── awww-rotate.nix    # Wallpaper rotation timer
│   │   ├── dev-gtk.nix        # GTK theme (catppuccin-frappe-blue + darkling CSS)
│   │   ├── dev-dotfiles.nix   # Dotfiles symlinking (dev vs prod mode)
│   │   ├── dotfiles-root.nix  # Resolves dotfiles path for dev/prod
│   │   ├── polkit-agent.nix   # Polkit GNOME agent as a user service
│   │   ├── thunar-default-view.nix
│   │   ├── wayscriber.nix
│   │   └── zen.nix            # Zen browser GTK CSS
│   └── pkgs/
│       └── neovim.nix         # Neovim wrapper with PATH for Codeium/Mason
│
├── users/
│   ├── keys/                  # SSH public keys for authorized_keys
│   ├── secrets/               # sops-encrypted user secrets (passwords, API keys)
│   ├── env/bas/               # User session variables (editor, flake paths, secret paths)
│   └── faces/                 # User avatar images
│
├── networks/
│   └── secrets.yml            # sops-encrypted Wi-Fi and VPN credentials
│
└── assets/
    └── patterns/grain.png     # Stylix base image
```

---

## Key Hosts

### `dorkbones` (primary workstation)

- **Hardware:** MSI MAG B650 TOMAHAWK WIFI, AMD Ryzen 7 7800X3D, RTX 4080 Super (16 GB), 32 GB RAM, 2 TB NVMe
- **OS:** NixOS 25.11 (Xantusia), kernel 6.12.66
- **Display:** 4K 27" @ 60 Hz
- **WM:** Hyprland (Wayland)
- **Boot:** Custom GRUB with cyberre theme, EFI
- **Users:** `bas` (primary), `ha` (system user for Home Assistant automation)
- **Services running locally:** Plex, Sonarr, Radarr, SABnzbd, Audiobookshelf, Ollama, Open WebUI, nginx (reverse proxy), Tailscale, PIA VPN

### `rpi4` (home server, aarch64)

- **Services:** Home Assistant, Pi-hole, Taskwarrior sync server, Tailscale

---

## Inventory-Driven Configuration

`inventory.nix` is the single source of truth. The Snowman engine reads it to:

- Create NixOS user accounts and SSH authorized keys
- Apply per-host role filters (`availableRoles`)
- Wire Home Manager roles per user
- Configure networking (Wi-Fi, NetworkManager profiles)
- Manage sops secrets

Do not create standalone NixOS user definitions outside of inventory unless there is a strong reason. Prefer adding to `inventory.nix` first.

---

## Secrets Management

Secrets use **sops + age**. The `.sops.yaml` file defines which age keys can decrypt which files.

- **User secrets:** `users/secrets/bas_secrets.yml` — password hash, API keys
- **Network secrets:** `networks/secrets.yml` — Wi-Fi PSK, PIA VPN credentials
- **Host secrets:** `hosts/secrets/` — host-specific items

To edit a secret file: `sops <file>`. Never commit plaintext secrets.

---

## Dev vs Prod Dotfiles Mode

Dotfiles can be loaded in two modes, switched with the `snowman` CLI:

- **`snowman prod`** — pure rebuild; dotfiles come from the pinned `bas-dotfiles` flake input (Nix store, immutable)
- **`snowman dev`** — impure rebuild; dotfiles are live symlinks into `~/Developer/dotfiles` (editable without rebuild)

Check current mode: `snowman status`

---

## Rebuild Commands

```bash
# Rebuild dorkbones (from dorkbones itself)
snowman prod       # or: sudo nixos-rebuild switch --flake ~/snowman-config#dorkbones

# Rebuild in dev mode (mutable dotfiles)
snowman dev

# Update all flake inputs
snowman update

# Show what would change without applying
snowman diff

# Garbage collect (keep last 10 generations)
snowman gc

# Deploy rpi4 remotely
nix run nixpkgs#nixos-rebuild -- switch \
  --flake ~/snowman-config#rpi4 \
  --target-host bas@rpi4 \
  --use-remote-sudo
```

---

## Snowman Engine Reference

The engine lives at `~/Developer/snowman` and is consumed as a flake input. When working
on framework-level changes, check that path. The engine provides:

- `nixosModules.default` — core NixOS modules (users, hardware, secrets, networking, dotfiles)
- `homeModules.default` — core Home Manager modules (ssh, dotfiles, secrets roles)

If this repo's `flake.nix` needs to point at a local engine build during development:

```nix
# In flake.nix inputs:
snowman.url = "path:/home/bas/Developer/snowman";
```

Revert to `github:DarkBones/snowman` when done.

---

## Dotfiles Reference

The dotfiles repo at `~/Developer/dotfiles` contains the actual config files that get
symlinked into `$HOME`. The `linkMap` in `inventory.nix` under `roles.dotfiles` defines
what gets linked where. Key directories:

- `nvim/` — Neovim config
- `hyprland/` — Hyprland, hypridle, hyprlock configs
- `waybar/`, `wofi/`, `swaync/` — bar, launcher, notifications
- `zsh/` — shell config
- `tmux/`, `tmuxinator/` — terminal multiplexer
- `wallpapers/` — wallpaper images for awww rotation

---

## Style Conventions

- All NixOS modules go in `modules/` and are auto-imported by the Snowman engine's `default.nix`
- All Home Manager roles go in `home/roles/` and are auto-imported
- All Home Manager one-off overrides go in `home/overrides/` and are auto-imported
- Use `pkgsUnstable` (passed via `specialArgs`) for packages that need to track unstable
- Prefer `lib.mkIf` guards over top-level conditionals
- Keep host-specific logic in `hosts/<hostname>.nix`, not in modules
- Modules should be additive and guarded; avoid `lib.mkForce` unless overriding a conflicting default
