# Syncthing lead node (jehoel). Device IDs are public identifiers — not secrets.
# GUI password set via environment file from sops.
let
  baseDomain = "otwell.dev";
  syncthingPort = 8384;
in
_: {
  flake.nixosModules.syncthing-lead =
    { config, ... }:
    {
      # GUI password — sops secret
      sops.secrets."syncthing-gui-password" = {
        owner = "john";
        sopsFile = ./supersecrets.yaml;
      };

      services = {
        nginx.virtualHosts."syncthing.${baseDomain}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://localhost:${toString syncthingPort}";
          locations."/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
        };

        syncthing = {
          enable = true;
          user = "john";
          overrideDevices = true;
          overrideFolders = true;
          openDefaultPorts = true;
          # Plaintext GUI password from sops; syncthing-init (the module's
          # config merger) bcrypt-hashes it and PATCHes /rest/config/gui.
          guiPasswordFile = config.sops.secrets."syncthing-gui-password".path;
          settings = {
            devices = {
              # Device IDs are public keys — not secrets.
              # Hub-and-spoke: spokes (pixel8, …) only know jehoel; the st
              # folder is shared with all registered peers below, and peers
              # are not introducers, so they never sync with each other.
              # TODO: fill in real device IDs for raphael and raziel.
              # "raphael".id = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
              # "raziel".id = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
              "pixel8".id = "7YWROAI-Z66BW2L-UE2DPVL-WOEMEBH-FNRKHPQ-NVDXRHR-EQOXICC-CDRLLAF";
              "pixel9".id = "XIDYDPP-XN7F4A4-WFWS7CU-HU3SUDX-VWHAKUN-XQ2VSYR-TM3OOPH-UFHJXQH";
            };
            folders = {
              "st" = {
                path = "/var/lib/syncthing/st";
                devices = [
                  "pixel8"
                  "pixel9"
                ];
              };

              # Keepass vault — dedicated folder, NOT inside st: small sync
              # surface, and the phone can subscribe to ONLY the vault.
              # KeePassXC (desktops) + Keepass2Android (phone) treat the
              # .kdbx as a plain file; sync conflicts resolve via
              # Database > Merge from Database (UUID merge) on the
              # .sync-conflict-* copies Syncthing leaves. Discipline that
              # matters: don't keep entries open in edit mode on two
              # devices at once (keepassxc#10225 — silent clobber, no
              # conflict file is produced in that case).
              # Backups: /var/lib/syncthing is in jehoel's restic paths —
              # covers the vault AND its version history; the desktop
              # KeePassXC also keeps entry-level history inside the kdbx.
              "vault" = {
                path = "/var/lib/syncthing/vault";
                devices = [ "pixel9" ];
                # Staggered versioning = the KeePassXC-recommended sync
                # safety net (old versions kept on a decaying schedule:
                # ~per-minute recent, thinning to per-week old; default
                # maxAge 365d). Recovers from bad overwrites/deletions
                # that sync would otherwise propagate everywhere.
                versioning = {
                  type = "staggered";
                  params.maxAge = "31536000";
                };
              };
            };
            gui = {
              user = "john.otwell";
              insecureSkipHostcheck = true;
            };
          };
        };
      };

      systemd = {
        tmpfiles.rules = [
          "d /var/lib/syncthing 0755 john users"
          "d /var/lib/syncthing/st 0755 john users"
          # 0700: password vault — only john (syncthing + KeePassXC run as
          # john) needs access.
          "d /var/lib/syncthing/vault 0700 john users"
        ];

        # syncthing-init (the module's config merger) needs the sops-rendered
        # GUI password file to exist before it runs; order both syncthing
        # units after sops-nix (the module itself only orders after
        # network.target).
        services = {
          syncthing.after = [ "sops-nix.service" ];
          syncthing-init.after = [ "sops-nix.service" ];
        };
      };
    };
}
