_: {
  flake.nixosModules.urielHardware =
    { lib, modulesPath, ... }:
    {
      imports = [
        (modulesPath + "/profiles/qemu-guest.nix")
      ];

      boot = {
        initrd = {
          systemd.enable = true;
          availableKernelModules = [
            "ahci"
            "xhci_pci"
            "virtio_pci"
            "virtio_scsi"
            "sd_mod"
            "sr_mod"
          ];
          kernelModules = [ ];
        };
        kernelModules = [ ];
        extraModulePackages = [ ];
      };

      networking.useDHCP = lib.mkDefault true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
