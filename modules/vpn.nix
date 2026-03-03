{ lib, pkgs, config, networkSecretsPath ? null, ... }:
let
  vpnConn = "pia-de-frankfurt";

  nmcli = "${pkgs.networkmanager}/bin/nmcli";
  grep = "${pkgs.gnugrep}/bin/grep";
  sed = "${pkgs.gnused}/bin/sed";
  cat = "${pkgs.coreutils}/bin/cat";

  secretsFile = if networkSecretsPath != null then
    networkSecretsPath
  else
    throw "modules/vpn.nix: networkSecretsPath not passed via specialArgs";

  setupScript = pkgs.writeShellScript "vpn-ensure-nm-openvpn" ''
    set -euo pipefail
    conn="${vpnConn}"

    ovpn_path="${config.sops.secrets."pia/ovpn".path}"
    user_path="${config.sops.secrets."pia/username".path}"
    pass_path="${config.sops.secrets."pia/password".path}"

    if ! test -s "$ovpn_path" || ! test -s "$user_path" || ! test -s "$pass_path"; then
      echo "[vpn] secrets missing/empty; skipping VPN setup" >&2
      exit 0
    fi

    # Always delete existing profile so updated .ovpn applies
    if ${nmcli} -t -f NAME connection show | ${grep} -qx "$conn"; then
      echo "[vpn] Removing existing connection '$conn'"
      ${nmcli} connection delete "$conn" >/dev/null
    fi

    echo "[vpn] Importing OpenVPN profile"
    import_out="$(${nmcli} connection import type openvpn file "$ovpn_path")"

    # Extract imported name
    imported="$(printf '%s' "$import_out" | ${sed} -nE "s/^Connection '([^']+)'.*/\1/p")"

    # Rename to stable name
    if [ -n "$imported" ] && [ "$imported" != "$conn" ]; then
      ${nmcli} connection modify "$imported" connection.id "$conn"
    fi

    user="$(${cat} "$user_path" | tr -d '\r\n')"
    pass="$(${cat} "$pass_path" | tr -d '\r\n')"

    # Set username + password (vpn.secrets is what NM actually uses here)
    ${nmcli} connection modify "$conn" vpn.user-name "$user"
    ${nmcli} connection modify "$conn" vpn.secrets "password=$pass"

    # Patch password-flags in vpn.data without destroying the rest
    data="$(${nmcli} -g vpn.data connection show "$conn" || true)"
    data="$(printf '%s' "$data" | tr '\n' ' ')"

    new_data="$(printf '%s' "$data" | ${sed} -E \
      's/(^|,)[[:space:]]*password-flags[[:space:]]*=[[:space:]]*[0-9]+/\1password-flags=0/g')"

    case "$new_data" in
      *password-flags*)
        ;;
      "")
        new_data="password-flags=0"
        ;;
      *)
        new_data="''${new_data},password-flags=0"
        ;;
    esac

    ${nmcli} connection modify "$conn" vpn.data "$new_data"

    # Autoconnect
    ${nmcli} connection modify "$conn" connection.autoconnect yes
    ${nmcli} connection modify "$conn" connection.autoconnect-retries -1

    # Attempt connection (do not fail boot)
    ${nmcli} connection up "$conn" || true

    echo "[vpn] ensured profile + credentials for '$conn'"
  '';
in {
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = with pkgs; [ networkmanager-openvpn ];
  environment.systemPackages = with pkgs; [ openvpn ];

  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
  };

  assertions = [{
    assertion = builtins.pathExists secretsFile;
    message = ''
      VPN module enabled but secrets file is missing: ${toString secretsFile}
      Create it with:
        sops networks/secrets.yml
    '';
  }];

  sops.secrets."pia/username" = { sopsFile = secretsFile; };
  sops.secrets."pia/password" = { sopsFile = secretsFile; };
  sops.secrets."pia/ovpn" = { sopsFile = secretsFile; };

  systemd.services.vpn-ensure-nm-openvpn = {
    description = "Ensure NetworkManager OpenVPN profile from SOPS";
    wantedBy = [ "multi-user.target" ];
    after = [ "NetworkManager.service" "network-online.target" ];
    wants = [ "NetworkManager.service" "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = setupScript;
    };
  };
}
