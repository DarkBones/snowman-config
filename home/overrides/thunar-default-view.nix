{ lib, pkgs, ... }: {
  home.activation.thunarDefaultView =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.xfce.xfconf}/bin/xfconf-query -c thunar -p /default-view \
        --create --type string --set ThunarDetailsView || true
    '';
}
