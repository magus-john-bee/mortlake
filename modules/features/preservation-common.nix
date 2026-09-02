{ inputs, ... }:
{
  flake.nixosModules.preservation-common =
    { ... }:
    {
      imports = [ inputs.preservation.nixosModules.preservation ];

      # With tmpfs root + preservation bind-mount, /etc/machine-id already
      # resolves to /persistent/etc/machine-id (on btrfs, not tmpfs).
      # The commit service expects a tmpfs-backed transient ID and fails
      # with "not on a temporary file system". Mask it — preservation
      # already handles persistence.
      systemd.services.systemd-machine-id-commit.enable = false;

      preservation = {
        enable = true;

        preserveAt."/persistent" = {
          directories = [
            # intermediate files can eat RAM
            {
              directory = "/tmp";
              user = "john";
              group = "users";
              mode = "1777";
            }
            {
              directory = "/var/lib/nixos";
              inInitrd = true;
            }
            "/var/log"
            {
              directory = "/var/lib/syncthing";
              user = "john";
              group = "users";
            }
          ];

          files = [
            {
              file = "/etc/machine-id";
              inInitrd = true;
            }
            {
              file = "/etc/ssh/ssh_host_ed25519_key";
              mode = "0600";
              # sops runs in initrd on systemd-initrd hosts (uriel), where it
              # derives the age key from this file. Without inInitrd the mount
              # lands in stage 2, after activation, so decryption gets an empty
              # key file ("0 successful groups required, got 0").
              inInitrd = true;
            }
            "/etc/ssh/ssh_host_ed25519_key.pub"
            {
              file = "/etc/ssh/ssh_host_rsa_key";
              mode = "0600";
            }
            "/etc/ssh/ssh_host_rsa_key.pub"
          ];

          users.john = {
            directories = [
              ".ssh"
              ".cache"
              ".npm"
            ];
          };
        };
      };
    };
}
