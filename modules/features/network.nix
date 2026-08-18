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

      # Shared SSH client config for the NixOS hosts (jehoel, raphael,
      # uriel). The nix-on-droid hosts keep their per-host
      # environment.etc."ssh/ssh_config" stanzas — different module API,
      # and their aarch64 eval isn't covered by flake check on x86.
      #
      # Host * first: ssh applies the first matching value per option,
      # and the specific blocks below only set HostName/User, so there
      # are no conflicts.
      programs.ssh.extraConfig = ''
        Host *
          ServerAliveInterval 60
          ServerAliveCountMax 3

        Host uriel
          HostName 87.99.146.205
          User john

        Host jehoel
          HostName ssh.otwell.dev
          User john
      '';
    };
}
