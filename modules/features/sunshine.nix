# Sunshine — open-source game streaming server (Moonlight client).
# Requires Vulkan (RADV on AMD), hardware-accelerated video encoding,
# and Wayland session capture.
{ lib, ... }:
{
  flake.nixosModules.sunshine =
    { pkgs, ... }:
    {
      hardware.graphics.enable = true;

      # AMD-specific: ensure RADV Vulkan driver and VAAPI
      environment.systemPackages = with pkgs; [
        vulkan-tools
        vulkan-loader
        vulkan-validation-layers
        mesa
        libva
      ];

      services.sunshine = {
        enable = true;
        autoStart = true;
        capSysAdmin = true; # needed for Wayland capture
        openFirewall = true; # ports 47984-48010 TCP/UDP
      };

      # Persistence for Sunshine config/credentials
      preservation.preserveAt."/persistent".users.john.directories = [
        ".config/sunshine"
      ];
    };
}
