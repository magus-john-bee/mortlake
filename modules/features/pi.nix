# Pi — primary AI coding agent (pi.dev). Uses TOML-based hooks and
# TypeScript extensions (not MCP-native). Memory/intelligence stack runs
# via CLI commands: gbrain, context, codebase-memory-mcp.
#
# In nixpkgs as `pi-coding-agent` (buildNpmPackage). Binary is `pi`.
# The nixpkgs package wraps pi with ripgrep and fd on PATH.
#
# Pi extensions need npm at runtime (they install to ~/.pi/agent/npm/).
# Consider wrapping with nodejs on PATH when extensions are needed.
#
# Pi has native Z.AI support built in:
#   /login zai
#   /model glm-5.2
# The built-in zai provider uses baseUrl: https://api.z.ai/api/coding/paas/v4
# with correct compat flags (thinkingFormat: "zai", supportsDeveloperRole: false).
#
# Also includes Prime Agent (PrimeIntellect) — a self-improving RLM agent
# built on top of pi. Adds persistent IPython control environment and
# Continual Harness state. Config: ~/.prime/agent/
# Binary: prime-agent. Requires Node.js 22.8.0+ at runtime.
#
# Both pi and prime-agent are also in numtide/llm-agents.nix, but pi is
# already in nixpkgs (pi-coding-agent) which is simpler to consume.
# prime-agent comes from llm-agents.nix (not yet in nixpkgs).
{ inputs, ... }:
{
  flake.nixosModules.pi =
    { config, pkgs, lib, ... }:
    let
      p = config.sops.placeholder;
      inherit (pkgs.stdenv.hostPlatform) system;
      prime-agent = inputs.llm-agents.packages.${system}.prime-agent;
    in
    {
      sops.templates."pi-env" = {
        content = ''
          ZAI_API_KEY=${p.glm-api-key}
          OPENROUTER_API_KEY=${p.openrouter-api-key}
          EXA_API_KEY=${p.exa-api-key}
        '';
        owner = "john";
      };

      environment.systemPackages = [
        pkgs.pi-coding-agent
        prime-agent
      ];

      # llm-agents.nix binary cache
      nix.settings = {
        extra-substituters = [ "https://cache.numtide.com" ];
        extra-trusted-public-keys = [
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        ];
      };

      preservation.preserveAt."/persistent".users.john.directories = [
        ".pi"
        ".prime"
      ];
    };
}
