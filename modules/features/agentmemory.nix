_: {
  # DEPRECATION NOTICE: agentmemory is being replaced by gbrain for Pi.
  # This module + agentmemory-plugin/ should be removed once gbrain is
  # proven as the primary memory layer. Until then, keep running on Hermes.
  #
  # Agentmemory is an npm package (@agentmemory/agentmemory), invoked via npx.
  # The Hermes plugin is vendored in this repo at agentmemory-plugin/.

  flake.nixosModules.agentmemory =
    { config, pkgs, ... }:
    let
      p = config.sops.placeholder;
      pluginDir = ./agentmemory-plugin;
    in
    {
      sops.templates."agentmemory-env" = {
        content = ''
          OPENROUTER_API_KEY=${p.openrouter-api-key}
        '';
        owner = "john";
      };

      # User service for john — runs agentmemory worker (REST :3111, streams :3112, viewer :3113)
      systemd.user.services.agentmemory = {
        description = "agentmemory — persistent memory for AI agents";
        after = [ "network.target" ];
        wantedBy = [ "default.target" ];

        path = [
          pkgs.nodejs
          pkgs.curl
          pkgs.bash
          pkgs.which
          pkgs.gnutar
        ];

        environment = {
          HOME = "/home/john";
          NPM_CONFIG_CACHE = "/tmp/npm-cache";
          AGENTMEMORY_URL = "http://localhost:3111";
          OPENROUTER_MODEL = "deepseek/deepseek-v4-flash";
          CONSOLIDATION_ENABLED = "true";
          GRAPH_EXTRACTION_ENABLED = "true";
          AGENTMEMORY_AUTO_COMPRESS = "true";
          AGENTMEMORY_INJECT_CONTEXT = "true";
          AGENTMEMORY_SLOTS = "true";
          LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
        };

        serviceConfig = {
          ExecStart = "${pkgs.nodejs}/bin/npx -y @agentmemory/agentmemory@latest";
          EnvironmentFile = config.sops.templates."agentmemory-env".path;
          Restart = "on-failure";
          RestartSec = "5";
        };
      };

      services.nginx.virtualHosts."uriel-memory.otwell.dev" = {
        forceSSL = true;
        enableACME = true;
        basicAuthFile =
          (pkgs.writeText "agentmemory-htpasswd" "john:$apr1$gxhcZ4qt$H.pTY3z4TX/0RbaRlZk2D1").outPath;
        locations = {
          "/" = {
            proxyPass = "http://localhost:3113";
            extraConfig = ''
              proxy_set_header Host localhost:3113;
              allow 75.130.161.0/24;
              deny all;
            '';
          };
          "/.well-known/acme-challenge" = {
            root = "/var/lib/acme/acme-challenge";
            extraConfig = ''
              allow all;
            '';
          };
        };
      };

      # Belt-and-suspenders cleanup for agentmemory sessions that the Hermes
      # gateway's expiry watcher may have marked as finalized without actually
      # calling agentmemory's session/end endpoint (e.g. after transient API
      # failures or the 3-strike give-up in the gateway watcher). This can leave
      # sessions stuck as "active" in agentmemory forever, which prevents
      # summarisation and consolidation from running on them.
      systemd.user.services.agentmemory-session-sweep = {
        description = "Sweep stale agentmemory sessions";
        after = [ "agentmemory.service" ];
        wants = [ "agentmemory.service" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = let
            sweepScript = pkgs.writeShellScript "agentmemory-session-sweep" ''
              set -eu
              BASE_URL="''${AGENTMEMORY_URL:-http://localhost:3111}"
              # Match the Discord DM reset policy in Hermes config.yaml (180 min)
              # and add a small buffer so we only sweep sessions the gateway
              # should already have finalised.
              IDLE_MINUTES=''${AGENTMEMORY_SWEEP_IDLE_MINUTES:-200}
              echo "Sweeping agentmemory sessions idle >''${IDLE_MINUTES}m..."
              ${pkgs.curl}/bin/curl -fsS "''${BASE_URL}/agentmemory/sessions" \
                | ${pkgs.jq}/bin/jq -r --argjson idle "''${IDLE_MINUTES}" '
                  .sessions[]
                  | select(.status == "active")
                  | select(.updatedAt)
                  | select(
                      (now - (.updatedAt | fromdateiso8601)) / 60 > $idle
                    )
                  | .id
                ' \
                | while read -r sid; do
                    echo "Ending stale session: ''${sid}"
                    ${pkgs.curl}/bin/curl -fsS -X POST "''${BASE_URL}/agentmemory/session/end" \
                      -H "Content-Type: application/json" \
                      -d "{\"sessionId\":\"''${sid}\"}" \
                      > /dev/null || echo "Failed to end ''${sid}"
                  done
              echo "Sweep complete."
            '';
          in "${sweepScript}";
        };
      };

      systemd.user.timers.agentmemory-session-sweep = {
        description = "Timer for agentmemory stale-session sweep";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "1h";
        };
      };

      # Ensure data directory exists, install vendored Hermes plugin
      systemd.tmpfiles.rules = [
        "d /home/john/.agentmemory 0755 john users - -"
        "d /var/lib/hermes/.hermes/plugins 2770 john users - -"
        "L+ /var/lib/hermes/.hermes/plugins/agentmemory - - - - ${pluginDir}"
      ];
    };
}
