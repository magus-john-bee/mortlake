{ inputs, ... }:
{
  flake.nixosModules.urielDisko =
    { lib, ... }:
    let
      primaryDisk = lib.mkDefault "/dev/sda";
    in
    {
      imports = [ inputs.disko.nixosModules.disko ];

      fileSystems."/nix".neededForBoot = true;
      fileSystems."/persistent".neededForBoot = true;

      disko.devices.nodev = {
        "/" = {
          fsType = "tmpfs";
          mountOptions = [
            "size=50%"
            "mode=755"
          ];
        };
      };

      disko.devices.disk.main = {
        device = primaryDisk;
        type = "disk";

        content = {
          type = "gpt";

          partitions = {
            bios-boot = {
              size = "1M";
              type = "EF02";
              priority = 0;
            };

            esp = {
              name = "ESP";
              size = "512M";
              type = "EF00";
              priority = 1;

              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            swap = {
              size = "2G";

              content = {
                type = "swap";
                discardPolicy = "both";
              };
            };

            root = {
              name = "root";
              size = "100%";

              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                ];

                subvolumes = {
                  "/persistent" = {
                    mountOptions = [
                      "subvol=persistent"
                      "compress=zstd"
                      "noatime"
                    ];
                    mountpoint = "/persistent";
                  };

                  "/nix" = {
                    mountOptions = [
                      "subvol=nix"
                      "compress=zstd"
                      "noatime"
                    ];
                    mountpoint = "/nix";
                  };
                };
              };
            };
          };
        };
      };
    };
}
