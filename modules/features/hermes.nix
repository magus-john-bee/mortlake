{ inputs, ... }:
{
  flake.nixosModules.hermes =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;
      p = config.sops.placeholder;

      enabled-toolsets = [
        "search"
        "vision"
        "terminal"
        "skills"
        "cronjob"
        "file"
        "tts"
        "todo"
        "memory"
        "session_search"
        "clarify"
        "code_execution"
      ];
    in
    {
      imports = [ inputs.hermes-agent.nixosModules.default ];

      # Secrets consumed by the hermes-env template below. Declared here
      # unconditionally so this module evaluates on any host: sops.placeholder
      # requires a matching sops.secrets declaration, and the supplying modules
      # (gh.nix, taskdog.nix) gate theirs on jehoel / the taskdog server.
      # Values identical to those, so double declarations merge cleanly.
      sops.secrets = {
        # uriel-gh-pat-for-jehoel -> GH_TOKEN: default gh identity for agent
        # sessions (see template).
        "uriel-gh-pat-for-jehoel" = {
          owner = "john";
          sopsFile = ./secrets.yaml;
        };
        # taskdog: previously the taskdog SERVER block supplied it — turning
        # uriel's server off broke uriel's eval.
        "taskdog-api-key-hermes" = {
          owner = "john";
          sopsFile = ./secrets.yaml;
        };
      };

      sops.templates."hermes-env" = {
        content = ''
          EXA_API_KEY=${p.exa-api-key}
          FAL_KEY=${p.fal-api-key}
          GLM_API_KEY=${p.glm-api-key}
          GROQ_API_KEY=${p.groq-api-key}
          MISTRAL_API_KEY=${p.mistral-api-key}
          OPENROUTER_API_KEY=${p.openrouter-api-key}
          LOGSEQ_PATH=/home/john/vault/logbook
          GLM_BASE_URL=https://api.z.ai/api/coding/paas/v4
          DISCORD_BOT_TOKEN=${p.discord-bot-token}
          DISCORD_ALLOWED_USERS=${p.discord-allowed-users}
          DISCORD_HOME_CHANNEL=${p.discord-home-channel}
          # Default gh identity for Hermes service sessions: uriel-mortlake.
          # GH_TOKEN overrides gh's active account (/etc/gh keeps magus-john-bee
          # active for john's interactive shells); the credRouter still serves
          # --user lookups for both identities from hosts.yml. Proven by test
          # 2026-10-09: GH_TOKEN=<uriel PAT> gh api user -> uriel-mortlake.
          GH_TOKEN=${p.uriel-gh-pat-for-jehoel}
          TASKDOG_API_BASE_URL=https://taskdog.otwell.dev
          TASKDOG_API_KEY=${p.taskdog-api-key-hermes}
        '';
        owner = "john";
      };

      services.hermes-agent = {
        enable = true;
        user = "john";
        group = "users";
        createUser = false;
        package = inputs.hermes-agent.packages.${system}.default;
        addToSystemPackages = true;
        # hermes-env template (sops secrets rendered below)
        environmentFiles = [ config.sops.templates."hermes-env".path ];
        extraDependencyGroups = [
          "exa"
          "messaging"
          "mistral"
          "tts-premium"
          "voice"
        ];

        # v50 matches hermes-agent at the bumped flake input (73162b0)'s
        # DEFAULT_CONFIG._config_version. The module deep-merges settings over
        # the live config additively; this stamp keeps `hermes doctor` from
        # flagging drift after every rebuild.
        settings._config_version = 50;

        settings = {
          approvals.mode = "off";
          toolsets = enabled-toolsets;

          platform_toolsets.cli = enabled-toolsets;

          security.tirith_enabled = false;

          model = {
            provider = "zai";
            default = "glm-5.3";
            # Hermes' hardcoded fallback for GLM is 202,752 (~200K).
            # GLM-5.2 actually has a 1M context window.
            context_length = 1048576;
          };

          fallback_model = {
            provider = "openrouter";
            model = "deepseek/deepseek-v4.1-flash";
          };

          stt = {
            provider = "groq";
          };

          tts = {
            provider = "mistral";
            mistral = {
              model = "voxtral-mini-tts-2603";
              voice_id = "e3596645-b1af-469e-b857-f18ddedc7652";
            };
          };

          smart_model_routing = {
            enabled = true;
            cheap_model = {
              provider = "groq";
              model = "openai/gpt-oss-20b";
            };
          };

          auxiliary = {
            vision = {
              provider = "openrouter";
              model = "deepseek/deepseek-v4.1-flash";
            };
            flush_memories = {
              provider = "groq";
              model = "openai/gpt-oss-20b";
              timeout = 60;
            };
          };

          session_reset = {
            reset_by_platform = {
              discord = {
                mode = "idle";
                idle_minutes = 180;
              };
            };
          };

          provider_routing = {
            sort = "throughput";
          };

          memory = {
            memory_char_limit = 6000;
            user_char_limit = 3000;
          };

          compression = {
            enabled = true;
            threshold = 0.9;
          };

          skills = {
            config.wiki.path = "/home/john/vault/book-of-thoth";
            external_dirs = [ "/home/john/src/mortlake/skills" ];
          };

          documents."SOUL.md" = builtins.readFile ./hermes/SOUL.md;
        };

        # Trimmed MCP servers — removed mempalace, codegraph, procontext, ouroboros, agentmemory
        mcpServers = {
          codebase-memory = {
            command = "${pkgs.codebase-memory-mcp}/bin/codebase-memory-mcp";
            args = [ ];
            enabled = true;
          };
          context = {
            command = "npx";
            args = [
              "@neuledge/context"
              "serve"
            ];
            enabled = true;
          };
          exa = {
            url = "https://mcp.exa.ai/mcp?tools=web_search_exa,web_fetch_exa,web_search_advanced_exa,get_code_context_exa";
            # Escaped \${...} → literal ${EXA_API_KEY} in config.yaml.
            # Hermes interpolates ${VAR} at MCP-connect time from the
            # gateway process env, which carries EXA_API_KEY via the
            # sops hermes-env template. (builtins.getEnv baked the
            # *building* host's env in at eval time — empty on jehoel.)
            headers = {
              x-api-key = "\${EXA_API_KEY}";
            };
          };
          nixos = {
            command = "uvx";
            args = [ "mcp-nixos" ];
            enabled = true;
          };
          gitmcp = {
            url = "https://gitmcp.io/docs";
            enabled = true;
          };
        };
      };

      # /var/lib/hermes must exist and be owned by the service user before
      # the gateway starts. Preservation creates the bind-mount point
      # root-owned on first provisioning (tmpfs-root), which crashes the
      # Discord adapter with EACCES on .local/ (bitten at the 2026-10-08
      # cutover — fixed imperatively then; this makes it permanent).
      systemd.tmpfiles.rules = [
        "d /var/lib/hermes 0755 ${config.services.hermes-agent.user} ${config.services.hermes-agent.group} -"
        # XDG dirs the service user's CLIs create on first use (taskdog wants
        # ~/.config/taskdog; other agents hit .local/.cache). Without the
        # rule, preservation re-creates the parent root-owned after a wipe
        # and every CLI in the gateway env dies with EACCES — silently kills
        # cron jobs that shell out (trash task, 2026-10-08).
        "d /var/lib/hermes/.config 0750 ${config.services.hermes-agent.user} ${config.services.hermes-agent.group} -"
        "d /var/lib/hermes/.local 0770 ${config.services.hermes-agent.user} ${config.services.hermes-agent.group} -"
        "d /var/lib/hermes/.cache 0770 ${config.services.hermes-agent.user} ${config.services.hermes-agent.group} -"
      ];

      systemd.services.hermes-agent = {
        environment = {
          LD_LIBRARY_PATH = "${pkgs.libopus.outPath}/lib:${pkgs.stdenv.cc.cc.lib}/lib";
        };
        path = [
          pkgs.binutils
          pkgs.nodejs
        ];
        # pm's lockfile pins ffmpeg+ripgrep as required tools, but a sealed
        # nix artifact delegates its tool store to the user-writable
        # $HERMES_HOME/tools (node/npm/python/uv land there at first boot).
        # When a flake bump re-pins a tool version, drift makes the gateway
        # print "install out of sync" until the store catches up. Self-heal
        # at service start: doctor exits 1 on drift, install --tools-only
        # writes only the writable store (never the nix store).
        preStart = ''
          if ! ${config.services.hermes-agent.package}/bin/hermes pm doctor >/dev/null 2>&1; then
            echo "hermes-agent: pm tool store drifted from lockfile; healing ffmpeg/ripgrep/…"
            ${config.services.hermes-agent.package}/bin/hermes pm install --tools-only >/dev/null 2>&1 || true
          fi
        '';
        serviceConfig = {
          NoNewPrivileges = lib.mkForce false;
        };
      };

      # NOTE: cognee memory wiring removed 2026-10-02 — server decommissioned
      # (cognee.nix/cognee-memory.nix deleted; secrets dropped from sops).
      # Hermes runs the built-in MEMORY.md/USER.md provider; icm lands separately.

      environment.systemPackages = [
        pkgs.ffmpeg
        pkgs.yt-dlp
        pkgs.libopus
        pkgs.codebase-memory-mcp
        # pdftotext et al. for Hermes text-extraction (TODO.md, PR #68)
        pkgs.poppler-utils
      ];
    };
}
