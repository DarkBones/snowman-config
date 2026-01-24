{ pkgs, ... }: {
  programs.hyprland.enable = true;

  environment.systemPackages = with pkgs; [
    papirus-icon-theme
    colloid-icon-theme
    xfce.xfce4-settings
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.displayManager = {
    defaultSession = "hyprland";
    sddm = {
      enable = true;
      wayland.enable = true;
    };
  };

  # --- Audio (Pipewire) ---
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # --- Thunar (File Manager) ---
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [ thunar-archive-plugin thunar-volman ];
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
