# DDNS client — Porkbun. Only active subdomains.
let
  baseDomain = "otwell.dev";
  supersecrets = {
    owner = "john";
    sopsFile = ./supersecrets.yaml;
  };
in
{
  flake.nixosModules.dd-client =
    { config, ... }:
    let
      p = config.sops.placeholder;
    in
    {
      sops.secrets = {
        "porkbun-api-key" = supersecrets;
        "porkbun-secret-api-key" = supersecrets;
      };

      sops.templates."porkbun-ddclient.conf" = {
        content = ''
          login=${p.porkbun-api-key}
          password=${p.porkbun-secret-api-key}
        '';
        mode = "0400";
        owner = "john";
      };

      services.ddclient = {
        enable = true;
        protocol = "porkbun";
        domains = [
          "ssh.${baseDomain}"
          "cache.${baseDomain}"
          "mealie.${baseDomain}"
          "jehoel.${baseDomain}"
          "syncthing.${baseDomain}"
        ];
        secretsFile = config.sops.templates."porkbun-ddclient.conf".path;
      };
    };
}
