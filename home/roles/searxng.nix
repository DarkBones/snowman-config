{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.roles.searxng;

  homeDir = config.home.homeDirectory;
  stateDir = "${homeDir}/.local/state/searxng";
  settingsFile = "${stateDir}/settings.yml";
  secretFile = "${stateDir}/secret_key";

  ensureSearxng = pkgs.writeShellScript "searxng-launch" ''
    set -euo pipefail

    mkdir -p "${stateDir}"

    if [ ! -s "${secretFile}" ]; then
      ${pkgs.openssl}/bin/openssl rand -hex 32 > "${secretFile}"
      chmod 600 "${secretFile}"
    fi

    secret_key="$(${pkgs.coreutils}/bin/cat "${secretFile}")"

    ${pkgs.coreutils}/bin/cat > "${settingsFile}" <<EOF
    use_default_settings: true
    general:
      instance_name: SearXNG
    search:
      formats:
        - html
        - json
      safe_search: 0
    server:
      bind_address: "127.0.0.1"
      port: 8888
      base_url: "http://127.0.0.1:8888/"
      secret_key: "$secret_key"
    EOF

    exec env SEARXNG_SETTINGS_PATH="${settingsFile}" ${pkgs.searxng}/bin/searxng-run
  '';
in
{
  options.roles.searxng.enable = lib.mkEnableOption "SearXNG role";

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    home.packages = [ pkgs.searxng ];

    launchd.agents.searxng = {
      enable = true;
      config = {
        Label = "org.nix.searxng";
        ProgramArguments = [ "${ensureSearxng}" ];
        RunAtLoad = true;
        KeepAlive = true;
        EnvironmentVariables = {
          PATH = "${config.home.profileDirectory}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
        StandardOutPath = "${homeDir}/Library/Logs/searxng.log";
        StandardErrorPath = "${homeDir}/Library/Logs/searxng.err.log";
      };
    };
  };
}
