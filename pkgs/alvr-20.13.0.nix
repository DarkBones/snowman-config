{
  lib,
  rustPlatform,
  fetchFromGitHub,
  replaceVars,
  pkg-config,
  autoAddDriverRunpath,
  alsa-lib,
  android-tools,
  brotli,
  bzip2,
  celt,
  ffmpeg,
  gmp,
  jack2,
  lame,
  libX11,
  libXi,
  libXrandr,
  libXcursor,
  libdrm,
  libglvnd,
  libogg,
  libpng,
  libtheora,
  libunwind,
  libva,
  libvdpau,
  libxkbcommon,
  openapv,
  openssl,
  openvr,
  pipewire,
  rust-cbindgen,
  soxr,
  vulkan-headers,
  vulkan-loader,
  wayland,
  x264,
  xvidcore,
}:
rustPlatform.buildRustPackage rec {
  pname = "alvr";
  version = "20.13.0";

  src = fetchFromGitHub {
    owner = "alvr-org";
    repo = "ALVR";
    tag = "v${version}";
    fetchSubmodules = true;
    hash = "sha256-h7/fuuolxbNkjUbqXZ7NTb1AEaDMFaGv/S05faO2HIc=";
  };

  cargoHash = "sha256-A0ADPMhsREH1C/xpSxW4W2u4ziDrKRrQyY5kBDn//gQ=";

  patches = [
    (replaceVars /nix/store/8hx8jwa24q6rkzhca9iqy5ckk9rbphi1-source/pkgs/by-name/al/alvr/fix-finding-libs.patch {
      ffmpeg = lib.getDev ffmpeg;
      x264 = lib.getDev x264;
    })
  ];

  postPatch = ''
    substituteInPlace alvr/server_openvr/cpp/platform/linux/EncodePipelineVAAPI.cpp \
      --replace-fail 'FF_PROFILE_H264_MAIN' 'AV_PROFILE_H264_MAIN' \
      --replace-fail 'FF_PROFILE_H264_BASELINE' 'AV_PROFILE_H264_BASELINE' \
      --replace-fail 'FF_PROFILE_H264_HIGH' 'AV_PROFILE_H264_HIGH' \
      --replace-fail 'FF_PROFILE_HEVC_MAIN' 'AV_PROFILE_HEVC_MAIN' \
      --replace-fail 'FF_PROFILE_AV1_MAIN' 'AV_PROFILE_AV1_MAIN'
  '';

  env = {
    NIX_CFLAGS_COMPILE = toString [
      "-lbrotlicommon"
      "-lbrotlidec"
      "-lcrypto"
      "-lpng"
      "-lssl"
    ];
    RUSTFLAGS = toString (
      map (a: "-C link-arg=${a}") [
        "-Wl,--push-state,--no-as-needed"
        "-lEGL"
        "-lwayland-client"
        "-lxkbcommon"
        "-Wl,--pop-state"
      ]
    );
  };

  cargoBuildFlags = [
    "--exclude=alvr_xtask"
    "--workspace"
  ];

  nativeBuildInputs = [
    rust-cbindgen
    pkg-config
    rustPlatform.bindgenHook
    autoAddDriverRunpath
  ];

  buildInputs = [
    alsa-lib
    android-tools
    brotli
    bzip2
    celt
    ffmpeg
    gmp
    jack2
    lame
    libX11
    libXcursor
    libXi
    libXrandr
    libdrm
    libglvnd
    libogg
    libpng
    libtheora
    libunwind
    libva
    libvdpau
    libxkbcommon
    openapv
    openssl
    openvr
    pipewire
    soxr
    vulkan-headers
    vulkan-loader
    wayland
    x264
    xvidcore
  ];

  postBuild = ''
    cargo xtask build-streamer --release
  '';

  postInstall = ''
    install -Dm755 ${src}/alvr/xtask/resources/alvr.desktop $out/share/applications/alvr.desktop
    install -Dm644 ${src}/resources/ALVR-Icon.svg $out/share/icons/hicolor/scalable/apps/alvr.svg

    mkdir -p $out/{libexec,lib/alvr,share}
    cp -r ./build/alvr_streamer_linux/lib64/. $out/lib
    cp -r ./build/alvr_streamer_linux/libexec/. $out/libexec
    cp -r ./build/alvr_streamer_linux/share/. $out/share
    ln -s $out/lib $out/lib64
  '';

  meta = {
    description = "Stream VR games from your PC to your headset via Wi-Fi";
    homepage = "https://github.com/alvr-org/ALVR/";
    changelog = "https://github.com/alvr-org/ALVR/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "alvr_dashboard";
    platforms = lib.platforms.linux;
  };
}
