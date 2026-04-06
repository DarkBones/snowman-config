{ lib, pkgs, config, ... }:
let
  cfg = config.snowman.desktopSpeakSsh;
  targetUser = config.users.users.${cfg.user};
  targetUid = toString targetUser.uid;
  targetHome = config.users.users.${cfg.user}.home;
  speakCommand = "${targetHome}/bin/speak";
  authorizedKeysRuntimeDir = "/run/snowman/ssh";
  authorizedKeysRuntimeFile =
    "${authorizedKeysRuntimeDir}/${cfg.sshUser}.authorized_keys";

  speakBridgeScript = pkgs.writeText "snowman-desktop-speak-bridge.py" ''
    import argparse
    import json
    import os
    import shlex
    import subprocess
    import sys


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
        if argv and argv[0] in {"speak", "snowman-desktop-speak", "--"}:
            argv = argv[1:]

        parser = argparse.ArgumentParser(prog="snowman-desktop-speak")
        parser.add_argument("--voice", default="hexley")
        parser.add_argument("text", nargs="+")
        args = parser.parse_args(argv)
        text = " ".join(args.text).strip()
        if not text:
            raise ValueError("text is required")
        return {
            "voice": args.voice,
            "text": text,
        }


    def main():
        try:
            payload = load_payload()
            completed = subprocess.run(
                [
                    "/run/wrappers/bin/sudo",
                    "--non-interactive",
                    "-u",
                    os.environ["SNOWMAN_SPEAK_TARGET_USER"],
                    "/run/current-system/sw/bin/snowman-desktop-speak-local",
                ],
                input=json.dumps(payload),
                check=False,
                capture_output=True,
                text=True,
            )
            if completed.returncode != 0:
                raise RuntimeError(completed.stderr.strip() or "speech delivery failed")
        except Exception as exc:
            print(f"snowman-desktop-speak: {exc}", file=sys.stderr)
            sys.exit(1)


    main()
  '';

  speakHelper = pkgs.writeShellScriptBin "snowman-desktop-speak" ''
    set -euo pipefail

    export PATH=${lib.makeBinPath [ pkgs.python3 ]}:$PATH
    export SNOWMAN_SPEAK_TARGET_USER=${lib.escapeShellArg cfg.user}

    exec python3 ${speakBridgeScript} "$@"
  '';

  speakLocalHelper = pkgs.writeShellScriptBin "snowman-desktop-speak-local" ''
    set -euo pipefail

    export PATH=${lib.makeBinPath [
      pkgs.coreutils
      pkgs.curl
      pkgs.ffmpeg
      pkgs.findutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.jq
      pkgs.mpv
      pkgs.vlc
    ]}:/run/current-system/sw/bin:$PATH
    export HOME=${lib.escapeShellArg targetHome}
    export XDG_RUNTIME_DIR=/run/user/${targetUid}
    export PULSE_SERVER=unix:$XDG_RUNTIME_DIR/pulse/native
    export ELEVEN_LABS_API_KEY_SECRET_PATH=${lib.escapeShellArg config.sops.secrets.elevenlabs_api_key.path}
    if [ -S "$XDG_RUNTIME_DIR/bus" ]; then
      export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    fi

    if [ ! -x ${lib.escapeShellArg speakCommand} ]; then
      echo "snowman-desktop-speak-local: missing speak command: ${speakCommand}" >&2
      exit 1
    fi

    payload="$(cat)"
    voice="$(printf '%s' "$payload" | jq -r '.voice // "hexley"')"
    text="$(printf '%s' "$payload" | jq -r '.text // empty')"

    if [ -z "$text" ]; then
      echo "snowman-desktop-speak-local: text is required" >&2
      exit 1
    fi

    exec ${lib.escapeShellArg speakCommand} --voice "$voice" "$text"
  '';
in {
  options.snowman.desktopSpeakSsh = {
    enable = lib.mkEnableOption
      "a restricted SSH entrypoint that speaks through the desktop session";

    user = lib.mkOption {
      type = lib.types.str;
      default = "bas";
      description = "User whose desktop session should play speech.";
    };

    sshUser = lib.mkOption {
      type = lib.types.str;
      default = "speak";
      description = "Restricted SSH account that may trigger speech playback.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ speakHelper speakLocalHelper ];

    systemd.tmpfiles.rules = [ "d ${authorizedKeysRuntimeDir} 0755 root root -" ];

    systemd.services.desktop-speak-ssh-authorize-openclaw = {
      description = "Expose OpenClaw SSH key for the restricted speak receiver";
      wantedBy = [ "multi-user.target" ];
      after = [ "openclaw-prepare.service" ];
      requires = [ "openclaw-prepare.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
      };
      script = ''
        set -euo pipefail

        install -d -m 0755 -o root -g root ${authorizedKeysRuntimeDir}

        if [ -r /var/lib/openclaw/.ssh/id_ed25519.pub ]; then
          install -m 0644 -o root -g root /var/lib/openclaw/.ssh/id_ed25519.pub ${authorizedKeysRuntimeFile}
        else
          rm -f ${authorizedKeysRuntimeFile}
        fi
      '';
    };

    security.sudo.extraRules = [{
      users = [ cfg.sshUser ];
      commands = [{
        command = "/run/current-system/sw/bin/snowman-desktop-speak-local";
        options = [ "NOPASSWD" ];
      }];
    }];

    services.openssh.extraConfig = ''
      Match User ${cfg.sshUser}
        AllowAgentForwarding no
        AllowStreamLocalForwarding no
        AllowTcpForwarding no
        AuthenticationMethods publickey
        AuthorizedKeysFile /etc/ssh/authorized_keys.d/%u ${authorizedKeysRuntimeFile}
        ForceCommand ${speakHelper}/bin/snowman-desktop-speak
        GatewayPorts no
        KbdInteractiveAuthentication no
        PasswordAuthentication no
        PermitOpen none
        PermitTTY no
        PubkeyAuthentication yes
        X11Forwarding no
    '';
  };
}
