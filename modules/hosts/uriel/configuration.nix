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
        # Syncthing spoke: st folder peers with jehoel (the hub) only —
        # syncthing-follow.nix. Device identity persists via
        # preservation-common (/var/lib/syncthing).
        self.nixosModules.syncthing-follow
        # Uriel restic → B2 bucket uriel-restic (s3 API). Repo init is
        # manual: `sudo restic-uriel init` after deploy (restic 0.17+
        # treats re-init as fatal, hence initialize = false).
        self.nixosModules.restic
        self.nixosModules.intellishell
        # AI tooling
        self.nixosModules.pi
        self.nixosModules.herdr
        self.nixosModules.taskdog
        self.nixosModules.silverbullet
        self.nixosModules.nginx
        # eBay Sell API prerequisite: account-deletion endpoint gates the
        # production keyset (see personal-resale skill / selling-ops).
        self.nixosModules.ebayDeletion
      ];

      services.intellishell.enable = true;

      # Taskdog: uriel is THE server; local CLI also talks to it via
      # https (through nginx) so the local client exercises the same
      # path as remote hosts.
      services.taskdog = {
        server.enable = true;
        client.enable = true;
      };

      # deletion.otwell.dev — eBay challenge/deletion endpoint behind
      # nginx + ACME (DNS record must exist at the registrar first).
      services.ebayDeletion.enable = true;

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

      # Uriel builds other hosts' closures (cross-host test builds) and
      # had accumulated 20.8 GiB of unreachable store paths by 2026-09.
      # Collect unrooted garbage weekly so it can't fill the 36G disk.
      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 14d";
        persistent = true;
      };

      system.stateVersion = "25.05";
    };
}
