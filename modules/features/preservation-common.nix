{ inputs, ... }:
{
  flake.nixosModules.preservation-common =
    { lib, ... }:
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
