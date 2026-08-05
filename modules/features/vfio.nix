# VFIO GPU passthrough — passes the 5700 XT eGPU (and optionally a USB
# controller) to a SteamOS KVM guest via VFIO. Solves the NixOS async
# reprojection / CAP_SYS_NICE blocker for SteamVR by running SteamOS in
# its own kernel, outside the bubblewrap sandbox.
#
# Intended for Jehoel (Minisforum UM780 XTX, AMD 7840HS + 5700 XT via OCuLink).
# The 780M iGPU stays on the host for desktop/Sunshine; the 5700 XT goes to
# the VM for SteamVR → Steam Frame wireless streaming.
#
# Enabled via a NixOS specialisation so the GPU is only reserved when needed:
# boot into the "VFIO" entry to use the VM, boot default for host-only use.
#
# See docs/vfio-steamos-plan.md for full architecture and setup steps.
{ lib, ... }:
let
  # TODO: VERIFY these against actual lspci -nn output on Jehoel.
  # 5700 XT (Navi 10) reference IDs:
  #   VGA:   1002:731f
  #   Audio: 1002:ab38
  #
  # USB controller IDs for the Steam Frame dongle port — pick from IOMMU
  # group listing after running the verification script in the plan doc.
  # UM780 XTX has multiple isolated USB controllers (groups 21-31).
  defaultGpuIds = [
    "1002:731f"  # 5700 XT VGA
    "1002:ab38"  # 5700 XT HDMI audio
  ];
in
{
  flake.nixosModules.vfio =
    { pkgs, config, ... }:
    {
      options.vfio = {
        enable = lib.mkEnableOption "VFIO GPU passthrough for SteamOS VM";

        gpuIds = lib.mkOption {
          type = with lib.types; listOf str;
          default = defaultGpuIds;
          description = ''
            PCI vendor:device IDs to claim for VFIO passthrough.
            Verify with: lspci -nn | grep -i radeon
            Must include both the VGA and HDMI audio function IDs.
          '';
          example = [ "1002:731f" "1002:ab38" ];
        };

        usbIds = lib.mkOption {
          type = with lib.types; listOf str;
          default = [ ];
          description = ''
            PCI vendor:device IDs of USB controllers to pass through to the VM.
            Leave empty if the Steam Frame dongle will be handled via
            individual USB device redirection instead of controller passthrough.
            Check IOMMU groups to ensure the controller is isolated.
          '';
          example = [ "1022:15c0" "1022:15c1" ];
        };
      };

      config = lib.mkIf config.vfio.enable {
        boot = {
          # vfio modules MUST load before amdgpu so vfio-pci can claim
          # the 5700 XT by its PCI IDs. The 780M iGPU (not in vfio-pci.ids)
          # will still bind to amdgpu normally.
          initrd.kernelModules = [
            "vfio_pci"
            "vfio"
            "vfio_iommu_type1"
            "kvm-amd"
            "amdgpu"
          ];

          kernelParams = [
            "amd_iommu=on"
            "iommu=pt"
            "vfio-pci.ids=${lib.concatStringsSep "," (config.vfio.gpuIds ++ config.vfio.usbIds)}"
          ];

          # vendor-reset helps the 5700 XT (Navi 10) recover cleanly
          # when the VM shuts down, avoiding the AMD GPU reset bug that
          # would otherwise require a host reboot between VM sessions.
          extraModulePackages = [
            config.boot.kernelPackages.vendor-reset
          ];
        };

        virtualisation.libvirtd = {
          enable = true;
          qemu = {
            package = pkgs.qemu_kvm;
            runAsRoot = true;
            swtpm.enable = true;
            ovmf = {
              enable = true;
              packages = [
                (pkgs.OVMF.override {
                  secureBoot = true;
                  tpmSupport = true;
                }).fd
              ];
            };
          };
        };

        programs.virt-manager.enable = true;
        virtualisation.spiceUSBRedirection.enable = true;

        # Looking Glass: shared memory for low-latency host-side preview
        # of the VM's framebuffer. The matching ivshmem device goes in
        # the VM's libvirt XML (see docs/vfio-steamos-plan.md Phase 4).
        systemd.tmpfiles.rules = [
          "f /dev/shm/looking-glass 0660 john qemu-libvirtd -"
        ];

        environment.systemPackages = with pkgs; [
          virt-manager
          looking-glass-client
          pciutils
          OVMF
        ];

        users.users.john.extraGroups = [
          "libvirtd"
          "qemu-libvirtd"
          "disk"
        ];
      };
    };
}
