{
  lib,
  pkgs,
  pkgsUnstable,
  config,
  ...
}:
let
  tailscaleApp = pkgsUnstable.tailscale-gui;
  tailscaleAppBundle = "${tailscaleApp}/Applications/Tailscale.app";
  systemTailscaleAppBundle = "/Applications/Tailscale.app";
  selectAppBundle = ''
    app_bundle="${systemTailscaleAppBundle}"
    if [ ! -d "$app_bundle" ]; then
      app_bundle="${tailscaleAppBundle}"
    fi
  '';
  tailscaleGuiApp = pkgs.runCommandLocal "tailscale-gui-app" { } ''
    mkdir -p "$out/Applications"
    ln -s "${tailscaleAppBundle}" "$out/Applications/Tailscale.app"
  '';
  launchTailscale = pkgs.writeShellScriptBin "launch-tailscale" ''
    ${selectAppBundle}

    exec /usr/bin/open "$app_bundle"
  '';
  tailscaleCli = pkgs.writeShellScriptBin "tailscale" ''
    ${selectAppBundle}
    cli="$app_bundle/Contents/MacOS/Tailscale"

    if ! "$cli" version >/dev/null 2>&1; then
      /usr/bin/open "$app_bundle"

      # The CLI fails until the app has initialized its local preferences/backend.
      attempts=25
      while [ "$attempts" -gt 0 ]; do
        if "$cli" version >/dev/null 2>&1; then
          break
        fi
        sleep 0.2
        attempts=$((attempts - 1))
      done
    fi

    exec "$cli" "$@"
  '';
in
{
  config = lib.mkIf pkgs.stdenv.isDarwin {
    home.packages = [
      tailscaleGuiApp
      tailscaleCli
    ];

    launchd.agents.tailscale = {
      enable = true;
      config = {
        Label = "org.nix.tailscale";
        ProgramArguments = [ "${launchTailscale}/bin/launch-tailscale" ];
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/tailscale.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/tailscale.err.log";
      };
    };
  };
}
