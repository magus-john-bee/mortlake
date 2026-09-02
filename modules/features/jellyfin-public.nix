# Jellyfin public — opt-in nginx reverse proxy + TLS for remote access.
# Not imported by default. Import alongside jellyfin.nix if remote access is needed.
let
  baseDomain = "otwell.dev";
  jellyfinPort = 8096;
in
_: {
  flake.nixosModules.jellyfin-public = _: {
    services.nginx.virtualHosts."jellyfin.${baseDomain}" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://localhost:${toString jellyfinPort}";
      locations."/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
    };
  };
}
