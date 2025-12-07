{ osConfig, lib, ... }: {
  home.sessionPath = [
    "$HOME/.local/state/nix/profiles/home-manager/bin"
    "$HOME/.nix-profile/bin"
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
    FLAKE = "~/Developer/snowman";

    OPENAI_API_KEY_SECRET_PATH = maybe "openai_api_key";
    GEMINI_API_KEY_SECRET_PATH = maybe "gemini_api_key";
  };
}
