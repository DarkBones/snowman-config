{
  stdenv,
  lib,
  appimageTools,
  addDriverRunpath,
  buildFHSEnv,
  bash,
  makeDesktopItem,
  copyDesktopItems,
  libGLU,
  libarchive,
  libxcrypt,
  glib,
  dbus,
  ocl-icd,
  python3,
  aprutil,
  xkeyboard-config,
  libxcb-util,
  libxcb-wm,
  libxcb-render-util,
  libxcb-keysyms,
  libxcb-image,
  libxxf86vm,
  libxt,
  libxtst,
  libxrender,
  libxrandr,
  libxi,
  libxinerama,
  libxfixes,
  libxext,
  libxdamage,
  libxcursor,
  libxcomposite,
  libx11,
  libsm,
  libice,
  libxcb,
  writeText,
  unzip,
  version ? "20.3.2",
  localZipPath,
}:
let
  src = builtins.path {
    path = localZipPath;
    name = "DaVinci_Resolve_${version}_Linux.zip";
  };

  davinci = stdenv.mkDerivation rec {
    pname = "davinci-resolve";
    inherit version src;

    nativeBuildInputs = [
      appimageTools.appimage-exec
      addDriverRunpath
      copyDesktopItems
      unzip
    ];

    buildInputs = [
      libGLU
      libxxf86vm
    ];

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      export HOME=$PWD/home
      mkdir -p "$HOME"

      mkdir -p "$out"
      test -e "DaVinci_Resolve_${version}_Linux.run"
      appimage-exec.sh -x "$out" "DaVinci_Resolve_${version}_Linux.run"

      mkdir -p "$out"/{"Apple Immersive/Calibration",configs,DolbyVision,easyDCP,Extras,Fairlight,GPUCache,logs,Media,"Resolve Disk Database",.crashreport,.license,.LUT}

      runHook postInstall
    '';

    dontStrip = true;

    postFixup = ''
      for program in "$out"/bin/*; do
        isELF "$program" || continue
        addDriverRunpath "$program"
      done

      for program in "$out"/libs/*; do
        isELF "$program" || continue
        if [[ "$program" != *"libcudnn_cnn_infer"* ]]; then
          addDriverRunpath "$program"
        fi
      done

      ln -s "$out"/libs/libcrypto.so.1.1 "$out"/libs/libcrypt.so.1
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "davinci-resolve";
        desktopName = "Davinci Resolve";
        genericName = "Video Editor";
        exec = "davinci-resolve";
        icon = "davinci-resolve";
        comment = "Professional video editing, color, effects and audio post-processing";
        categories = [
          "AudioVideo"
          "AudioVideoEditing"
          "Video"
          "Graphics"
        ];
        startupWMClass = "resolve";
      })
    ];
  };
in
buildFHSEnv {
  inherit (davinci) pname version;

  targetPkgs =
    pkgs: with pkgs; [
      alsa-lib
      aprutil
      bzip2
      davinci
      dbus
      expat
      fontconfig
      freetype
      glib
      libGL
      libGLU
      libarchive
      libcap
      librsvg
      libtool
      libuuid
      libxcrypt
      libxkbcommon
      nspr
      ocl-icd
      opencl-headers
      python3
      python3.pkgs.numpy
      udev
      xdg-utils
      libice
      libsm
      libx11
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxinerama
      libxrandr
      libxrender
      libxt
      libxtst
      libxxf86vm
      libxcb
      libxcb-util
      libxcb-image
      libxcb-keysyms
      libxcb-render-util
      libxcb-wm
      xkeyboard-config
      zlib
    ];

  runScript = "${bash}/bin/bash ${writeText "davinci-wrapper" ''
    export QT_XKB_CONFIG_ROOT="${xkeyboard-config}/share/X11/xkb"
    export QT_PLUGIN_PATH="${davinci}/libs/plugins:$QT_PLUGIN_PATH"
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/lib:/usr/lib32:${davinci}/libs"
    ${davinci}/bin/resolve
  ''}";

  extraInstallCommands = ''
    mkdir -p "$out/share/applications" "$out/share/icons/hicolor/128x128/apps"
    ln -s ${davinci}/share/applications/*.desktop "$out/share/applications/"
    ln -s ${davinci}/graphics/DV_Resolve.png "$out/share/icons/hicolor/128x128/apps/davinci-resolve.png"
  '';

  passthru = { inherit davinci; };

  meta = {
    description = "Professional video editing, color, effects and audio post-processing";
    homepage = "https://www.blackmagicdesign.com/products/davinciresolve";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "davinci-resolve";
  };
}
