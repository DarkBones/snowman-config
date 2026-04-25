{ pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  environment.systemPackages = with pkgs; [
    papirus-icon-theme
    colloid-icon-theme
    bibata-cursors
    xfce.xfce4-settings
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # --- Audio (Pipewire) ---
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber = {
      enable = true;
      extraConfig."10-bluetooth-headphones" = {
        "wireplumber.settings" = {
          # Keep Bluetooth headphones in high-quality A2DP mode when apps
          # open a recording stream. Capture should use a real microphone.
          "bluetooth.autoswitch-to-headset-profile" = false;
        };
      };
    };
  };

  # --- Thunar (File Manager) ---
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-volman
    ];
  };
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # --- Fonts ---
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    font-awesome
    crimson-pro
    inter
    nerd-fonts.jetbrains-mono
  ];
}
