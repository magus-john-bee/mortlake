_: {
  flake.nixosModules.the-aether =
    { config, ... }:
    let
      supersecrets = {
        sopsFile = ./supersecrets.yaml;
      };
    in
    {
      sops.secrets."the-aether-pw" = supersecrets;

      networking.networkmanager = {
        ensureProfiles = {
          profiles."the-aether" = {
            connection = {
              id = "TheAether";
              type = "wifi";
            };
            wifi = {
              ssid = "TheAether";
              mode = "infrastructure";
            };
            wifi-security = {
              key-mgmt = "wpa-psk";
              auth-alg = "open";
              psk-flags = "1";
            };
            ipv4.method = "auto";
            ipv6.method = "auto";
            ipv6.addr-gen-mode = "stable-privacy";
          };

          secrets.entries = [
            {
              matchId = "the-aether";
              matchType = "wifi";
              matchSetting = "wifi-security";
              key = "psk";
              file = config.sops.secrets."the-aether-pw".path;
              trim = true;
            }
          ];
        };
      };
    };
}
