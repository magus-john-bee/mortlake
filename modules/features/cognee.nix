# Cognee — shared agent memory (https://cognee.ai, topoteretes/cognee).
#
# Topology: uriel-only service bound to 127.0.0.1:8000, fronted by nginx +
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
      port = 8000;
      # Same directory through the preservation bind mount's source path —
      # writable even before the mount exists (first boot / early switch).
      persistentStateDir = "/persistent/var/lib/cognee";
      p = config.sops.placeholder;

      cogneeSpec = "cognee[api]==1.6.1";

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
      };

      sops.templates."cognee-env" = {
        content = ''
          # Auth — JWT secret pinned in sops so tokens survive restarts.
          FASTAPI_USERS_JWT_SECRET=${p.cognee-jwt-secret}
          ENABLE_BACKEND_ACCESS_CONTROL=True
          # LLM: GLM via Z.AI coding endpoint (openai-compatible).
          LLM_PROVIDER=openai
          LLM_API_KEY=${p.glm-api-key}
          LLM_ENDPOINT=https://api.z.ai/api/coding/paas/v4
          LLM_MODEL=glm-5.3
          LLM_TEMPERATURE=0
          # Storage roots (SQLite + LanceDB + Kuzu live under these).
          SYSTEM_ROOT_DIRECTORY=${persistentStateDir}/system
          DATA_ROOT_DIRECTORY=${persistentStateDir}/data
          ENV=prod
          PYTHONUNBUFFERED=1
        '';
        owner = "john";
      };

      systemd = {
        # tmpfs home: cognee writes logs to ~/.cognee, which must EXIST
        # before the service's mount namespace is set up (ReadWritePaths on
        # a missing path → 226/NAMESPACE). tmpfiles runs at
        # activation/boot as root.
        tmpfiles.rules = [
          "d /home/john/.cognee 0755 john users -"
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
      };
    };
}
