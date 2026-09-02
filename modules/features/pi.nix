# Pi — primary AI coding agent (pi.dev). Uses TOML-based hooks and
# TypeScript extensions (not MCP-native).
#
# In nixpkgs as `pi-coding-agent` (buildNpmPackage). Binary is `pi`.
# The nixpkgs package wraps pi with ripgrep and fd on PATH.
#
# Pi extensions need npm at runtime (they install to ~/.pi/agent/npm/);
# nodejs is declared in systemPackages below so the dependency travels
# with this module (prime-agent also requires Node.js 22.8.0+).
#
# Pi has native Z.AI support built in:
#   /login zai
#   /model glm-5.3
# The built-in zai provider uses baseUrl: https://api.z.ai/api/coding/paas/v4
# with correct compat flags (thinkingFormat: "zai", supportsDeveloperRole: false).
#
# Also includes Prime Agent (PrimeIntellect) — a self-improving RLM agent
# built on top of pi. Adds persistent IPython control environment and
# Continual Harness state. Config: ~/.prime/agent/
# Binary: prime-agent. Requires Node.js 22.8.0+ at runtime.
# Both pi and prime-agent are also in numtide/llm-agents.nix, but pi is
# already in nixpkgs (pi-coding-agent) which is simpler to consume.
# prime-agent comes from llm-agents.nix (not yet in nixpkgs).
#
# Versions (2026-08-18 audit, post flake bump #94):
#   pi-coding-agent 0.84.2 (nixpkgs; was 0.80.7 live)
#   prime-agent     0.7.2  (llm-agents.nix; was 0.7.0 live)
# auth.json format unchanged — {"zai":{"type":"api_key","key":...}} matches
# AuthStorageData in pi 0.84.2 type defs.
#
# TODO: Context enrichment stack (deferred — add after first boot):
#   1. codebase-memory-mcp — C11 MCP server, indexes codebases into a
#      knowledge graph. In nixpkgs as pkgs.codebase-memory-mcp (v0.8.1).
#      158 languages, sub-ms queries, SQLite-backed.
#   2. neuledge/context — local-first library docs (.db files, SQLite FTS5).
#      npm: @neuledge/context. Not in nixpkgs or llm-agents.nix.
#   3. cognee — semantic memory + synthesis, backed by Postgres.
#      Shared across all agents (Pi + Hermes). Python, needs Postgres.
#      Not in nixpkgs. Host: Uriel or Jehoel (TBD).
{ inputs, ... }:
{
  flake.nixosModules.pi =
    {
      config,
      pkgs,
      ...
    }:
    let
      p = config.sops.placeholder;
      inherit (pkgs.stdenv.hostPlatform) system;
      prime-agent = inputs.llm-agents.packages.${system}.prime-agent;
    in
    {
      sops.templates."pi-auth.json" = {
        content = ''
          {"zai":{"type":"api_key","key":"${p.glm-api-key}"},"openrouter":{"type":"api_key","key":"${p.openrouter-api-key}"}}
        '';
        owner = "john";
      };

      system.activationScripts.pi-auth.text = ''
        mkdir -p /home/john/.pi/agent
        ln -sf ${config.sops.templates."pi-auth.json".path} /home/john/.pi/agent/auth.json
        chown -h john:users /home/john/.pi/agent/auth.json
      '';

      # Declarative model defaults (vanilla pi settings). Without these, pi's
      # model-resolver walks its known-provider table and openrouter's default
      # (moonshotai/kimi-k2.6) wins on any host with both keys — seen live on
      # jehoel. Primary is GLM 5.3 via the ZAI coding plan.
      #
      # settings.json is ALSO pi's user-preference store (theme, editor,
      # ctrl+s saves) — merge-update only the default keys, never clobber.
      system.activationScripts.pi-model-defaults.text = ''
        mkdir -p /home/john/.pi/agent
        ${pkgs.python3}/bin/python3 - <<'EOF'
        import json, os
        path = os.path.expanduser("/home/john/.pi/agent/settings.json")
        try:
            with open(path) as f:
                settings = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            settings = {}
        settings["defaultProvider"] = "zai"
        settings["defaultModel"] = "glm-5.3"
        with open(path, "w") as f:
            json.dump(settings, f, indent=2)
        EOF
        chown john:users /home/john/.pi/agent/settings.json 2>/dev/null || true
      '';

      # Shared agent skills: mortlake's skills/ tree is the cross-agent source
      # of truth (Hermes reads it via skills.external_dirs; see
      # corpus-nixos-modules "Shared Agent Skills Directory"). pi and
      # prime-agent discover it through the Agent Skills standard location
      # ~/.agents/skills (both scan it; project .agents/skills too). The
      # symlink is recreated at activation because /home/john is tmpfs.
      system.activationScripts.pi-agent-skills.text = ''
        mkdir -p /home/john/.agents
        ln -sfn /home/john/src/mortlake/skills /home/john/.agents/skills
        chown john:users /home/john/.agents
        chown -h john:users /home/john/.agents/skills
      '';

      environment.systemPackages = [
        pkgs.pi-coding-agent
        prime-agent
        # Runtime for pi extensions (npm) and prime-agent (Node.js >= 22.8.0).
        # Declared here rather than relying on packages.nix's nodejs by
        # coincidence.
        pkgs.nodejs
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
