_:
{
  flake.nixosModules.network =
    { lib, ... }:
    {
      networking.firewall.enable = true;

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };
    };
}
