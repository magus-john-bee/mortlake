# VFIO SteamOS VM Plan — Jehoel

## Goal

Run SteamOS as a KVM/QEMU VM on Jehoel (Minisforum UM780 XTX) with the AMD 5700 XT
eGPU passed through via VFIO. This gives SteamVR its native environment (CAP_SYS_NICE,
DRM leasing, async reprojection) without the NixOS bubblewrap sandbox problems — no
reboot required, host stays on NixOS.

Primary use case: Steam Frame VR headset streaming from the VM's SteamVR to the headset
via the included Wi-Fi 6E USB adapter.

## Architecture decision: Sunshine vs VFIO

Two distinct modes, selected at boot:

- **Default boot** → 5700 XT on host (amdgpu). Sunshine has full dGPU for flatscreen
  game streaming to Moonlight clients (Deck, phone, tablet). This is the daily mode.
- **VFIO boot** → 5700 XT reserved by vfio-pci for the SteamOS VM. SteamVR runs natively
  in the VM (no bubblewrap, async reprojection works). Used only for VR sessions.

No overlap: Sunshine streaming doesn't benefit from running through the VM (adds latency,
no benefit for flatscreen), and SteamVR can't run on the NixOS host (CAP_SYS_NICE blocked).
The specialisation cleanly separates these two use cases.

## Why this works on the UM780 XTX

- **Two GPUs**: Radeon 780M iGPU (host) + 5700 XT dGPU via OCuLink (guest). Clean split,
  no single-GPU hacks.
