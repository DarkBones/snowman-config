{ osConfig, lib, ... }: {
  home.sessionPath = [
    "$HOME/.local/state/nix/profiles/home-manager/bin"
    "$HOME/.nix-profile/bin"
    "$HOME/.npm-global/bin"
    "$HOME/bin"
    "$HOME/.local/bin"
  ];

  home.sessionVariables = let
    maybe = name:
      if lib.hasAttr name osConfig.sops.secrets then
        osConfig.sops.secrets.${name}.path
      else
        "";
  in {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";
    FLAKE = "${osConfig.users.users.bas.home}/Developer/snowman";
    SNOWMAN_FLAKE = "${osConfig.users.users.bas.home}/snowman-config";

    OPENAI_API_KEY_SECRET_PATH = maybe "openai_api_key";
    GEMINI_API_KEY_SECRET_PATH = maybe "gemini_api_key";
    MAIN_KEY_SECRET_PATH = maybe "darkbones_dev_key";
  };
}
