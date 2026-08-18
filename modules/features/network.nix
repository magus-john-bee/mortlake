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

      # Pinned host keys — ssh uriel / ssh jehoel is not TOFU. Provenance:
      # - uriel: on-disk key read on the host itself == keyscan-presented
      # - jehoel: keyscan-presented == john@uriel known_hosts entry, and
      #   derives to the &jehoel age anchor in .sops.yaml (only the key
      #   jehoel sops-decrypts with could produce that)
      programs.ssh.knownHosts = {
        uriel = {
          hostNames = [ "87.99.146.205" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA8+i8bREEEwTtYIGoldz0OQaB4YFKt+wG+MHf1caq5X";
        };
        jehoel = {
          hostNames = [ "ssh.otwell.dev" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDPeQiYDQJGWpEnXZSwVIFm8CJ+95iOwhl06SfGnap0z";
        };
      };
    };
}
