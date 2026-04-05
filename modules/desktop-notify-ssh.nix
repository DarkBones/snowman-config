{ lib, pkgs, config, ... }:
let
  cfg = config.snowman.desktopNotifySsh;

  notifyHelper = pkgs.writeShellScriptBin "snowman-desktop-notify" ''
    set -euo pipefail

    export PATH=${lib.makeBinPath [ pkgs.python3 pkgs.util-linux pkgs.libnotify ]}:$PATH

    exec python3 - <<'PY'
    import argparse
    import json
    import os
    import pwd
    import shlex
    import subprocess
    import sys

    TARGET_USER = os.environ.get("SNOWMAN_NOTIFY_TARGET_USER", "bas")
    DEFAULT_APP_NAME = "snowman-notify"
    VALID_URGENCIES = {"low", "normal", "critical"}


    def load_payload():
        if len(sys.argv) > 1:
            return payload_from_args(sys.argv[1:])

        ssh_command = os.environ.get("SSH_ORIGINAL_COMMAND", "").strip()
        if ssh_command:
            return payload_from_args(shlex.split(ssh_command))

        if not sys.stdin.isatty():
            raw = sys.stdin.read().strip()
            if raw:
                payload = json.loads(raw)
                if not isinstance(payload, dict):
                    raise ValueError("JSON payload must be an object")
                return payload

        raise ValueError("provide args or JSON on stdin")


    def payload_from_args(argv):
        if argv and argv[0] in {"notify", "snowman-desktop-notify", "--"}:
            argv = argv[1:]

        parser = argparse.ArgumentParser(prog="snowman-desktop-notify")
        parser.add_argument("--title", default="")
        parser.add_argument("--message", "--body", dest="message", default="")
        parser.add_argument("--app-name", default=DEFAULT_APP_NAME)
        parser.add_argument("--urgency", default="normal")
        parser.add_argument("--expire-time", type=int, default=-1)
        parser.add_argument("--icon", default="")

        args = parser.parse_args(argv)
        return {
            "title": args.title,
            "message": args.message,
            "app_name": args.app_name,
            "urgency": args.urgency,
            "expire_time": args.expire_time,
            "icon": args.icon,
        }


    def send_notification(payload):
        user_info = pwd.getpwnam(TARGET_USER)
        runtime_dir = f"/run/user/{user_info.pw_uid}"
        bus_path = f"{runtime_dir}/bus"

        if not os.path.exists(bus_path):
            raise RuntimeError(
                f"notification bus unavailable for {TARGET_USER}: {bus_path}"
            )

        title = str(payload.get("title") or "").strip()
        body = str(payload.get("message") or payload.get("body") or "").strip()

        if not title and not body:
            raise ValueError("payload must include title or message")

        if not title:
            title = "Notification"

        urgency = str(payload.get("urgency") or "normal").strip().lower()
        if urgency not in VALID_URGENCIES:
            raise ValueError("urgency must be one of: low, normal, critical")

        app_name = str(
            payload.get("app_name") or payload.get("appName") or DEFAULT_APP_NAME
        ).strip() or DEFAULT_APP_NAME
        icon = str(payload.get("icon") or "").strip()

        expire_time = payload.get("expire_time", payload.get("expireTime", -1))
        try:
            expire_time = int(expire_time)
        except (TypeError, ValueError) as exc:
            raise ValueError("expire_time must be an integer") from exc

        env = os.environ.copy()
        env.update(
            {
                "HOME": user_info.pw_dir,
                "XDG_RUNTIME_DIR": runtime_dir,
                "DBUS_SESSION_BUS_ADDRESS": f"unix:path={bus_path}",
            }
        )

        command = [
            "runuser",
            "--preserve-environment",
            "-u",
            TARGET_USER,
            "--",
            "notify-send",
            f"--app-name={app_name}",
            f"--urgency={urgency}",
            f"--expire-time={expire_time}",
        ]

        if icon:
            command.append(f"--icon={icon}")

        command.append(title)
        if body:
            command.append(body)

        completed = subprocess.run(
            command,
            env=env,
            check=False,
            capture_output=True,
            text=True,
        )

        if completed.returncode != 0:
            raise RuntimeError(completed.stderr.strip() or "notify-send failed")


    def main():
        try:
            payload = load_payload()
            send_notification(payload)
        except Exception as exc:
            print(f"snowman-desktop-notify: {exc}", file=sys.stderr)
            sys.exit(1)


    main()
    PY
  '';
in {
  options.snowman.desktopNotifySsh = {
    enable = lib.mkEnableOption
      "a restricted SSH entrypoint that emits swaync desktop notifications";

    user = lib.mkOption {
      type = lib.types.str;
      default = "bas";
      description = "User whose desktop session should receive notifications.";
    };

    sshUser = lib.mkOption {
      type = lib.types.str;
      default = "notify";
      description = "Restricted SSH account that may trigger notifications.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ notifyHelper ];

    services.openssh.extraConfig = ''
      Match User ${cfg.sshUser}
        AllowAgentForwarding no
        AllowStreamLocalForwarding no
        AllowTcpForwarding no
        ForceCommand ${notifyHelper}/bin/snowman-desktop-notify
        GatewayPorts no
        PermitOpen none
        PermitTTY no
        X11Forwarding no
    '';

    systemd.services.sshd.environment.SNOWMAN_NOTIFY_TARGET_USER = cfg.user;
  };
}
