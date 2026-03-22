{ osConfig, lib, pkgs, ... }:
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
    OPENROUTER_API_KEY_SECRET_PATH = maybe "openrouter_api_key";
    ANTHROPIC_API_KEY_SECRET_PATH = maybe "anthropic_api_key";
    ELEVEN_LABS_API_KEY_SECRET_PATH = maybe "eleven_labs_api_key";
    GEMINI_API_KEY_SECRET_PATH = maybe "gemini_api_key";
    OPENCLAW_GATEWAY_TOKEN_SECRET_PATH = maybe "openclaw_gateway_token";
    OPENCLAW_TELEGRAM_BOT_TOKEN_SECRET_PATH =
      maybe "openclaw_telegram_bot_token";
    HA_TOKEN_SECRET_PATH = maybe "home_assistant_long_lived_token";
    NZB_GEEK_USERNAME_SECRET_PATH = maybe "nzb_geek_username";
    NZB_GEEK_KEY_SECRET_PATH = maybe "nzb_geek_key";
    HA_TOKEN_SECRET_PATH = maybe "home_assistant_long_lived_token";
  };
in {
  home.sessionVariables = vars;
  systemd.user.sessionVariables = lib.mkIf pkgs.stdenv.isLinux vars;

  home.activation.installHomeAssistantToken =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      token_path="${vars.HA_TOKEN_SECRET_PATH}"
      target_dir="$HOME/.config/home-assistant"
      target_file="$target_dir/ha-token"

      if [ -n "$token_path" ] && [ -r "$token_path" ]; then
        mkdir -p "$target_dir"
        cp "$token_path" "$target_file"
        chmod 600 "$target_file"
      fi
    '';
}
