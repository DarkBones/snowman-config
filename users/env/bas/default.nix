{ osConfig ? null, lib, pkgs, config, ... }:
let
  # Fallback to Home Manager's own sops configuration if osConfig (NixOS) is missing
  sopsSecrets =
    if osConfig != null then
      osConfig.sops.secrets
    else if (config ? sops && config.sops ? secrets) then
      config.sops.secrets
    else
      { };

  # Always use the Home Manager config for home directory to handle mapped usernames correctly
  userHome = config.home.homeDirectory;

  maybe = name:
    if lib.hasAttr name sopsSecrets then
      sopsSecrets.${name}.path
    else
      "";

  vars = rec {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";

    SNOWMAN_BASE_PATH = "${userHome}/Developer/snowman";
    SNOWMAN_CONFIG_PATH = "${userHome}/snowman-config";

    # Used by the `snowman` helper to override which body repo flake it targets.
    SNOWMAN_FLAKE = SNOWMAN_CONFIG_PATH;

    OPENAI_API_KEY_SECRET_PATH = maybe "openai_api_key";
    OPENROUTER_API_KEY_SECRET_PATH = maybe "openrouter_api_key";
    ANTHROPIC_API_KEY_SECRET_PATH = maybe "anthropic_api_key";
    ELEVENLABS_API_KEY_SECRET_PATH = maybe "elevenlabs_api_key";
    GEMINI_API_KEY_SECRET_PATH = maybe "gemini_api_key";
    YOUTUBE_API_KEY_SECRET_PATH = maybe "youtube_api_key";
    OPENCLAW_GATEWAY_TOKEN_SECRET_PATH = maybe "openclaw_gateway_token";
    OPENCLAW_TELEGRAM_BOT_TOKEN_SECRET_PATH =
      maybe "openclaw_telegram_bot_token";
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
