# TODO (jehoel restic) — remaining manual steps:
#
# 1. B2 Application Key — create a key restricted to the jehoel-restic bucket
#    (S3 compatible). Need: keyID (005...) + applicationKey.
#
# 2. Restic repo password — generate or choose a strong passphrase:
#      openssl rand -base64 32
#    Store it somewhere safe; it goes into sops next.
#
# 3. Add secrets to supersecrets.yaml (on Jehoel or Raphael — has age key):
#      cd ~/src/mortlake
#      sops modules/features/supersecrets.yaml
#    Add three keys:
#      jehoel-restic-password: "<the passphrase from step 2>"
#      jehoel-b2-access-key-id: "<keyID from step 1>"
#      jehoel-b2-secret-access-key: "<applicationKey from step 1>"
#
# 4. Import this module in jehoel/configuration.nix (already present as
#    self.nixosModules.restic in the imports list — confirm it's there).
#
# 5. Rebuild:
#      sudo nixos-rebuild switch --flake .#jehoel
#    With initialize = false, the repo must already exist (restic 0.17.0+
#    treats re-init as fatal). Create it manually if needed:
#      source <(cat /run/secrets.d/jehoel-restic-b2-env)
#      restic -r s3:s3.us-east-005.backblazeb2.com/jehoel-restic init
#
# 6. Verify first backup:
#      systemctl status restic-backups-jehoel
#      sudo restic-jehoel snapshots
#    (wrapper sources the env file automatically)
#
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
            "/home/john/vault"
            "/home/john/src"
            "/home/john/reference-repos"
            "/home/john/.ssh"
          ];
          exclude = [ "*.tmp" ];
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
            "/home/john/reference-repos"
            "/home/john/.ssh"
            "/var/lib/jellyfin"
            "/var/lib/transmission"
            "/var/lib/mealie"
            "/var/lib/syncthing"
          ];
          exclude = [
            "*.tmp"
            "/var/lib/jellyfin/transcodes"
            "/var/lib/transmission/Downloads"
            "/var/lib/syncthing/st"
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

          paths = cfg.paths;
          exclude = cfg.exclude;

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
