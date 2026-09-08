# SilverBullet — self-hosted PKM web app (https://silverbullet.md).
#
# Topology: uriel-only service bound to 127.0.0.1:3000, fronted by
# nginx + ACME at sb.otwell.dev (same vhost pattern as taskdog/mealie).
# Auth: SB_USER basic auth, rendered by sops from silverbullet-password
# in secrets.yaml. Space is plain markdown at /var/lib/silverbullet,
# persisted across rebuilds; content seeding happens post-deploy
# (logbook copy + archive triage) — not part of this module.
let
  domain = "sb.otwell.dev";
  port = 3000;
in
_: {
  flake.nixosModules.silverbullet =
    {
      config,
      lib,
      ...
    }:
    let
      p = config.sops.placeholder;
    in
    {
      services.silverbullet = {
        enable = true;
        listenAddress = "127.0.0.1";
        listenPort = port;
        envFile = config.sops.templates."silverbullet-env".path;
      };

      sops.secrets."silverbullet-password" = {
        owner = "silverbullet";
        sopsFile = ./secrets.yaml;
        restartUnits = [ "silverbullet.service" ];
      };

      # Rendered env file consumed via the module's envFile option.
      sops.templates."silverbullet-env" = {
        content = ''
          SB_USER=john:${p.silverbullet-password}
        '';
        owner = "silverbullet";
      };

      # Secrets must exist before the service starts (house pattern:
      # syncthing-lead/atuin order against sops-nix).
      systemd.services.silverbullet.after = [ "sops-nix.service" ];

      # Public HTTPS entry — WebSocket (/.command, live sync) rides the
      # same location.
      services.nginx.virtualHosts."${domain}" = lib.mkIf config.services.nginx.enable {
        forceSSL = true;
        enableACME = true;
        locations."/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = true;
        };
      };

      # Space persistence — plain markdown, survives rebuilds.
      preservation.preserveAt."/persistent".directories = [
        {
          directory = "/var/lib/silverbullet";
          user = "silverbullet";
          group = "silverbullet";
        }
      ];
    };
}
