{ pkgs, lib, ... }:
{
  imports = [
    ./rpi4-hardware-configuration.nix
    ../modules/home-assistant.nix
  ];

  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    kernelParams = [ "ipv6.disable=1" ];
  };

  time.timeZone = "Europe/Berlin";

  networking = {
    enableIPv6 = false;

    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ]; # TODO: Quad 9

    firewall = {
      enable = true;
      allowPing = true;

      # LAN access: SSH + Home Assistant
      allowedTCPPorts = [
        22
        8123
      ];

      # LAN discovery
      allowedUDPPorts = [ 5353 ];

      checkReversePath = "loose";

      # Trust LAN + Tailscale interfaces
      trustedInterfaces = [
        "wlan0"
        "tailscale0"
      ];
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

          pyrate-limiter = python-prev.pyrate-limiter.overridePythonAttrs (oldAttrs: {
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
