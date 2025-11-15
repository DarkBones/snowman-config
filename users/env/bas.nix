{ osConfig, ... }: {
  home.sessionPath = [
    "$HOME/.local/state/nix/profiles/home-manager/bin"
    "$HOME/.nix-profile/bin"
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";
    FLAKE = "~/Developer/snowman";

    TEST_PATH = osConfig.sops.secrets.test.path;
  };
}
