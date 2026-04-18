{ lib, config, ... }:
let
  cfg = config.snowman.reverseProxy;
in
{
  options.snowman.reverseProxy.enable = lib.mkEnableOption "local nginx reverse proxy capability";

  # Service modules may declare local nginx virtual hosts, but hosts that want
  # them must import this module and enable snowman.reverseProxy.
  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
    };
  };
}
