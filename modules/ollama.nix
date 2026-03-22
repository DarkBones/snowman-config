{ config, inputs, lib, pkgsUnstable, ... }:
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

  systemd.services.ollama = {
    environment = {
      # Keep Open WebUI from silently pushing very large default contexts.
      OLLAMA_CONTEXT_LENGTH = "4096";
      OLLAMA_KEEP_ALIVE = "10m";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_MAX_QUEUE = "2";
      OLLAMA_NUM_PARALLEL = "1";

      # Ollama is currently falling back to CPU-only inference on dorkbones.
      OLLAMA_LLM_LIBRARY = "cuda";
      CUDA_VISIBLE_DEVICES = "0";
      LD_LIBRARY_PATH = lib.makeLibraryPath [ config.hardware.nvidia.package ];
    };

    serviceConfig = {
      MemoryHigh = "20G";
      MemoryMax = "24G";
      SupplementaryGroups = [ "render" "video" ];
    };
  };
}
