{ self, ... }:
{
  flake.nixosModules.urielConfiguration =
    { lib, ... }:
    {
      imports = [
        self.nixosModules.urielHardware
        self.nixosModules.urielDisko
        self.nixosModules.preservation-common
        self.nixosModules.clock
        self.nixosModules.network
        self.nixosModules.packages
        self.nixosModules.john
        self.nixosModules.nix-qol
        self.nixosModules.sops
        self.nixosModules.hermes
        self.nixosModules.podman
        self.nixosModules.git
        self.nixosModules.gh
        self.nixosModules.zsh
        self.nixosModules.safe-atuin
        self.nixosModules.helix
        self.nixosModules.zellij
        self.nixosModules.dev-dirs
        # TODO(restic): re-enable once the Backblaze side is provisioned —
        # new bucket for uriel (old thoth-restic objects are being deleted;
        # nothing references that bucket anymore), `restic-<host> init`,
        # and B2 keys in supersecrets if they change.
        # self.nixosModules.restic
        self.nixosModules.intellishell
        # AI tooling
        self.nixosModules.pi
        self.nixosModules.herdr
        self.nixosModules.taskdog
        self.nixosModules.nginx
      ];

      boot = {
        loader.grub = {
          enable = true;
          # This Hetzner box boots BIOS-legacy (bootctl: "Not booted with
          # EFI"; sda1 is an EF02 bios-boot partition). device=/dev/sda
          # installs BIOS GRUB into sda1; keeping efiSupport also writes
          # EFI files to the ESP — boots under either firmware mode.
          device = "/dev/sda";
          efiSupport = true;
          efiInstallAsRemovable = true;
        };
        kernelParams = [ "console=ttyS0" ];
      };

      networking = {
        hostName = "uriel";
        useDHCP = lib.mkDefault true;
      };

      networking.firewall.allowedTCPPorts = [
        22
        80
        443
      ];

      preservation.preserveAt."/persistent" = {
        directories = [
          "/var/lib/hermes"
          "/var/lib/containers"
          "/var/lib/acme"
          "/var/lib/nginx"
        ];
      };

      # VPS resource constraints
      nix.settings = {
        max-jobs = 1;
        cores = 1;
        max-substitution-jobs = lib.mkOverride 90 3;
      };

      system.stateVersion = "25.05";
    };
}
