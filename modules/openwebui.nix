{ lib, pkgs, ... }: {
  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 4080;
  };
}
