{ lib, pkgs, config, ... }: {
  config =
    lib.mkIf (pkgs.stdenv.isLinux && (config.roles.desktop.enable or false)) {
      home.activation.thunarDefaultView =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${pkgs.xfce.xfconf}/bin/xfconf-query -c thunar -p /default-view \
          --create --type string --set ThunarDetailsView || true

          ${pkgs.xfce.xfconf}/bin/xfconf-query -c thunar -p /misc-date-style \
          --create --type string --set THUNAR_DATE_STYLE_CUSTOM || true

          ${pkgs.xfce.xfconf}/bin/xfconf-query -c thunar -p /misc-date-custom-style \
          --create --type string --set '%Y-%m-%d %H:%M' || true
        '';
    };
}
