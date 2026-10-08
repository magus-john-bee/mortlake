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
        "messaging"
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

      # The hermes env consumes the 'hermes' taskdog API key; declare it
      # here so this module evaluates on any host. (sops.placeholder
      # requires a matching sops.secrets declaration; previously the
      # taskdog SERVER block supplied it — turning uriel's server off
      # broke uriel's eval. Values identical to taskdog.nix's secretOpts,
      # so double declarations on server hosts merge cleanly.)
      sops.secrets."taskdog-api-key-hermes" = {
        owner = "john";
        sopsFile = ./secrets.yaml;
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

        # v37 matches hermes-agent at the bumped flake input (1c4dc4c)'s rev. The module
        # deep-merges settings over the live config additively; this stamp
        # keeps `hermes doctor` from flagging drift after every rebuild.
        settings._config_version = 37;

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
            # V4.1 Flash (2026-09-10, CED arch) — retires V4-Pro; vision is
            # native, so fallback and vision share one slug.
            model = "deepseek/deepseek-v4.1-flash";
          };

          stt = {
            provider = "groq";
          };

          tts = {
            # Voxtral (Mistral) — switched from ElevenLabs 2026-09-28.
            # Key: mistral-api-key via hermes-env; SDK via the "mistral" extra.
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
              # Native multimodal in V4.1 Flash — replaces retired vision-exp.
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
      ];

      systemd.services.hermes-agent = {
        environment = {
          LD_LIBRARY_PATH = "${pkgs.libopus.outPath}/lib:${pkgs.stdenv.cc.cc.lib}/lib";
        };
        path = [
          pkgs.binutils
          pkgs.nodejs
        ];
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
