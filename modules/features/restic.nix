# Repo initialization is manual (initialize = false; restic 0.17+ treats
# re-init as fatal). For a new host's bucket:
#   sudo restic-<host> init
# The wrapper sources the sops env template automatically.
_: {
  flake.nixosModules.restic =
    {
      config,
      lib,
      pkgs,
      ...
    }:
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
            "/home/john/vault"
            "/home/john/src"
            "/home/john/reference-repos"
            "/home/john/.ssh"
            # taskdog SQLite DB + notes (hourly snapshots under backups/
            # are excluded — redundant with the DB itself at daily cadence)
            "/home/john/.local/share/taskdog"
          ];
          exclude = [
            "*.tmp"
            "/home/john/.local/share/taskdog/backups"
          ];
        };

        # Jehoel — server + desktop.
        # Paths previously self-registered by service modules via
        # mortlake.restic.paths; now listed here directly.
        jehoel = {
          name = "jehoel";
          repository = "s3:s3.us-east-005.backblazeb2.com/jehoel-restic";
          passwordSecret = "jehoel-restic-password";
          envTemplate = "jehoel-restic-b2-env";
          paths = [
            "/home/john/data"
            "/home/john/vault"
            "/home/john/src"
            "/home/john/.ssh"
            "/var/lib/jellyfin"
            "/var/lib/transmission"
            "/var/lib/mealie"
            "/var/lib/syncthing"
          ];
          # Media and downloaded data are replaceable; configs, metadata,
          # torrent files (.config/transmission-daemon/torrents) and
          # fast-resume state are small and included.
          exclude = [
            "*.tmp"
            "/var/lib/jellyfin/library"
            "/var/lib/jellyfin/transcodes"
            "/var/lib/transmission/Downloads"
            "/var/lib/transmission/.incomplete"
          ];
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
      config = {
        sops.secrets = lib.mkMerge [
          (lib.mkIf isUriel {
            "uriel-restic-password" = {
              owner = "john";
              sopsFile = ./secrets.yaml;
            };
            "uriel-b2-access-key-id" = {
              owner = "john";
              sopsFile = ./secrets.yaml;
            };
            "uriel-b2-secret-access-key" = {
              owner = "john";
              sopsFile = ./secrets.yaml;
            };
          })
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

          inherit (cfg) paths;
          inherit (cfg) exclude;

          initialize = false;

          extraBackupArgs = [ "--verbose" ];

          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "30m";
          };

          createWrapper = true;
        };

        # Run as root (the NixOS default). Root reads all backup paths,
        # all sops secrets (bypasses file perms), and the cache directory
        # without permission issues. The `restic-<host>` wrapper still works
        # for manual use: `sudo restic-jehoel snapshots`.
        # Previous User=john override caused: polkit access denied on
        # systemd-inhibit, cache permission denied panics, and would fail
        # on any root-owned backup path.

        environment.systemPackages = [ pkgs.restic ];
      };
    };
}
