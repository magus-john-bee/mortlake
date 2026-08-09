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
          };
          folders = {
            "st" = {
              path = "/var/lib/syncthing/st";
              # devices = [ "raphael" "raziel" ];
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
      # Uses a script wrapper because systemd doesn't do shell expansion in
      # ExecStartPost — $(...) needs explicit bash invocation.
      systemd.services.syncthing = {
        after = [ "sops-nix.service" ];
        serviceConfig = {
          ExecStartPost = lib.mkForce (
            "+${pkgs.writeShellScript "syncthing-set-gui-password" ''
              ${lib.getExe config.services.syncthing.package} cli config gui set password "$(cat ${config.sops.secrets."syncthing-gui-password".path})"
            ''}"
          );
        };
      };
    };
}
