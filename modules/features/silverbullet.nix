# SilverBullet — self-hosted PKM web app (https://silverbullet.md).
#
# Topology: uriel-only service bound to 127.0.0.1:3000, fronted by
# nginx + ACME at sb.otwell.dev (same vhost pattern as taskdog/mealie).
# Auth: SB_USER basic auth (silverbullet-password) plus SB_AUTH_TOKEN
# for HTTP API / programmatic access (silverbullet-auth-token), both
# sops-rendered from secrets.yaml.
#
# Space: plain markdown at /home/john/vault/sb — inside the vault bind
# mount, which is already tmpfs-persisted and restic-backed. vault/sb
# is a standalone git repo (hand-pushed fallback mirror at the magus
# account; no automation). The service runs as john so it can read and
# write the home-dir space natively.
let
  domain = "sb.otwell.dev";
  port = 3000;
  spaceDir = "/home/john/vault/sb";
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
        inherit spaceDir;
        user = "john";
        group = "users";
        envFile = config.sops.templates."silverbullet-env".path;
      };

      sops = {
        secrets = {
          "silverbullet-password" = {
            owner = "john";
            sopsFile = ./secrets.yaml;
            restartUnits = [ "silverbullet.service" ];
          };
          "silverbullet-auth-token" = {
            owner = "john";
            sopsFile = ./secrets.yaml;
            restartUnits = [ "silverbullet.service" ];
          };
        };

        # Rendered env file consumed via the module's envFile option.
        templates."silverbullet-env" = {
          content = ''
            SB_USER=john:${p.silverbullet-password}
            SB_AUTH_TOKEN=${p.silverbullet-auth-token}
          '';
          owner = "john";
        };
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

      # No preservation entry needed: the space lives at /home/john/vault/sb,
      # already covered by the vault bind mount (see john.nix / dev-dirs.nix).
    };
}
