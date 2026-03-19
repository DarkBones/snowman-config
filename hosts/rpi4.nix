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

    nameservers =
      [ "1.1.1.1" "8.8.8.8" "2606:4700:4700::1111" "2606:4700:4700::1001" ];

    firewall = {
      enable = true;
      allowPing = true;

      # LAN access: SSH + Home Assistant
      allowedTCPPorts = [ 22 8123 ];

      # LAN discovery
      allowedUDPPorts = [ 5353 ];

      checkReversePath = "loose";

      # Trust LAN + Tailscale interfaces
      trustedInterfaces = [ "wlan0" "tailscale0" ];
    };
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
