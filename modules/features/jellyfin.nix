# Jellyfin media server. Public at https://jellyfin.otwell.dev via nginx +
# ACME; LAN direct access on :8096 also stays open.
let
  baseDomain = "otwell.dev";
  jellyfinPort = 8096;
in
_: {
  flake.nixosModules.jellyfin = _: {
    networking.firewall.allowedTCPPorts = [ jellyfinPort ]; # LAN direct

    services.jellyfin = {
      enable = true;
      user = "john";
      group = "users";
    };

    services.nginx.virtualHosts."jellyfin.${baseDomain}" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://localhost:${toString jellyfinPort}";
      locations."/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
    };

    preservation.preserveAt."/persistent".directories = [
      {
        directory = "/var/lib/jellyfin";
        user = "john";
        group = "users";
      }
    ];
  };
}
