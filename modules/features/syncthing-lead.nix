# Syncthing lead node (jehoel). Device IDs are public identifiers — not secrets.
# GUI password set via environment file from sops.
let
  baseDomain = "otwell.dev";
  syncthingPort = 8384;
in
_:
{
  flake.nixosModules.syncthing-lead =
    { config, lib, pkgs, ... }:
    {
      # GUI password — sops secret
      sops.secrets."syncthing-gui-password" = {
        owner = "john";
        sopsFile = ./supersecrets.yaml;
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
            # Device IDs are public keys — not secrets.
            # TODO: fill in real device IDs for raphael and raziel.
            # "raphael".id = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
            # "raziel".id = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
            "pixel8".id = "7YWROAI-Z66BW2L-UE2DPVL-WOEMEBH-FNRKHPQ-NVDXRHR-EQOXICC-CDRLLAF";
          };
          folders = {
            "st" = {
              path = "/var/lib/syncthing/st";
              devices = [ "pixel8" ];
            };
          };
          gui = {
            user = "john.otwell";
            insecureSkipHostcheck = true;
            # Password set at runtime via activation script below.
          };
        };
      };

      # Syncthing GUI password: read sops secret at runtime, write to
      # syncthing config via CLI. The secret doesn't exist at Nix eval time,
      # so we can't use builtins.readFile.
      # Uses a script wrapper that waits for syncthing to be ready before
      # setting the password.
      systemd.services.syncthing = {
        after = [ "sops-nix.service" ];
        serviceConfig = {
          ExecStartPost = lib.mkForce (
            "+${pkgs.writeShellScript "syncthing-set-gui-password" ''
              ${pkgs.coreutils}/bin/timeout 30 ${pkgs.bash}/bin/bash -c '
                while ! ${lib.getExe config.services.syncthing.package} cli show system >/dev/null 2>&1; do
                  sleep 1
                done
              '
              ${lib.getExe config.services.syncthing.package} cli config gui set password "$(cat ${config.sops.secrets."syncthing-gui-password".path})"
            ''}"
          );
        };
      };
    };
}
