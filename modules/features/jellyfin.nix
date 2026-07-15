# Jellyfin — LAN-only by default. No nginx reverse proxy.
# For remote access, import jellyfin-public.nix alongside this module.
_:
{
  flake.nixosModules.jellyfin = _: {
    mortlake.restic = {
      paths = [ "/var/lib/jellyfin" ];
      exclude = [ "/var/lib/jellyfin/transcodes" ];
    };

    networking.firewall.allowedTCPPorts = [ 8096 ]; # LAN access

    services.jellyfin = {
      enable = true;
      user = "john";
      group = "users";
    };
  };
}
