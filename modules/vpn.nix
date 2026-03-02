{ pkgs, ... }: {
  networking.networkmanager.enable = true;

  networking.networkmanager.plugins = with pkgs; [ networkmanager-openvpn ];

  environment.systemPackages = with pkgs; [ openvpn ];

  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
  };
}
