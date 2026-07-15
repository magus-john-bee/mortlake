_:
{
  flake.nixosModules.restic =
    { config, lib, pkgs, ... }:
    let
      inherit (config.sops) secrets templates;
      p = config.sops.placeholder;
      inherit (config.networking) hostName;

      supersecrets = {
        owner = "john";
        sopsFile = ./supersecrets.yaml;
      };

      hostConfig = {
        # Uriel (was thoth) — Hetzner VPS
        uriel = {
          name = "uriel";
          repository = "s3:s3.us-east-005.backblazeb2.com/thoth-restic";
          passwordSecret = "uriel-restic-password";
          envTemplate = "uriel-restic-b2-env";
          paths = [
            "/persistent/var/lib/hermes"
            "/persistent/home/john/.agentmemory"
          ];
          exclude = [ "*.tmp" ];
        };

        # Jehoel (replaces mab) — server + desktop
        jehoel = {
          name = "jehoel";
          repository = "s3:s3.us-east-005.backblazeb2.com/mab-restic";
          passwordSecret = "jehoel-restic-password";
          envTemplate = "jehoel-restic-b2-env";
          paths = [ ];
          exclude = [ "*.tmp" ];
        };

        # Raphael (was puck) — Framework 12 laptop
        raphael = {
          name = "raphael";
          repository = "s3:s3.us-east-005.backblazeb2.com/puck-restic";
          passwordSecret = "raphael-restic-password";
          envTemplate = "raphael-restic-b2-env";
          paths = [ ];
          exclude = [ "*.tmp" ];
        };
      };

      cfg = hostConfig.${hostName} or (throw "restic: no backup config for host '${hostName}'");

      isUriel = hostName == "uriel";
      isJehoel = hostName == "jehoel";
      isRaphael = hostName == "raphael";
    in
    {
      options.mortlake.restic = {
        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Extra paths to include in the host's restic backup.
            Intended for service modules to contribute their data directories.
          '';
        };
        exclude = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Extra exclude patterns for the host's restic backup.
            Intended for service modules to exclude large or regenerable data.
          '';
        };
      };

      config = {
        sops.secrets = lib.mkMerge [
          (lib.mkIf isJehoel {
            "jehoel-restic-password" = supersecrets;
            "jehoel-b2-access-key-id" = supersecrets;
            "jehoel-b2-secret-access-key" = supersecrets;
          })
          (lib.mkIf isRaphael {
            "raphael-restic-password" = supersecrets;
            "raphael-b2-access-key-id" = supersecrets;
            "raphael-b2-secret-access-key" = supersecrets;
          })
        ];

        sops.templates = lib.mkMerge [
          (lib.mkIf isUriel {
            "uriel-restic-b2-env" = {
              content = ''
                AWS_ACCESS_KEY_ID=${p.uriel-b2-access-key-id}
                AWS_SECRET_ACCESS_KEY=${p.uriel-b2-secret-access-key}
              '';
              owner = "john";
            };
          })
          (lib.mkIf isJehoel {
            "jehoel-restic-b2-env" = {
              content = ''
                AWS_ACCESS_KEY_ID=${p.jehoel-b2-access-key-id}
                AWS_SECRET_ACCESS_KEY=${p.jehoel-b2-secret-access-key}
              '';
              owner = "john";
            };
          })
          (lib.mkIf isRaphael {
            "raphael-restic-b2-env" = {
              content = ''
                AWS_ACCESS_KEY_ID=${p.raphael-b2-access-key-id}
                AWS_SECRET_ACCESS_KEY=${p.raphael-b2-secret-access-key}
              '';
              owner = "john";
            };
          })
        ];

        services.restic.backups.${cfg.name} = {
          inherit (cfg) repository;
          passwordFile = secrets."${cfg.passwordSecret}".path;
          environmentFile = templates."${cfg.envTemplate}".path;

          paths = cfg.paths ++ config.mortlake.restic.paths;
          exclude = cfg.exclude ++ config.mortlake.restic.exclude;

          initialize = true;
          inhibitsSleep = true;

          extraBackupArgs = [ "--verbose" ];

          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "30m";
          };

          createWrapper = true;
        };

        systemd.services."restic-backups-${cfg.name}" = {
          serviceConfig = {
            User = lib.mkForce "john";
            Group = lib.mkForce "users";
          };
        };

        environment.systemPackages = [ pkgs.restic ];
      };
    };
}
