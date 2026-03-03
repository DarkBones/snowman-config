{ lib, pkgs, config, networkSecretsPath ? null, ... }:
let
  vpnConn = "pia-de-frankfurt";
  piaUserSecret = "pia-username";
  piaPassSecret = "pia-password";
  piaOvpnSecret = "pia-ovpn";

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

    ovpn_path="${config.sops.secrets.${piaOvpnSecret}.path}"
    user_path="${config.sops.secrets.${piaUserSecret}.path}"
    pass_path="${config.sops.secrets.${piaPassSecret}.path}"

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

    # Ensure NM stores the password instead of prompting for an agent.
    ${nmcli} connection modify "$conn" +vpn.data "password-flags=0"
    # Prevent MTU blackholes that stall TCP on some PIA endpoints.
    ${nmcli} connection modify "$conn" +vpn.data "mssfix=1360"

    # Autoconnect by default when NetworkManager is up.
    ${nmcli} connection modify "$conn" connection.autoconnect yes
    ${nmcli} connection modify "$conn" connection.autoconnect-retries -1

    # Bring the VPN up now if it's not already active.
    if ! ${nmcli} -t -f NAME connection show --active | ${grep} -qx "$conn"; then
      ${nmcli} connection up "$conn" || true
    fi

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

  sops.secrets.${piaUserSecret} = {
    sopsFile = secretsFile;
    key = "pia/username";
  };
  sops.secrets.${piaPassSecret} = {
    sopsFile = secretsFile;
    key = "pia/password";
  };
  sops.secrets.${piaOvpnSecret} = {
    sopsFile = secretsFile;
    key = "pia/ovpn";
  };

  systemd.services.vpn-ensure-nm-openvpn = {
    description = "Ensure NetworkManager OpenVPN profile from SOPS";
    wantedBy = [ "multi-user.target" ];
    after =
      [ "NetworkManager.service" "network-online.target" "sops-nix.service" ];
    wants =
      [ "NetworkManager.service" "network-online.target" "sops-nix.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = setupScript;
    };
  };
}
