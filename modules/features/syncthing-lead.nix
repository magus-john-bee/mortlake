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
              # Hub-and-spoke: spokes (pixel8, pixel9, raphael) only know
              # jehoel; folders are shared with registered peers, and peers
              # are not introducers, so they never sync with each other.
              # TODO(raphael): get raphael's syncthing device ID
              # (`syncthing --device-id` or GUI: Actions > Show ID), then
              # uncomment + add "raphael" to the st devices and the vault
              # peers list in keepass.nix:
              # "raphael".id = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
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

              # Keepass vault — dedicated folder, NOT inside st: small
              # sync surface, and the phone subscribes to ONLY the vault.
              # Usage discipline (merge-on-conflict, single-writer,
              # key-file-out-of-band) documented in keepass.nix.
              # TODO(raphael): add "raphael" to devices once its ID lands
              # (see devices TODO above) — and it arrives automatically on
              # raphael via syncthing-follow.
              "vault" = {
                path = "/var/lib/syncthing/vault";
                devices = [ "pixel9" ];
                # Staggered versioning = the KeePassXC-recommended sync
                # safety net (old versions on a decaying schedule:
                # ~per-minute recent, thinning to per-week old; maxAge
                # 365d). Recovers from bad overwrites/deletions that sync
                # would otherwise propagate everywhere.
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
          # 0700: keepass vault — only john (syncthing + KeePassXC run as
          # john) needs access. Usage side: keepass.nix.
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
