# Pi — primary AI coding agent (pi.dev). Uses TOML-based hooks and
# TypeScript extensions (not MCP-native). Memory/intelligence stack runs
# via CLI commands: gbrain, context, codebase-memory-mcp.
#
# Pi has native Z.AI support built in:
#   /login zai
#   /model glm-5.2
# The built-in zai provider uses baseUrl: https://api.z.ai/api/coding/paas/v4
# with correct compat flags (thinkingFormat: "zai", supportsDeveloperRole: false).
{ ... }:
{
  flake.nixosModules.pi =
    { config, pkgs, ... }:
    let
      p = config.sops.placeholder;
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

      # TODO: Check whether pi is in nixpkgs or needs installer script.
      # Pi may ship its own installer script.
      environment.systemPackages = with pkgs; [
        pi
        codebase-memory-mcp
      ];

      preservation.preserveAt."/persistent".users.john.directories = [
        ".pi"
      ];
    };
}
