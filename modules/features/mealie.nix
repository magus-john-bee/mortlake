let
  baseDomain = "otwell.dev";
  mealiePort = 9000;
in
_: {
  flake.nixosModules.mealie = { lib, ... }: {
    services.mealie = {
      enable = true;
      port = mealiePort;
      settings = {
        BASE_URL = "mealie.${baseDomain}";
      };
    };

    # Override DynamicUser to run as john:users for /run/secrets access
    # and compatibility with preservation bind-mounts
    systemd.services.mealie.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "john";
      Group = lib.mkForce "users";
    };

    services.nginx.virtualHosts."mealie.${baseDomain}" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://localhost:${toString mealiePort}";
      locations."/.well-known/acme-challenge".root = "/var/lib/acme/acme-challenge";
    };
  };
}
