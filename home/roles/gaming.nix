{ lib, pkgsUnstable, pkgs, config, ... }:
let
  cfg = config.roles.gaming;
  alvrPkg = pkgsUnstable.alvr.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      mv $out/libexec/alvr/vrcompositor-wrapper $out/libexec/alvr/vrcompositor-wrapper-unwrapped
      cat > $out/libexec/alvr/vrcompositor-wrapper << EOF
#!/usr/bin/env bash
unset LD_LIBRARY_PATH
unset LD_PRELOAD
unset VRCOMPOSITOR_LD_LIBRARY_PATH
unset STEAM_RUNTIME
unset STEAM_ZENITY
exec ${pkgs.steam-run}/bin/steam-run $out/libexec/alvr/vrcompositor-wrapper-unwrapped "\$@"
EOF
      chmod +x $out/libexec/alvr/vrcompositor-wrapper
    '';
  });
  alvrDashboardX11 = pkgs.writeShellScriptBin "alvr-dashboard-x11" ''
    unset WAYLAND_DISPLAY
    unset WAYLAND_SOCKET
    unset SWAYSOCK
    unset HYPRLAND_INSTANCE_SIGNATURE

    export XDG_SESSION_TYPE=x11

    exec ${alvrPkg}/bin/alvr_dashboard "$@"
  '';
  alvrDefaultSession = pkgs.writeText "alvr-session.json"
    (builtins.toJSON {
      session_settings = {
        capture = {
          capture_method = {
            variant = "Wlr";
          };
        };
        headset = {
          controllers = {
            enabled = false;
            content = {
              tracked = false;
              hand_skeleton = {
                enabled = false;
              };
            };
          };
        };
      };
      openvr_config = {
        use_separate_hand_trackers = false;
      };
    });
in {
  options.roles.gaming.enable = lib.mkEnableOption "Gaming (home)";

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    home.packages = with pkgsUnstable; [
      mangohud
      lutris
      protontricks
      vulkan-tools
      mesa-demos
      dualsensectl
      piper
      openrgb
    ];

    home.activation.ensureAlvrSessionWritable =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        config_dir="$HOME/.config/alvr"
        session_file="$config_dir/session.json"
        tmp_file="$config_dir/session.json.tmp"

        mkdir -p "$config_dir"

        if [ -L "$session_file" ]; then
          rm "$session_file"
        fi

        if [ ! -e "$session_file" ]; then
          cp ${alvrDefaultSession} "$session_file"
          chmod 600 "$session_file"
        fi

        if [ -e "$session_file" ]; then
          ${pkgs.jq}/bin/jq '
            .openvr_config.use_separate_hand_trackers = false
            | .session_settings.headset.controllers.enabled = false
            | .session_settings.headset.controllers.content.tracked = false
            | .session_settings.headset.controllers.content.hand_skeleton.enabled = false
          ' "$session_file" > "$tmp_file"
          mv "$tmp_file" "$session_file"
          chmod 600 "$session_file"
        fi
      '';

    home.activation.ensureSteamVrLaunchOptions =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        steamvr_root="$HOME/.local/share/Steam/steamapps/common/SteamVR"
        launcher="$steamvr_root/bin/linux64/vrcompositor-launcher.sh"
        backup="$steamvr_root/bin/linux64/vrcompositor-launcher.sh.bak"
        launch_options="QT_QPA_PLATFORM=xcb $steamvr_root/bin/vrmonitor.sh %command%"

        if [ -f "$launcher" ] && [ -f "$backup" ] \
          && ${pkgs.gnugrep}/bin/grep -Fq 'Bypassing vrcompositor-launcher' "$launcher" \
          && ${pkgs.gnugrep}/bin/grep -Fq 'exec "$ROOT/vrcompositor-launcher" "$@"' "$backup"; then
          cp "$backup" "$launcher"
          chmod 755 "$launcher"
        fi

        for steam_root in "$HOME/.local/share/Steam" "$HOME/.steam/root"; do
          userdata_dir="$steam_root/userdata"

          if [ ! -d "$userdata_dir" ]; then
            continue
          fi

          while IFS= read -r localconfig; do
            tmp_file="$localconfig.tmp"

            ${pkgs.gnused}/bin/sed \
              "s#\"LaunchOptions\"[[:space:]]*\".*vrmonitor\\.sh %command%\"#\"LaunchOptions\"\t\t\"$launch_options\"#" \
              "$localconfig" > "$tmp_file"

            if ! ${pkgs.diffutils}/bin/cmp -s "$localconfig" "$tmp_file"; then
              mv "$tmp_file" "$localconfig"
            else
              rm -f "$tmp_file"
            fi
          done < <(${pkgs.findutils}/bin/find "$userdata_dir" -path '*/config/localconfig.vdf' -type f)
        done
      '';
  };
}
