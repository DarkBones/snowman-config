{ config, ... }: {
  nixpkgs.config.allowUnfree = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  boot.initrd.kernelModules =
    [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  boot.extraModulePackages = [ config.boot.kernelPackages.nvidiaPackages.beta ];

  boot.kernelParams = [ "nvidia_drm.modeset=1" "nvidia_drm.fbdev=1" ];

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    XDG_SESSION_TYPE = "wayland";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  hardware.nvidia = {
    modesetting.enable = true;

    # Required for 40-series stability and proper resume/start.
    powerManagement.enable = true;
    powerManagement.finegrained = false;

    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    nvidiaSettings = true;
  };
}
