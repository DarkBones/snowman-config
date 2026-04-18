{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.snowman.desktopNotifySsh;

  notifyBridgeScript = pkgs.writeText "snowman-desktop-notify-bridge.py" ''
    import argparse
    import json
    import os
    import shlex
    import subprocess
    import sys

    DEFAULT_APP_NAME = "snowman-notify"

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


    def main():
        try:
            payload = load_payload()
            completed = subprocess.run(
                ["/run/wrappers/bin/sudo", "--non-interactive", "-u", os.environ["SNOWMAN_NOTIFY_TARGET_USER"],
                 "/run/current-system/sw/bin/snowman-desktop-notify-local"],
                input=json.dumps(payload),
                check=False,
                capture_output=True,
                text=True,
            )
            if completed.returncode != 0:
                raise RuntimeError(completed.stderr.strip() or "notification delivery failed")
        except Exception as exc:
            print(f"snowman-desktop-notify: {exc}", file=sys.stderr)
            sys.exit(1)


    main()
  '';

  notifyLocalScript = pkgs.writeText "snowman-desktop-notify-local.py" ''
    import json
    import os
    import pwd
    import subprocess
    import sys

    TARGET_USER = pwd.getpwuid(os.getuid()).pw_name
    DEFAULT_APP_NAME = "snowman-notify"
    VALID_URGENCIES = {"low", "normal", "critical"}


    def main():
        raw = sys.stdin.read().strip()
        if not raw:
            raise ValueError("expected JSON payload on stdin")

        payload = json.loads(raw)
        if not isinstance(payload, dict):
            raise ValueError("JSON payload must be an object")

        runtime_dir = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
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
        env["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={bus_path}"

        command = [
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


    try:
        main()
    except Exception as exc:
        print(f"snowman-desktop-notify-local: {exc}", file=sys.stderr)
        sys.exit(1)
  '';

  notifyHelper = pkgs.writeShellScriptBin "snowman-desktop-notify" ''
    set -euo pipefail

    export PATH=${lib.makeBinPath [ pkgs.python3 ]}:$PATH
    export SNOWMAN_NOTIFY_TARGET_USER=${lib.escapeShellArg cfg.user}

    exec python3 ${notifyBridgeScript} "$@"
  '';

  notifyLocalHelper = pkgs.writeShellScriptBin "snowman-desktop-notify-local" ''
    set -euo pipefail

    export PATH=${
      lib.makeBinPath [
        pkgs.python3
        pkgs.libnotify
      ]
    }:$PATH

    exec python3 ${notifyLocalScript}
  '';
in
{
  options.snowman.desktopNotifySsh = {
    enable = lib.mkEnableOption "a restricted SSH entrypoint that emits swaync desktop notifications";

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
    environment.systemPackages = [
      notifyHelper
      notifyLocalHelper
    ];

    security.sudo.extraRules = [
      {
        users = [ cfg.sshUser ];
        commands = [
          {
            command = "/run/current-system/sw/bin/snowman-desktop-notify-local";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

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
  };
}
