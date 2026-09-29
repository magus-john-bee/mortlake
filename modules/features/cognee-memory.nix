# cognee-memory — client wiring for shared agent memory (cognee.otwell.dev).
#
# Server + MCP proxy live in cognee.nix (uriel-only import). This module is
# imported on every host with agent clients:
#   - uriel:   hermes plugin (vendored wheel) + pi/prime-agent extension
#   - jehoel:  pi/prime-agent extension
#   - raphael: pi/prime-agent extension
#
# ── Hermes plugin: why a vendored dir, not extraPlugins ──────────────────
# The upstream hermes-agent NixOS module's extraPlugins symlinks packages as
# plugins/nix-managed-<name>; hermes's memory-provider scanner registers the
# provider under the DIRECTORY name (plugins/memory/__init__.py:
# _iter_provider_dirs → child.name), so memory.provider would have to be
# "nix-managed-cognee" — while every docs page, env var and CLI subcommand
# says "cognee". A plain plugins/cognee symlink (the same shape the old
# agentmemory plugin used) keeps the canonical name. extraPythonPackages is
# out: the plugin is pure-stdlib Python (urllib only) and must NOT drag the
# 2GB cognee PyPI package into hermes' venv — remote mode (COGNEE_BASE_URL)
# never imports it.
#
# ── Plugin facts (verified against wheel 1.2.2 + live server 1.6.1) ─────
# - Layout the scanner keys on: plugins/cognee/__init__.py mentioning
#   register_memory_provider (first 8KB), plus plugin.yaml, cli.py and the
#   cognee_integration_hermes/ package dir copied alongside (installer.py
#   _ROOT_FILES mapping: plugin_init.py → __init__.py).
# - plugin.yaml pins cognee==1.5.4 — inert in remote mode (the pin is for
#   the local embedded server this deployment never spawns).
# - Wire endpoints used: /api/v1/remember, /remember/entry, /recall,
#   /improve, /forget, /datasets, /agents/register, /agents/unregister —
#   all verified present in the live server's openapi.json (09-29).
# - Auth: X-Api-Key from COGNEE_API_KEY — REQUIRED for remote URLs; the
#   plugin refuses to start without it rather than failing 401 per call.
# - Do NOT run `hermes memory setup` on the deployed host afterwards: it
#   writes $HERMES_HOME/cognee.json whose values take precedence over env.
#
# ── pi extension facts (verified live 09-29, pi 0.87.1) ─────────────────
# - `pi install npm:@kerryhatcher/pi-cognee` lands in
#   ~/.pi/agent/npm/node_modules/... (.pi preserved via pi.nix) and merges
#   "packages": ["npm:@kerryhatcher/pi-cognee"] into ~/.pi/agent/settings.json
#   — same merge-update discipline as pi-model-defaults in pi.nix.
# - Extension config: ~/.pi/agent/cognee-config.json (mode, mcpUrl). In MCP
#   mode only mcpUrl matters — LLM/embedding config lives server-side.
# - The MCP client sends NO auth headers (Content-Type/Accept/mcp-session-id
#   only) — auth rides the ?token= query param, enforced by nginx on uriel
#   (map over $arg_token, see cognee.nix). The token (sops
#   cognee-mcp-token, declared in sops.nix → rendered on every host) is
#   merged into cognee-config.json at activation; it never lands in the
#   nix store.
# - recall is cross-dataset by default; the proxy scopes WRITES to
#   {client}_memory datasets for attribution (COGNEE_MCP_AGENT_SCOPED).
#   pi_cognee_memory is expected — not drift.
# - prime-agent: ~/.prime/agent is a separate config tree from ~/.pi, but
#   pi extensions load from ~/.pi/agent/npm via pi's shared loader. The
#   config mirror below covers the (unverified) case that prime reads its
#   own cognee-config.json — check live after deploy; harmless if unused.
{
  perSystem =
    { pkgs, lib, ... }:
    {
      # Vendored hermes memory-provider plugin, in the directory layout
      # hermes's scanner expects. Data-only derivation (no python build).
      # Upstream: https://pypi.org/project/cognee-integration-hermes-agent/
      # Wheel is pure-stdlib (urllib HTTP client); remote mode never
      # imports the cognee package despite plugin.yaml's pin.
      #
      # Upgrading: bump version + wheel hash (nix-prefetch-url the new
      # wheel from pypi.org/pypi/cognee-integration-hermes-agent/json);
      # if the wheel ever grows a non-stdlib import, extraPythonPackages
      # becomes unavoidable.
      packages.cognee-hermes-plugin =
        let
          version = "1.2.2";
          # Wheel layout: cognee_integration_hermes/ (the package) +
          # cognee_integration_hermes/_plugin_root/ (plugin.yaml, cli.py,
          # plugin_init.py, after-install.md). installer.py maps
          # plugin_init.py → __init__.py at the plugin root.
          wheel = pkgs.fetchurl {
            url = "https://files.pythonhosted.org/packages/0e/e9/cb65f5feddfc9498f6de3c9a968e78e5bcf9849e38c10fa7ed6288fe046f/cognee_integration_hermes_agent-1.2.2-py3-none-any.whl";
            hash = "sha256-OZHHI5810XH45PaXJSOqJEnyws32+2g7UpCtbtCEh9E=";
          };
        in
        pkgs.stdenv.mkDerivation {
          pname = "cognee-hermes-plugin";
          inherit version;
          dontUnpack = true;
          nativeBuildInputs = [ pkgs.python3 ];
          installPhase = ''
            runHook preInstall
            mkdir -p $out
            python3 - <<'PYEOF'
            import zipfile, os, shutil
            out = os.environ["out"]
            with zipfile.ZipFile("${wheel}") as z:
                z.extractall(out + "/.wheel")
            pkg = out + "/.wheel/cognee_integration_hermes"
            root = pkg + "/_plugin_root"
            # Plugin root files: __init__.py is plugin_init.py renamed
            # (installer.py _ROOT_FILES).
            shutil.copyfile(root + "/plugin_init.py", out + "/__init__.py")
            for f in ("plugin.yaml", "cli.py", "after-install.md"):
                shutil.copyfile(root + "/" + f, out + "/" + f)
            # The package itself sits inside the plugin dir (installer.py
            # copies the whole package; hermes imports it relative to the
            # plugin root).
            shutil.copytree(
                pkg, out + "/cognee_integration_hermes",
                ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "_plugin_root"),
            )
            shutil.rmtree(out + "/.wheel")
            PYEOF
            runHook postInstall
          '';
          meta = {
            description = "Cognee memory provider plugin for Hermes Agent (vendored wheel, remote mode)";
            homepage = "https://docs.cognee.ai/integrations/hermes-agent-integration";
            license = lib.licenses.mit;
          };
        };
    };

  flake.nixosModules.cogneeMemory =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      cfg = config.services.cognee-memory;
      mcpUrl = "https://cognee.otwell.dev/mcp";
      plugin = self.packages.${pkgs.stdenv.hostPlatform.system}.cognee-hermes-plugin;
    in
    {
      options.services.cognee-memory = {
        enable = lib.mkEnableOption "cognee memory clients (hermes plugin + pi/prime-agent extension)";

        hermes = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Install the vendored cognee plugin into Hermes and make it the active memory provider (uriel only).";
          };
          dataset = lib.mkOption {
            type = lib.types.str;
            default = "agent_memory";
            description = "COGNEE_PLUGIN_DATASET — hermes' dataset in the shared brain.";
          };
        };

        pi = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Seed @kerryhatcher/pi-cognee (MCP mode) into ~/.pi for pi + prime-agent.";
          };
        };
      };

      config = lib.mkMerge [
        # ── Hermes (uriel) ──────────────────────────────────────────────
        (lib.mkIf (cfg.enable && cfg.hermes.enable) {
          # Plugin symlink: plugins/cognee → nix store, recreated every
          # activation (Hermes home is persistent but the symlink is
          # cheap to reassert; the old agentmemory symlink — dead since
          # its store path was GC'd — is retired here too).
          system.activationScripts.cognee-hermes-plugin.text = ''
            mkdir -p /var/lib/hermes/.hermes/plugins
            ln -sfn ${plugin} /var/lib/hermes/.hermes/plugins/cognee
            chown -h john:users /var/lib/hermes/.hermes/plugins/cognee
            rm -f /var/lib/hermes/.hermes/plugins/agentmemory
          '';

          # Provider flip + env. settings deep-merge over the live
          # config.yaml (nix keys win; the hermes module's merge script
          # preserves user-added keys).
          services.hermes-agent = {
            settings.memory.provider = "cognee";
            environmentFiles = [
              (config.sops.templates."cognee-client-env".path)
            ];
          };

          # Client env via sops template (renders at /run/secrets/cognee-client-env).
          # COGNEE_BASE_URL selects remote mode; dataset shares the one brain.
          sops.templates."cognee-client-env" = {
            content = ''
              COGNEE_BASE_URL=https://cognee.otwell.dev
              COGNEE_API_KEY=${config.sops.placeholder.cognee-api-key}
              COGNEE_PLUGIN_DATASET=${cfg.hermes.dataset}
              COGNEE_IMPROVE_ON_END=true
            '';
            owner = "john";
          };
        })

        # ── pi + prime-agent (all hosts) ────────────────────────────────
        (lib.mkIf (cfg.enable && cfg.pi.enable) {
          # stringAfter setupSecrets: the script READS the sops-rendered
          # MCP token to build mcpUrl — without the ordering it can run
          # before sops-nix renders secrets (empty token until next
          # activation). "users" for /home/john to exist.
          system.activationScripts.cognee-pi-extension = lib.stringAfter (
            [ "users" ]
            ++ lib.optional (config.system.activationScripts ? setupSecrets) "setupSecrets"
          ) ''
            mkdir -p /home/john/.pi/agent
            # 1. npm-install the extension if missing. nodejs comes from
            #    pi.nix systemPackages (activation PATH includes the
            #    system profile); .pi is preserved so this self-heals a
            #    lost node_modules and is a no-op otherwise.
            if [ ! -d /home/john/.pi/agent/npm/node_modules/@kerryhatcher/pi-cognee ]; then
              npm --prefix /home/john/.pi/agent/npm install @kerryhatcher/pi-cognee >/dev/null 2>&1 || true
            fi
            # 2. merge "packages" into ~/.pi/agent/settings.json (append-only,
            #    never clobbers user prefs — same discipline as
            #    pi-model-defaults in pi.nix).
            # 3. merge mode+mcpUrl(+token) into cognee-config.json for pi
            #    and prime-agent (separate config trees).
            ${pkgs.python3}/bin/python3 - <<'PYEOF'
            import json, os
            def merge(path, updates):
                try:
                    with open(path) as f: d = json.load(f)
                except (FileNotFoundError, json.JSONDecodeError): d = {}
                d.update(updates)
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, "w") as f: json.dump(d, f, indent=2)
            spath = "/home/john/.pi/agent/settings.json"
            try:
                with open(spath) as f: s = json.load(f)
            except (FileNotFoundError, json.JSONDecodeError): s = {}
            pkgs_list = s.get("packages", [])
            if "npm:@kerryhatcher/pi-cognee" not in pkgs_list:
                pkgs_list.append("npm:@kerryhatcher/pi-cognee")
                s["packages"] = pkgs_list
                with open(spath, "w") as f: json.dump(s, f, indent=2)
            token = ""
            try:
                token = open("/run/secrets/cognee-mcp-token").read().strip()
            except OSError:
                pass
            url = "${mcpUrl}" + ("?token=" + token if token else "")
            merge("/home/john/.pi/agent/cognee-config.json", {"mode": "mcp", "mcpUrl": url})
            try:
                merge("/home/john/.prime/agent/cognee-config.json", {"mode": "mcp", "mcpUrl": url})
            except OSError:
                pass
            PYEOF
            chown -R john:users /home/john/.pi/agent 2>/dev/null || true
            chown -R john:users /home/john/.prime/agent 2>/dev/null || true
          '';
        })
      ];
    };
}
