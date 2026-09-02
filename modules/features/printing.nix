_: {
  flake.nixosModules.printing =
    { pkgs, ... }:
    {
      services = {
        printing = {
          enable = true;
          drivers = [ pkgs.brlaser ];
        };
        avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
        };
      };
    };
}
