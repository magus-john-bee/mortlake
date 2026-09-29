# Cognee — shared agent memory (https://cognee.ai, topoteretes/cognee).
#
# Topology: uriel-only service bound to 127.0.0.1:8010, fronted by nginx +
# ACME at cognee.otwell.dev (same vhost pattern as taskdog/silverbullet).
# Clients (pi / prime-agent / hermes, any host) talk HTTPS + X-Api-Key.
#
# Storage: upstream file-based defaults — SQLite (relational), LanceDB
# (vector), Kuzu/Ladybug (graph) — all under /var/lib/cognee (preserved at
# /persistent/var/lib/cognee; see preservation block below). Upstream's own
# Docker image ships exactly this shape (SYSTEM_ROOT_DIRECTORY +
# DATA_ROOT_DIRECTORY). No Postgres on this 1.9GB box; the July Postgres
# plan was superseded when upstream flipped its defaults to file-based
# (docs/cognee-setup-plan.md on private/main is historical). Portability:
# everything is files under one directory — restic snapshots rehydrate on
# any host, and the graph is derived data (re-cognify) if the backend ever
# changes.
#
# Runtime: uv-managed venv built by cognee-venv.service (a oneshot ordered
# before the API service — NOT an activation script, so switches stay fast).
# Nix+uv two-layer philosophy per the ml template: nix provides uv + CPython,
# uv owns the deep/fast-moving Python dep tree. Pinned: cognee[api]==1.6.1.
#
# Auth: ENABLE_BACKEND_ACCESS_CONTROL=true (upstream default) — API requires
# an authenticated user. One admin user (password in sops), one API key per
# agent, issued via /api/v1/auth/apikeys after login. FASTAPI_USERS_JWT_SECRET
# is pinned in sops so tokens/keys survive restarts. Per-user dataset
# isolation exists but all agents share the admin user — the shared brain is
# the point; agent attribution via dataset names.
#
# LLM: GLM via Z.AI (openai-compatible endpoint) for extraction during
# cognify. Embeddings: fastembed default model, local ONNX CPU, no API cost.
_: {
  flake.nixosModules.cognee =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      domain = "cognee.otwell.dev";
      # 8000 is taskdog's loopback port on uriel; cognee takes 8010.
      port = 8010;
      # cognee-mcp proxy (API mode → 8010). 8011 is the hermes plugin's
      # LOCAL-mode port (never bound here — remote mode — but reserved to
      # avoid confusion); proxy takes 8012.
      mcpPort = 8012;
      # Same directory through the preservation bind mount's source path —
      # writable even before the mount exists (first boot / early switch).
      persistentStateDir = "/persistent/var/lib/cognee";
      p = config.sops.placeholder;

      cogneeSpec = "cognee[api]==1.6.1";

      # Pinned by digest (mutable :main tag — digest pin gives rollback and
      # auditability; image bundles cognee 1.5.4 for the proxy's client,
      # which speaks the same v1 API as our 1.6.1 server — verified live
      # 09-29: initialize/tools/list/remember/recall all work).
      cogneeMcpImage = "docker.io/cognee/cognee-mcp@sha256:4e3245d7b5fdb3fbe5f4d3ea8f7b518e320fbf1b37461118add6c9a0c9f713fd";

      # GC-safety: the venv's python symlinks into /nix/store. If that
      # interpreter is ever garbage-collected the venv is dead — detect and
      # rebuild. `uv pip install` on a healthy venv is a fast no-op.
      venvBuildScript = pkgs.writeShellScript "cognee-venv-build" ''
        set -euo pipefail
        mkdir -p ${persistentStateDir}
        if [ ! -x ${persistentStateDir}/venv/bin/python ] \
           || ! ${persistentStateDir}/venv/bin/python -c 'import sys' >/dev/null 2>&1; then
          rm -rf ${persistentStateDir}/venv
          ${pkgs.uv}/bin/uv venv --python ${pkgs.python313}/bin/python3 ${persistentStateDir}/venv
        fi
        ${pkgs.uv}/bin/uv pip install \
          --python ${persistentStateDir}/venv/bin/python '${cogneeSpec}'
      '';
    in
    {
      sops.secrets = {
        "cognee-jwt-secret" = {
          owner = "john";
          sopsFile = ./secrets.yaml;
          restartUnits = [ "cognee.service" ];
        };
        "cognee-admin-password" = {
          owner = "john";
          sopsFile = ./secrets.yaml;
          restartUnits = [ "cognee.service" ];
        };
        # Bearer token gating the public /mcp nginx location (the MCP
        # proxy's own api-token authenticates IT to cognee; this gate is
        # for the outside world). pi-cognee sends no auth headers, so the
        # token rides as ?token= — both channels validated by the nginx map.
        "cognee-mcp-token" = {
          owner = "john";
          sopsFile = ./secrets.yaml;
          restartUnits = [ "nginx.service" ];
        };
      };

      sops.templates."cognee-env" = {
        content = ''
          # Auth — JWT secret pinned in sops so tokens survive restarts.
          FASTAPI_USERS_JWT_SECRET=${p.cognee-jwt-secret}
          ENABLE_BACKEND_ACCESS_CONTROL=True
          # LLM: deepseek-v4.1-flash via OpenRouter — the same cheap-model
          # slug hermes uses for fallback/vision. Extraction doesn't need
          # GLM-level quality; this keeps cognee usage off the Z.AI coding
          # plan. litellm needs the openrouter/ provider prefix.
          LLM_PROVIDER=openrouter
          LLM_API_KEY=${p.openrouter-api-key}
          LLM_MODEL=openrouter/deepseek/deepseek-v4.1-flash
          LLM_TEMPERATURE=0
          # Embeddings: local fastembed (ONNX CPU). Without explicit
          # provider+model, cognee defaults to OpenAI embeddings reusing
          # LLM_API_KEY (401 against the GLM key) — pin both.
          EMBEDDING_PROVIDER=fastembed
          EMBEDDING_MODEL=BAAI/bge-small-en-v1.5
          # Storage roots (SQLite + LanceDB + Kuzu live under these).
          SYSTEM_ROOT_DIRECTORY=${persistentStateDir}/system
          DATA_ROOT_DIRECTORY=${persistentStateDir}/data
          ENV=prod
          PYTHONUNBUFFERED=1
        '';
        owner = "john";
        # Template changes (LLM_*, EMBEDDING_*) must restart the service —
        # without this, a redeployed env lands in the rendered file but the
        # running process keeps the old values (observed live).
        restartUnits = [ "cognee.service" ];
      };

      systemd = {
        # tmpfs home: cognee writes logs to ~/.cognee, which must EXIST
        # before the service's mount namespace is set up (ReadWritePaths on
        # a missing path → 226/NAMESPACE). tmpfiles runs at
        # activation/boot as root.
        tmpfiles.rules = [
          "d /home/john/.cognee 0755 john users -"
          # Kuzu/Ladybug JSON extension auto-installs to ~/.lbdb on first run.
          "d /home/john/.lbdb 0755 john users -"
          "d ${persistentStateDir} 0755 john users -"
          "d ${persistentStateDir}/system 0755 john users -"
          "d ${persistentStateDir}/data 0755 john users -"
        ];

        # One-shot venv builder. uv resolves into ~/.cache/uv (persisted via
        # preservation-common users.john .cache) so rebuilds are warm.
        # LD_LIBRARY_PATH: pip-native wheels (tokenizers etc.) need host
        # libstdc++/zlib — nix-ld doesn't apply inside systemd services
        # (skills/mortlake/nix-ld-systemd-gotcha).
        services.cognee-venv = {
          description = "Cognee venv builder (uv)";
          after = [
            "network-online.target"
            "local-fs.target"
          ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            User = "john";
            Group = "users";
            Environment = [
              "HOME=/home/john"
              "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib"
            ];
            ExecStart = "${venvBuildScript}";
            RemainAfterExit = true;
            TimeoutStartSec = "900";
            ReadWritePaths = [
              persistentStateDir
              "/home/john/.cache"
            ];
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = "read-only";
          };
        };

        # Cognee API server. Requires the venv (built above).
        services.cognee = {
          description = "Cognee — shared agent memory (cognee.otwell.dev)";
          requires = [ "cognee-venv.service" ];
          after = [
            "network-online.target"
            "sops-nix.service"
            "cognee-venv.service"
          ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          environment = {
            HOME = "/home/john";
            # Bind loopback only; nginx is the public edge.
            HTTP_API_HOST = "127.0.0.1";
            HTTP_API_PORT = toString port;
            # pip-native wheels need host libstdc++/zlib (see cognee-venv note).
            LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib";
          };

          serviceConfig = {
            User = "john";
            Group = "users";
            ExecStart = "${persistentStateDir}/venv/bin/python -m cognee.api.client";
            EnvironmentFile = config.sops.templates."cognee-env".path;
            WorkingDirectory = persistentStateDir;
            Restart = "on-failure";
            RestartSec = "5";
            # Lifespan runs migrations at startup; first boot also downloads
            # the fastembed model — give it room.
            TimeoutStartSec = "300";
            # Kuzu/Ladybug WAL must checkpoint cleanly; cognee drains
            # background tasks on shutdown (BACKGROUND_DRAIN_TIMEOUT_SECONDS).
            TimeoutStopSec = "30";
            KillMode = "mixed";
            MemoryMax = "1200M";
            ReadWritePaths = [
              persistentStateDir
              "/home/john/.cognee"
              "/home/john/.lbdb"
              "/home/john/.cache"
            ];
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = "read-only";
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
            ];
            RestrictNamespaces = true;
            LockPersonality = true;
          };
        };

        # ── cognee-mcp proxy (API mode) ─────────────────────────────────
        # Translates MCP (pi-cognee extension, MCP mode) to the cognee
        # REST API. Container, not a venv: the pip package drags
        # cognee[docs,neo4j,postgres-binary] (~3GB) that API mode never
        # runs. Rootful podman — rootless storage lives on the tmpfs root
        # (~/.local/share/containers, 962M total; the 2.77G image needs
        # the preserved /var/lib/containers).
        #
        # Flags verified live 09-29 (tag main @ 4e3245d):
        #  - TRANSPORT_MODE=http + HTTP_PORT → --transport http --host
        #    0.0.0.0 --port $HTTP_PORT via the image entrypoint. We pass
        #    explicit args instead AND override entrypoint — the wrapper
        #    rewrites localhost/127.0.0.1 in API_URL to a docker-bridge
        #    address (host.docker.internal etc.), which is wrong here:
        #    cognee.service binds 127.0.0.1 only and we run --network=host.
        #  - COGNEE_BASE_URL/COGNEE_API_KEY are the flag-less env path
        #    (mcp-local-setup.md) — no URL rewriting.
        #  - COGNEE_API_AUTH_SCHEME=x-api-key: REQUIRED — default bearer
        #    gets 401 from our server (X-Api-Key auth). Live-diagnosed.
        #  - MCP_ALLOWED_HOSTS: FastMCP Host/Origin guard. nginx proxies
        #    with Host: cognee.otwell.dev (recommendedProxySettings), which
        #    the loopback auto-guard would reject — 421/403.
        services.cognee-mcp = {
          description = "Cognee MCP proxy (API mode → cognee.service)";
          after = [
            "network-online.target"
            "cognee.service"
          ];
          wants = [ "network-online.target" ];
          requires = [ "cognee.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            # Pull then run. Image is digest-pinned; podman pull is a
            # no-op when present (fast restarts).
            ExecStartPre = [
              "${pkgs.podman}/bin/podman pull -q ${cogneeMcpImage}"
              "${pkgs.podman}/bin/podman rm -f cognee-mcp >/dev/null 2>&1 || true"
            ];
            ExecStart = pkgs.writeShellScript "cognee-mcp-run" ''
              exec ${pkgs.podman}/bin/podman run --rm \
                --name cognee-mcp \
                --network host \
                --entrypoint cognee-mcp \
                -e COGNEE_BASE_URL=http://127.0.0.1:${toString port} \
                -e COGNEE_API_KEY="$(cat ${config.sops.secrets."cognee-api-key".path})" \
                -e COGNEE_API_AUTH_SCHEME=x-api-key \
                -e MCP_ALLOWED_HOSTS=${domain}:* \
                ${cogneeMcpImage} \
                --transport http --host 127.0.0.1 --port ${toString mcpPort}
            '';
            # Clean stop: podman stop (10s grace) then --rm reaps it.
            ExecStop = "${pkgs.podman}/bin/podman stop -t 10 cognee-mcp || true";
            # Restart policy: cognee.service bouncing pulls the proxy up too.
            Restart = "on-failure";
            RestartSec = "10";
            TimeoutStartSec = "300";
            TimeoutStopSec = "60";
          };
        };
      };

      # All cognee state (SQLite + LanceDB + Kuzu + venv) persists under
      # /var/lib/cognee. Ephemeral by design: ~/.cognee logs and fastembed
      # model cache (~/.cache) — both regenerate.
      preservation.preserveAt."/persistent".directories = [
        {
          directory = "/var/lib/cognee";
          user = "john";
          group = "users";
        }
      ];

      # Public HTTPS entry (ports 80/443 already open in uriel config).
      services.nginx.virtualHosts."${domain}" = lib.mkIf config.services.nginx.enable {
        forceSSL = true;
        enableACME = true;
        locations."/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
        # Chunked LLM responses + long-running cognify pipelines.
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_read_timeout 600s;
            proxy_send_timeout 600s;
          '';
        };
        # MCP endpoint for pi-cognee (and any MCP client). Token-gated:
        # pi-cognee sends no auth headers, so the token rides as ?token=
        # (Authorization: Bearer also accepted — map checks both). The
        # token lives in sops (cognee-mcp-token); the map file is
        # sops-rendered so the token never enters the nix store.
        locations."/mcp" = {
          proxyPass = "http://127.0.0.1:${toString mcpPort}";
          proxyWebsockets = true;
          extraConfig = ''
            # MCP streamable-http: long-lived POST+SSE responses + pings.
            proxy_read_timeout 600s;
            proxy_send_timeout 600s;
            proxy_buffering off;
            # Host must reach the proxy intact (FastMCP DNS-rebinding
            # guard validates it — MCP_ALLOWED_HOSTS on the container).
            proxy_set_header Host ${domain};
            # Gate: 401 unless ?token= or Authorization matches.
            if ($mcp_token_ok = "0") { return 401; }
          '';
        };
      };

      # Token map: $mcp_token_ok = "1" when ?token= or Authorization:
      # Bearer matches the sops secret, "0" otherwise. sops-rendered file
      # included at the http{} level — the token never enters the nix
      # store. sops-nix renders templates before nginx starts (systemd
      # dependency via sops-nix.service), so `nginx -t` at switch sees it.
      sops.templates."cognee-mcp-nginx-map" = {
        content = ''
          map $arg_token $mcp_arg_ok {
              default "0";
              ${p.cognee-mcp-token} "1";
          }
          map $http_authorization $mcp_hdr_ok {
              default "0";
              "Bearer ${p.cognee-mcp-token}" "1";
          }
          map "$mcp_arg_ok$mcp_hdr_ok" $mcp_token_ok {
              default "0";
              "01" "1";
              "10" "1";
              "11" "1";
          }
        '';
        owner = "root";
        group = "nginx";
        mode = "0640";
        restartUnits = [ "nginx.service" ];
      };

      # Include into the http{} block (appendHttpConfig = types.lines).
      # Map directives must live at http{} level, before server{} blocks.
      services.nginx.appendHttpConfig = ''
        include ${config.sops.templates."cognee-mcp-nginx-map".path};
      '';
    };
}
