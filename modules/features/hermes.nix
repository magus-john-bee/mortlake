{ self, inputs, ... }:
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

      sops.templates."hermes-env" = {
        content = ''
          ELEVENLABS_API_KEY=${p.elevenlabs-api-key}
          EXA_API_KEY=${p.exa-api-key}
          GLM_API_KEY=${p.glm-api-key}
          GROQ_API_KEY=${p.groq-api-key}
          DEEPSEEK_API_KEY=${p.deepseek-api-key}
          OPENROUTER_API_KEY=${p.openrouter-api-key}
          HF_TOKEN=${p.hf-token}
          LOGSEQ_PATH=/home/john/vault/logbook
          GLM_BASE_URL=https://api.z.ai/api/coding/paas/v4
          DISCORD_BOT_TOKEN=${p.discord-bot-token}
          DISCORD_ALLOWED_USERS=${p.discord-allowed-users}
          DISCORD_HOME_CHANNEL=${p.discord-home-channel}
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
        environmentFiles = [ config.sops.templates."hermes-env".path ];
        extraDependencyGroups = [
          "exa"
          "messaging"
          "tts-premium"
          "voice"
        ];

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
            model = "deepseek/deepseek-v4-pro";
          };

          stt = {
            provider = "groq";
          };

          tts = {
            provider = "elevenlabs";
            elevenlabs = {
              voice_id = "fATgBRI8wg5KkDFg8vBd";
              model_id = "eleven_multilingual_v2";
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
              model = "moonshotai/kimi-k2.7-code";
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
