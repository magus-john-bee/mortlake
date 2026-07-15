{ lib, ... }:
{
  flake.nixosModules.codexSafe =
    { config, pkgs, ... }:
    let
      p = config.sops.placeholder;
      codexEnvFile = config.sops.templates."codex-env".path;

      baseConfig = builtins.readFile ./codex-shared/config.toml;

      # Minimal safe config — workspace-write sandbox, no MCP servers
      safeBase = lib.replaceStrings
        [
          ''approval_policy = "on-request"''
          ''sandbox_mode = "read-only"''
        ]
        [
          ''approval_policy = "never"''
          ''sandbox_mode = "workspace-write"''
        ]
        baseConfig;

      safeConfig = pkgs.writeText "codex-safe.toml" safeBase;
      agentsFile = ./codex-shared/AGENTS.md;

      codexWrapper = pkgs.writeShellScriptBin "codex" ''
        export CODEX_HOME="''${HOME}/.codex"
        mkdir -p "$CODEX_HOME"
        cp ${safeConfig} "$CODEX_HOME/nix-safe.config.toml"
        chmod 644 "$CODEX_HOME/nix-safe.config.toml"
        cp ${agentsFile} "$CODEX_HOME/AGENTS.md"
        chmod 644 "$CODEX_HOME/AGENTS.md"
        set -a
        source ${codexEnvFile} 2>/dev/null
        set +a
        exec ${pkgs.codex}/bin/codex -p nix-safe "$@"
      '';
    in
    {
      sops.templates."codex-env" = {
        content = ''
          GLM_API_KEY=${p.glm-api-key}
          OPENROUTER_API_KEY=${p.openrouter-api-key}
          GROQ_API_KEY=${p.groq-api-key}
          DEEPSEEK_API_KEY=${p.deepseek-api-key}
          EXA_API_KEY=${p.exa-api-key}
        '';
        owner = "john";
      };

      environment = {
        etc = {
          "codex/config.toml".source = ./codex-shared/config.toml;
          "codex/models.json".source = ./codex-shared/models.json;
          "codex/skills".source = ./../../skills;
        };
        systemPackages = [ codexWrapper ];
      };

      # Persist codex state across reboots (session history, trust cache)
      preservation.preserveAt."/persistent" = {
        users.john.directories = [ ".codex" ];
      };
    };
}