- **Excellent IOMMU groups**: Level1Techs confirms all USB controllers and the OCuLink GPU
  are in separate groups. No ACS override needed.
  (https://forum.level1techs.com/t/minisforum-um780-xtx-has-excellent-iommu-groups/204221)
- **AMD-Vi**: 7840HS supports IOMMU natively.
- **8C/16T**: Enough to pin 4-6 cores for the VM while host keeps 2-4.

## Architecture

```
┌─────────────────────────────────────────────────┐
│ NixOS Host (Jehoel)                              │
│  ├── Radeon 780M iGPU → niri desktop             │
│  ├── USB controller group A → host peripherals    │
│  ├── 32-64 GB RAM (allocate 16 GB to VM)         │
│  └── QEMU/KVM + libvirtd                         │
│       │                                           │
│       ├── VFIO: 5700 XT (GPU + HDMI audio)       │
│       ├── VFIO: USB controller group B            │
│       │    └── Steam Frame Wi-Fi 6E dongle       │
│       └── SteamOS guest VM                        │
│            ├── SteamVR (native, no sandbox)       │
│            ├── gamescope session                  │
│            └── Async reprojection ✅              │
└─────────────────────────────────────────────────┘
         │ HDMI (from 5700 XT)
         ▼
    Sony Bravia OLED (mirror view / setup)
         │ Wireless 6GHz (Steam Frame adapter)
         ▼
    Steam Frame headset
```

## Prerequisites

- [ ] BIOS: Enable AMD-Vi / IOMMU (SVM) in UM780 XTX BIOS
- [ ] Verify IOMMU groups on Jehoel — run the group listing script (below) with
      `amd_iommu=on iommu=pt` in kernelParams to confirm 5700 XT and a USB controller
      are in isolated groups
- [ ] Identify the 5700 XT's PCI vendor/device IDs: `lspci -nn | grep -i radeon`
- [ ] Identify which USB controller group to pass through (the one with the port where
      the Steam Frame dongle will be plugged in)
- [x] Fix `hardware.nix`: `kvm-intel` → `kvm-amd`, `cpu.intel` → `cpu.amd` (done)

## Implementation Phases

### Phase 1: NixOS host configuration (VFIO module)

**Status: Implemented** — `modules/features/vfio.nix` + specialisation in
`modules/hosts/jehoel/configuration.nix`.

The VFIO module (`self.nixosModules.vfio`) provides:
- `options.vfio.enable` — mkEnableOption, only active in the VFIO specialisation
- `options.vfio.gpuIds` — PCI IDs to passthrough (default: 5700 XT reference IDs)
- `options.vfio.usbIds` — optional USB controller PCI IDs for dongle passthrough
- VFIO kernel modules loaded before amdgpu in initrd
- libvirtd with QEMU/KVM, OVMF (UEFI), swtpm (TPM emulation)
- Looking Glass shared memory at `/dev/shm/looking-glass`
- virt-manager, pciutils, OVMF in system packages
- `vendor-reset` kernel module to mitigate the 5700 XT reset bug

The specialisation in Jehoel's `configuration.nix`:
```nix
specialisation = {
  "VFIO".configuration = {
    system.nixos.tags = [ "VFIO" ];
    vfio.enable = true;
  };
};
```

**Remaining before first use:**
- [ ] Verify 5700 XT PCI IDs in `vfio.gpuIds` match actual `lspci -nn` output
- [ ] Identify and set `vfio.usbIds` for the USB controller whose port will host
      the Steam Frame dongle (run IOMMU group script, pick an isolated controller)
- [ ] BIOS: enable AMD-Vi / SVM

### Phase 2: SteamOS VM creation

SteamOS doesn't ship as a standard ISO — it comes as a Steam Deck recovery image
(.bz2). The VM needs special handling:

1. Download Steam Deck recovery image from Valve:
   https://help.steampowered.com/en/faqs/view/65B4-2AA3-5F37-4227

2. Convert to qcow2 and place in libvirt images:
   ```bash
   decompress steamdeck-recovery.img.bz2
   qemu-img convert -O qcow2 steamdeck-recovery.img \
     /var/lib/libvirt/images/steamos-recovery.qcow2
   ```

3. Create a virtual NVMe disk (SteamOS installer expects `/dev/nvme0n1`):
   ```bash
   qemu-img create -f qcow2 /var/lib/libvirt/images/steamos-disk.qcow2 120G
   ```

4. VM XML config (via virsh or virt-manager):
   - **Machine type**: `q35` (required for PCIe passthrough)
   - **BIOS**: OVMF (UEFI) — use the NixOS-provided OVMF firmware
   - **CPU**: `host-passthrough`, pin 6 vCPUs (7840HS has 8C/16T)
   - **RAM**: 16 GB
   - **Disk**: NVMe emulation (`-device nvme,drive=nvme0,serial=badbeef`)
   - **GPU passthrough**: 5700 XT PCI devices (both VGA + audio functions)
   - **USB controller passthrough**: The controller whose ports will host
     the Steam Frame Wi-Fi 6E dongle
   - **Video model**: `none` (disable QEMU's virtual display — use GPU output only)
   - **Looking Glass**: Add ivshmem device for host-side display preview

5. Boot from recovery image, run SteamOS installer targeting the virtual NVMe.
   After install, before rebooting into Gaming Mode:
   - Ctrl+Alt+F2 to get a terminal
   - Force desktop mode autologin on both A/B partitions:
     ```bash
     sudo steamos-chroot --disk nvme0n1 --partset A --no-overlay
     steamos-readonly disable
     echo '[Autologin]' > /etc/sddm.conf.d/zz-steamos-autologin.conf
     echo 'Session=plasma.desktop' >> /etc/sddm.conf.d/zz-steamos-autologin.conf
     steamos-readonly enable
     exit
     # Repeat for --partset B
     ```

6. After first boot to Plasma desktop: install SteamVR from Steam.

### Phase 3: Steam Frame integration (when hardware ships)

1. Plug the Steam Frame's Wi-Fi 6E USB adapter into a port on the **passed-through
   USB controller** (not a host-controlled port)
2. Boot the SteamOS VM
3. Launch SteamVR — it should detect the adapter and connect to the headset's
   6GHz point-to-point link
4. The 5700 XT renders VR content, encodes it, and streams via the wireless adapter
5. Foveated streaming (eye-tracked bandwidth optimization) is handled by the headset
   — transparent to the host

### Phase 4: Looking Glass (optional, for host-side monitoring)

Looking Glass provides a low-latency capture of the VM's framebuffer into a
host-side window. Useful for:
- Monitoring SteamVR status without switching the TV input
- Initial setup before SteamVR is running
- Troubleshooting

The shared memory device (`/dev/shm/looking-glass`) is already configured in Phase 1.
Add the ivshmem PCI device to the VM XML, then run `looking-glass-client` on the
NixOS host.

## Known gotchas / risks

1. **5700 XT reset bug**: Some AMD GPUs don't cleanly reset when the VM shuts down,
   requiring a host reboot to reuse the GPU. The 5700 XT (RDNA1/Navi 10) is
   affected. Mitigation: the `vendor-reset` kernel module, or accept host reboot
   when restarting the VM. Check current status when implementing.

2. **Dual amdgpu binding**: Both the 780M iGPU and the 5700 XT use the `amdgpu`
   driver. VFIO claims the 5700 XT by PCI ID before amdgpu loads, but verify the
   iGPU still works for the host display after enabling VFIO. If both get claimed
   by vfio-pci, the host loses its display.

3. **SteamOS updates**: The VM's SteamOS will update itself (A/B partition scheme).
   Read-only root means custom changes need `steamos-readonly disable` first.
   Updates may overwrite the desktop-mode autologin hack.

4. **Audio**: The 5700 XT's HDMI audio goes to the TV. For VR audio (headset),
   that's handled by the Steam Frame itself. Host audio stays on the iGPU/HDMI
   or whatever Jehoel currently uses.

5. **Performance overhead**: VFIO passthrough is near-bare-metal (~95-98%) for
   GPU compute. CPU overhead from virt is minimal with host-passthrough + KVM.
   The 5700 XT over OCuLink (PCIe 3.0 x4) already has some bandwidth overhead
   vs a native PCIe slot — VM adds negligible additional overhead on top.

6. **`kvm-intel` → `kvm-amd`**: FIXED — hardware.nix was loading `kvm-intel`
   (leftover from mab's Intel NUC). Changed to `kvm-amd` and
   `hardware.cpu.amd.updateMicrocode`.

7. **Performance overhead**: VFIO passthrough is near-bare-metal for GPU
   compute (~2-5% overhead). The 5700 XT over OCuLink (PCIe 3.0 x4, ~32 Gbps)
   is the larger bottleneck but mainly affects texture upload bandwidth, not
   render performance. CPU overhead with host-passthrough + KVM is single-digit
   microseconds. VFIO adds ~1-2ms to motion-to-photon latency — well within
   VR's ~20ms budget. The dominant latency factors are the wireless link and
   headset-side processing.

## IOMMU group verification script

Run this after adding `amd_iommu=on iommu=pt` to kernelParams and rebooting:

```bash
for d in /sys/kernel/iommu_groups/*/devices/*; do
  g=$(echo "$d" | cut -d/ -f5)
  echo "Group $g: $(lspci -nn | grep "$(basename $d)")"
done
```

Look for:
- 5700 XT (VGA + audio) in a group with no host-critical devices
- A USB controller in its own group for the Steam Frame dongle

## Resources

- NixOS Wiki: https://wiki.nixos.org/wiki/PCI_passthrough
- astrid.tech VFIO + VR: https://astrid.tech/2022/09/30/0/nixos-vfio/
- pigs.dev NixOS gaming VM: https://pigs.dev/posts/2025-04-15-gaming-in-vm-with-nixos.html
- SteamOS in QEMU: https://dev.to/retro-1o1/virtualizing-steamos-with-qemukvm-the-steps-nobody-tells-you-2mcm
- Proxmox SteamOS guide (transferable to libvirtd): https://proxmoxpulse.com/articles/steamos-vm-proxmox-gpu-passthrough-gaming/
- UM780 XTX IOMMU groups: https://forum.level1techs.com/t/minisforum-um780-xtx-has-excellent-iommu-groups/204221
