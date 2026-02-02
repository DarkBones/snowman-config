{ osConfig, lib, ... }:
let
  maybe = name:
    if lib.hasAttr name osConfig.sops.secrets then
      osConfig.sops.secrets.${name}.path
    else
      "";

  vars = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";

    FLAKE = "${osConfig.users.users.bas.home}/Developer/snowman";
    SNOWMAN_FLAKE = "${osConfig.users.users.bas.home}/snowman-config";

    OPENAI_API_KEY_SECRET_PATH = maybe "openai_api_key";
    GEMINI_API_KEY_SECRET_PATH = maybe "gemini_api_key";
    NZB_GEEK_USERNAME_SECRET_PATH = maybe "nzb_geek_username";
    NZB_GEEK_KEY_SECRET_PATH = maybe "nzb_geek_key";
  };
in {
  home.sessionVariables = vars;

  systemd.user.sessionVariables = vars;
}
