{
  lib,
  pkgs,
  config,
  ...
}:
let
  notifyFailedUserServices = pkgs.writeShellScriptBin "snowman-systemd-user-failure-notifier" ''
    set -euo pipefail

    systemctl_bin="${pkgs.systemd}/bin/systemctl"
    notify_send_bin="${pkgs.libnotify}/bin/notify-send"
    sort_bin="${pkgs.coreutils}/bin/sort"
    mktemp_bin="${pkgs.coreutils}/bin/mktemp"
    mkdir_bin="${pkgs.coreutils}/bin/mkdir"
    rm_bin="${pkgs.coreutils}/bin/rm"
    boot_id_bin="${pkgs.systemd}/bin/systemd-id128"

    xdg_state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
    state_dir="$xdg_state_home/systemd-user-failure-notifier"
    state_file="$state_dir/failure-state"
    boot_id_file="$state_dir/boot-id"
    current_file="$($mktemp_bin)"
    first_run=0

    cleanup() {
      $rm_bin -f "$current_file"
    }
    trap cleanup EXIT

    $mkdir_bin -p "$state_dir"

    current_boot_id="$($boot_id_bin boot-id)"
    stored_boot_id=""

    if [ -r "$boot_id_file" ]; then
      IFS= read -r stored_boot_id <"$boot_id_file" || true
    fi

    if [ "$stored_boot_id" != "$current_boot_id" ]; then
      first_run=1
      : >"$state_file"
      printf '%s\n' "$current_boot_id" >"$boot_id_file"
    elif [ ! -f "$state_file" ]; then
      first_run=1
      : >"$state_file"
    fi

    while IFS= read -r unit; do
      [ -n "$unit" ] || continue

      description=""
      active_state=""
      transient=""
      fragment_path=""
      result=""
      exec_main_code=""
      exec_main_status=""
      status_text=""
      sub_state=""

      while IFS='=' read -r key value; do
        case "$key" in
          Description) description="$value" ;;
          ActiveState) active_state="$value" ;;
          Transient) transient="$value" ;;
          FragmentPath) fragment_path="$value" ;;
          Result) result="$value" ;;
          ExecMainCode) exec_main_code="$value" ;;
          ExecMainStatus) exec_main_status="$value" ;;
          StatusText) status_text="$value" ;;
          SubState) sub_state="$value" ;;
        esac
      done < <(
        "$systemctl_bin" --user show "$unit" \
          --property=Description \
          --property=ActiveState \
          --property=Transient \
          --property=FragmentPath \
          --property=Result \
          --property=ExecMainCode \
          --property=ExecMainStatus \
          --property=StatusText \
          --property=SubState
      )

      [ "$active_state" = "failed" ] || continue
      [ "$transient" != "yes" ] || continue
      [ -n "$fragment_path" ] || continue

      case "$fragment_path" in
        /run/user/*/systemd/transient/*) continue ;;
        /run/systemd/generator*/*) continue ;;
        /run/user/*/systemd/generator*/*) continue ;;
      esac

      attempts=0
      terminal=0

      while IFS=$'\t' read -r stored_unit stored_attempts stored_terminal; do
        if [ "$stored_unit" = "$unit" ]; then
          attempts="$stored_attempts"
          terminal="$stored_terminal"
          break
        fi
      done < "$state_file"

      if [ "$first_run" -eq 1 ]; then
        printf '%s\t%s\t%s\n' "$unit" "$attempts" "$terminal" >>"$current_file"
        continue
      fi

      if [ "$terminal" = "1" ]; then
        printf '%s\t%s\t%s\n' "$unit" "$attempts" "$terminal" >>"$current_file"
        continue
      fi

      reason_parts=()

      if [ -n "$result" ] && [ "$result" != "success" ]; then
        reason_parts+=("Result=$result")
      fi

      if [ -n "$sub_state" ] && [ "$sub_state" != "dead" ]; then
        reason_parts+=("SubState=$sub_state")
      fi

      if [ -n "$exec_main_code" ] || [ -n "$exec_main_status" ]; then
        reason_parts+=("ExecMain=$exec_main_code/$exec_main_status")
      fi

      if [ -n "$status_text" ]; then
        reason_parts+=("Status=$status_text")
      fi

      body="$unit"

      if [ "''${#reason_parts[@]}" -gt 0 ]; then
        reason=""
        for part in "''${reason_parts[@]}"; do
          if [ -n "$reason" ]; then
            reason="$reason; $part"
          else
            reason="$part"
          fi
        done
        body="$body"$'\n'"$reason"
      fi

      summary="User service failed: $unit"
      if [ -n "$description" ] && [ "$description" != "$unit" ]; then
        summary="User service failed: $description"
      fi

      next_attempts=$((attempts + 1))

      if [ "$next_attempts" -le 3 ]; then
        "$systemctl_bin" --user restart "$unit" || true

        "$notify_send_bin" \
          --app-name=snowman-systemd-user-failure-notifier \
          --urgency=normal \
          --icon=dialog-error \
          --hint=boolean:transient:false \
          "$summary (retry $next_attempts/3)" \
          "$body"

        printf '%s\t%s\t0\n' "$unit" "$next_attempts" >>"$current_file"
        continue
      fi

      "$notify_send_bin" \
        --app-name=snowman-systemd-user-failure-notifier \
        --urgency=critical \
        --icon=dialog-error \
        --hint=boolean:transient:false \
        "$summary (giving up after 3 retries)" \
        "$body"
      printf '%s\t%s\t1\n' "$unit" "$next_attempts" >>"$current_file"
    done < <(
      "$systemctl_bin" --user list-units \
        --type=service \
        --state=failed \
        --all \
        --no-legend \
        --plain \
        --full \
        | while IFS= read -r line; do
          set -- $line
          [ $# -gt 0 ] && printf '%s\n' "$1"
        done
    )

    $sort_bin -u "$current_file" >"$state_file"
  '';
in
{
  config = lib.mkIf (pkgs.stdenv.isLinux && (config.roles.hyprland.enable or false)) {
    home.packages = [ notifyFailedUserServices ];

    systemd.user.services.snowman-systemd-user-failure-notifier = {
      Unit = {
        Description = "Snowman systemd user failure notifier";
        After = [
          "graphical-session.target"
          "dbus.service"
        ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${notifyFailedUserServices}/bin/snowman-systemd-user-failure-notifier";
      };
    };

    systemd.user.timers.snowman-systemd-user-failure-notifier = {
      Unit = {
        Description = "Snowman poller for failed user service notifications";
        PartOf = [ "graphical-session.target" ];
      };

      Timer = {
        OnStartupSec = "2m";
        OnUnitActiveSec = "30s";
        AccuracySec = "5s";
      };

      Install.WantedBy = [ "timers.target" ];
    };
  };
}
