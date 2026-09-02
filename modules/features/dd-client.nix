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

      # ddclient's porkbun protocol authenticates with apikey/secretapikey.
      # login/password are placeholder vars there ('unused' in 3.x, rejected
      # outright in 4.x) — they were never sent to the API.
      sops.templates."porkbun-ddclient.conf" = {
        content = ''
          apikey=${p.porkbun-api-key}
          secretapikey=${p.porkbun-secret-api-key}
        '';
        mode = "0400";
        owner = "john";
      };

      services.ddclient = {
        enable = true;
        protocol = "porkbun";
        interval = "5min";
        # We are IPv4-only: nixpkgs' module defaults render usev6=webv6,
        # webv6=ipify-ipv6, giving every domain a doomed AAAA pass each run
        # ("no applicable existing records" noise that buries real failures).
        # 'disabled' is the canonical ddclient 4.x spelling ('no' is a
        # deprecated alias). usev4 keeps its webv4/ipify default.
        usev6 = "disabled";
        # After a failed update attempt, ddclient skips retries until
        # min-error-interval (default 5m) expires. With a 5m timer that gate
        # races every run, so a failing update pattern wedges itself: retry
        # failures quickly instead.
        extraConfig = "min-error-interval=30s";
        domains = [
          "ssh.${baseDomain}"
          "cache.${baseDomain}"
          "mealie.${baseDomain}"
          "jehoel.${baseDomain}"
          "syncthing.${baseDomain}"
          "jellyfin.${baseDomain}"
        ];
        secretsFile = config.sops.templates."porkbun-ddclient.conf".path;
      };
    };
}
