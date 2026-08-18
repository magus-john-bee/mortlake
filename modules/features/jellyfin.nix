# Jellyfin — LAN-only by default. No nginx reverse proxy.
# For remote access, import jellyfin-public.nix alongside this module.
_:
{
  flake.nixosModules.jellyfin = _: {
    networking.firewall.allowedTCPPorts = [ 8096 ]; # LAN access

    services.jellyfin = {
      enable = true;
      user = "john";
      group = "users";
    };

    # Jellyfin state — owned by the service user/group declared above.
    preservation.preserveAt."/persistent".directories = [
      {
        directory = "/var/lib/jellyfin";
        user = "john";
        group = "users";
      }
    ];
  };
}
