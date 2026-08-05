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
        self.nixosModules.restic
        self.nixosModules.intellishell
        # AI tooling
        self.nixosModules.pi
        self.nixosModules.herdr
        self.nixosModules.gbrain
        self.nixosModules.nginx
      ];

      boot = {
        loader.grub = {
          enable = true;
          efiSupport = true;
          efiInstallAsRemovable = true;
          device = "nodev";
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
