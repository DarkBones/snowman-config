{
  lib,
  pkgsUnstable,
  pkgs,
  config,
  ...
}:
let
  cfg = config.roles.gaming;
  alvrPkg = pkgs.callPackage ../../pkgs/alvr-20.13.0.nix { };
  alvrDashboardX11 = pkgs.writeShellScriptBin "alvr-dashboard-x11" ''
    unset WAYLAND_DISPLAY
    unset WAYLAND_SOCKET
    unset SWAYSOCK
    unset HYPRLAND_INSTANCE_SIGNATURE

    export XDG_SESSION_TYPE=x11

    exec ${alvrPkg}/bin/alvr_dashboard "$@"
  '';
  alvrDefaultSession = pkgs.writeText "alvr-session.json" (
    builtins.toJSON {
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
    }
  );
in
{
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
      picom # X11 compositor for startx environment
      alvrPkg
      alvrDashboardX11
    ];

    home.activation.ensureAlvrSessionWritable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
          | .openvr_config.force_sw_encoding = true
          | .openvr_config.eye_resolution_width = 1440
          | .openvr_config.eye_resolution_height = 1584
          | .openvr_config.target_eye_resolution_width = 1440
          | .openvr_config.target_eye_resolution_height = 1584
          | .openvr_config.refresh_rate = 72
          | .session_settings.headset.controllers.enabled = true
          | .session_settings.headset.controllers.content.tracked = true
          | .session_settings.headset.controllers.content.hand_skeleton.enabled = true
          | .session_settings.video.encoder_config.software.force_software_encoding = true
          | .session_settings.video.encoder_config.software.thread_count = 4
          | .session_settings.video.preferred_fps = 72.0
          | .session_settings.video.transcoding_view_resolution.Absolute.width = 1440
          | .session_settings.video.emulated_headset_view_resolution.Absolute.width = 1440
          | .session_settings.video.bitrate.mode.ConstantMbps = 50
        ' "$session_file" > "$tmp_file"
        mv "$tmp_file" "$session_file"
        chmod 600 "$session_file"
      fi
    '';

    home.activation.ensureSteamVrLaunchOptions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      steamvr_root="$HOME/.local/share/Steam/steamapps/common/SteamVR"
      launcher="$steamvr_root/bin/linux64/vrcompositor-launcher.sh"
      backup="$steamvr_root/bin/linux64/vrcompositor-launcher.sh.bak"
      launch_options="env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET -u SWAYSOCK -u HYPRLAND_INSTANCE_SIGNATURE DISPLAY=\$DISPLAY XAUTHORITY=''${XAUTHORITY:-\$HOME/.Xauthority} XDG_SESSION_TYPE=x11 SDL_VIDEODRIVER=x11 GDK_BACKEND=x11 __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia VK_DRIVER_FILES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json QT_QPA_PLATFORM=xcb $steamvr_root/bin/vrmonitor.sh %command%"
      vrwebhelper_script="$steamvr_root/bin/vrwebhelper/linux64/vrwebhelper.sh"
      steamvr_settings="$HOME/.local/share/Steam/config/steamvr.vrsettings"

      if [ -f "$launcher" ] && [ -f "$backup" ] \
        && ${pkgs.gnugrep}/bin/grep -Fq 'Bypassing vrcompositor-launcher' "$launcher" \
        && ${pkgs.gnugrep}/bin/grep -Fq 'exec "$ROOT/vrcompositor-launcher" "$@"' "$backup"; then
        cp "$backup" "$launcher"
        chmod 755 "$launcher"
      fi

      if [ -f "$launcher" ] && [ ! -f "$backup" ]; then
        cp -a "$launcher" "$backup"
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

      if [ -f "$backup" ]; then
        cp "$backup" "$launcher"
        chmod 755 "$launcher"
      fi

      if [ -f "$vrwebhelper_script" ] \
        && ! ${pkgs.gnugrep}/bin/grep -Fq '/run/current-system/sw/share/nix-ld/lib' "$vrwebhelper_script"; then
        tmp_file="$vrwebhelper_script.tmp"
        ${pkgs.gawk}/bin/awk '
          /^exec "\$\{in_runtime\[@\]\}" \.\/vrwebhelper "\$@"$/ {
            print "export LD_LIBRARY_PATH=\"/run/current-system/sw/share/nix-ld/lib''${LD_LIBRARY_PATH+:$LD_LIBRARY_PATH}\""
          }
          { print }
        ' "$vrwebhelper_script" > "$tmp_file"
        if ! ${pkgs.diffutils}/bin/cmp -s "$vrwebhelper_script" "$tmp_file"; then
          mv "$tmp_file" "$vrwebhelper_script"
          chmod 755 "$vrwebhelper_script"
        else
          rm -f "$tmp_file"
        fi
      fi

      if [ -f "$steamvr_settings" ]; then
        tmp_file="$steamvr_settings.tmp"
        ${pkgs.jq}/bin/jq '
          if has("driver_alvr_server") then
            .driver_alvr_server.blocked_by_safe_mode = false
          else
            . + { "driver_alvr_server": { "blocked_by_safe_mode": false } }
          end
          | if has("driver_prism") then
              .driver_prism.blocked_by_safe_mode = false
            else
              .
            end
          | .steamvr.showMirrorView = false
          | .steamvr.mirrorViewDisplayMode = 0
          | .steamvr.mirrorViewEye = 0
          | .steamvr.enableHomeApp = false
          | .dashboard.showOnAppExit = false
        ' "$steamvr_settings" > "$tmp_file"

        if ! ${pkgs.diffutils}/bin/cmp -s "$steamvr_settings" "$tmp_file"; then
          mv "$tmp_file" "$steamvr_settings"
          chmod 600 "$steamvr_settings"
        else
          rm -f "$tmp_file"
        fi
      fi
    '';
  };
}
