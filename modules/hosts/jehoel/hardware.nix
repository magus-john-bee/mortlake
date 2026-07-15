# Jehoel hardware — based on mab's Intel NUC pattern + AMD GPU via OCuLink.
# OCuLink is just physical PCIe-over-cable. The GPU appears as a normal PCIe
# device — no special drivers needed beyond standard AMD graphics setup.
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
    # When upgrading to 7900 XTX (RDNA3), no driver change needed —
    # just flip amdgpu.opencl to true for ROCm compute support.
    kernelModules = [
      "kvm-intel"
      "amdgpu"
    ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  hardware = {
    enableRedistributableFirmware = lib.mkDefault true;
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # AMD GPU
    amdgpu = {
      loadBalancing = true;
      opencl = false; # RDNA1 (5700 XT) has limited ROCm. Flip to true for 7900 XTX.
    };
    graphics.enable = true;
  };
}
