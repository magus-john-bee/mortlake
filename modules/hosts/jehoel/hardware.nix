# Jehoel hardware — based on mab's Intel NUC pattern + AMD GPU via OCuLink.
# OCuLink is just physical PCIe-over-cable. The GPU appears as a normal PCIe
# device — no special drivers needed beyond standard AMD graphics setup.
{ self, ... }:
{
  flake.nixosModules.jehoelHardware =
    {
      config,
      lib,
      modulesPath,
      ...
    }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      nixpkgs.hostPlatform = "x86_64-linux";

      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "ahci"
          "nvme"
          "usb_storage"
          "usbhid"
          "sd_mod"
          "sdhci_pci"
        ];
        # amdgpu for the 5700 XT (RDNA1). Same driver for all AMD cards.
        # When upgrading to 7900 XTX (RDNA3), enable opencl.enable for ROCm.
        #
        # kvm-amd for the 7840HS (was kvm-intel — leftover from mab's Intel NUC config).
        # When VFIO is enabled (via specialisation), vfio.nix prepends the vfio
        # modules to initrd.kernelModules so they load before amdgpu.
        kernelModules = [
          "kvm-amd"
          "amdgpu"
        ];
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
      };

      hardware = {
        enableRedistributableFirmware = lib.mkDefault true;
        cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

        # AMD GPU — RDNA1 (5700 XT) has limited ROCm, so opencl stays off.
        # For 7900 XTX (RDNA3): set amdgpu.opencl.enable = true for ROCm.
        amdgpu.opencl.enable = false;
        graphics.enable = true;
      };
    };
}
