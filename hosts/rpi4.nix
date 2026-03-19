{ pkgs, lib, ... }: {
  imports = [ ./rpi4-hardware-configuration.nix ../modules/home-assistant.nix ];

  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  time.timeZone = "Europe/Berlin";

  networking = {
    enableIPv6 = true;

    useDHCP = lib.mkForce false;
    interfaces.end0.useDHCP = true;
    interfaces.wlan0.useDHCP = false;

    nameservers =
      [ "1.1.1.1" "8.8.8.8" "2606:4700:4700::1111" "2606:4700:4700::1001" ];

    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [ 22 8123 ];
      allowedUDPPorts = [ 5353 ];
      checkReversePath = "loose";

      trustedInterfaces = [ "end0" "tailscale0" ];
    };

    wireless.enable = lib.mkForce false;
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  nixpkgs.overlays = [
    (final: prev: {
      # Fix timing-sensitive python packages that fail on Pi 4 hardware
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (python-final: python-prev: {

          pyrate-limiter = python-prev.pyrate-limiter.overridePythonAttrs
            (oldAttrs: {
              # Skip tests that depend on high-precision timing/latency
              doCheck = false;
            });

          psycopg = python-prev.psycopg.overridePythonAttrs (oldAttrs: {
            # Skip tests because the temporary Postgres DB fails to start in time
            doCheck = false;
          });

        })
      ];
    })
  ];
}
