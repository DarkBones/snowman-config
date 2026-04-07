{ inputs, pkgsUnstable, ... }:
let
  ollamaFromGitHub = pkgsUnstable.ollama-cuda.overrideAttrs (_: {
    version = "0.20.2";
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
      OLLAMA_KV_CACHE_TYPE = "q8_0";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_MAX_QUEUE = "2";
      OLLAMA_NUM_PARALLEL = "1";
      # Reserve VRAM so Ollama doesn't overcommit the 16 GiB card on large models.
      OLLAMA_GPU_OVERHEAD = "2147483648";

      CUDA_VISIBLE_DEVICES = "0";
    };

    serviceConfig = {
      MemoryHigh = "20G";
      MemoryMax = "24G";
      SupplementaryGroups = [ "render" "video" ];
    };
  };
}
