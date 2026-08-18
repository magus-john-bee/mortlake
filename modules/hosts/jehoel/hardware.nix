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
        # Intel AX211 BT (8087:0032) — BT half of the M.2 card, USB-attached
        # internally (btusb). WiFi half is PCIe (8086:2725). Firmware via
        # enableRedistributableFirmware. Pairings persist via /var/lib/bluetooth.
        bluetooth.enable = true;
        enableRedistributableFirmware = lib.mkDefault true;
        cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

        # AMD GPU — RDNA1 (5700 XT) has limited ROCm, so opencl stays off.
        # For 7900 XTX (RDNA3): set amdgpu.opencl.enable = true for ROCm.
        amdgpu.opencl.enable = false;
        graphics.enable = true;
      };
    };
}
