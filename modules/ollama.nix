{ inputs, lib, pkgsUnstable, ... }:
let
  ollamaFromGitHub = pkgsUnstable.ollama.overrideAttrs (_: {
    version = "0.17.7";
    src = inputs.ollama-src;
    proxyVendor = true;
    subPackages = [ "." ];
    vendorHash = "sha256-Lc1Ktdqtv2VhJQssk8K1UOimeEjVNvDWePE9WkamCos=";
  });
in {
  services.ollama = {
    enable = true;
    package = ollamaFromGitHub;
    host = "0.0.0.0";
    openFirewall = true;
  };
}
