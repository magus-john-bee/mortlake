_:
{
  flake.nixosModules.network =
    { lib, ... }:
    {
      networking.firewall.enable = true;

      systemd.tmpfiles.rules = [
        "d /persistent/etc/ssh 0755 root root -"
        "z /persistent/etc/ssh/ssh_host_ed25519_key 0600 root root -"
        "z /persistent/etc/ssh/ssh_host_ed25519_key.pub 0644 root root -"
        "z /persistent/etc/ssh/ssh_host_rsa_key 0600 root root -"
        "z /persistent/etc/ssh/ssh_host_rsa_key.pub 0644 root root -"
      ];

      services.openssh = {
        enable = true;
        hostKeys = [
          {
            path = "/persistent/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
          {
            path = "/persistent/etc/ssh/ssh_host_rsa_key";
            type = "rsa";
            bits = 4096;
          }
        ];
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      # Under tmpfs root + preservation, sshd races tmpfiles at boot.
      # If the key directory doesn't exist yet or private keys have
      # permissions looser than 0600, sshd fails to start and stays
      # down — locking out remote access. Two fixes:
      #
      # 1. Order sshd after tmpfiles so the directory exists before
      #    the openssh module's own preStart tries to generate keys.
      # 2. A preStart guard that enforces correct directory + key
      #    permissions every time, regardless of whether tmpfiles
      #    won the race.
      systemd.services.sshd = {
        after = [
          "systemd-tmpfiles-setup.service"
          "nscd.service"
        ];
        wants = [ "systemd-tmpfiles-setup.service" ];
        preStart = lib.mkBefore ''
          mkdir -p /persistent/etc/ssh
          chmod 0755 /persistent/etc/ssh
          for key in /persistent/etc/ssh/ssh_host_ed25519_key /persistent/etc/ssh/ssh_host_rsa_key; do
            [ -f "$key" ] && chmod 0600 "$key"
          done
          for pub in /persistent/etc/ssh/ssh_host_ed25519_key.pub /persistent/etc/ssh/ssh_host_rsa_key.pub; do
            [ -f "$pub" ] && chmod 0644 "$pub"
          done
        '';
      };
    };
}
