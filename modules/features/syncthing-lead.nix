# Syncthing lead node (jehoel). Device IDs from sops — not hardcoded.
let
  baseDomain = "otwell.dev";
  syncthingPort = 8384;
in
_:
{
  flake.nixosModules.syncthing-lead =
    { config, ... }:
    let
      p = config.sops.placeholder;
    in
    {
      # Device IDs — encrypted, not in plaintext
      sops.secrets = {
        "syncthing-raphael-id" = {
          owner = "john";
          sopsFile = ./supersecrets.yaml;
        };
        "syncthing-raziel-id" = {
          owner = "john";
          sopsFile = ./supersecrets.yaml;
        };
        "syncthing-gui-password" = {
          owner = "john";
          sopsFile = ./supersecrets.yaml;
        };
      };

      mortlake.restic = {
        paths = [ "/var/lib/syncthing" ];
        exclude = [ "/var/lib/syncthing/st" ];
      };

      systemd.tmpfiles.rules = [
        "d /var/lib/syncthing 0755 john users"
        "d /var/lib/syncthing/st 0755 john users"
      ];

      services.nginx.virtualHosts."syncthing.${baseDomain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://localhost:${toString syncthingPort}";
        locations."/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
      };

      services.syncthing = {
        enable = true;
        user = "john";
        overrideDevices = true;
        overrideFolders = true;
        openDefaultPorts = true;
        settings = {
          devices = {
            # Device IDs read from sops files at runtime
            "raphael".id = builtins.readFile config.sops.secrets."syncthing-raphael-id".path;
            "raziel".id = builtins.readFile config.sops.secrets."syncthing-raziel-id".path;
          };
          folders = {
            "st" = {
              path = "/var/lib/syncthing/st";
              devices = [
                "raphael"
                "raziel"
              ];
            };
          };
          gui = {
            user = "john.otwell";
            password = builtins.readFile config.sops.secrets."syncthing-gui-password".path;
            insecureSkipHostcheck = true;
          };
        };
      };
    };
}
