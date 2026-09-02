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
