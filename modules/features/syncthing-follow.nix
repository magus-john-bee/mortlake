let
  userName = "john";
  groupName = "users";
  syncthingDir = "/var/lib/syncthing";
  syncthingConfigDir = "${syncthingDir}/config";
  st = "${syncthingDir}/st";
  vault = "${syncthingDir}/vault";
  # Hub = jehoel (syncthing-lead). Hub-and-spoke: this device only knows
  # the hub; st and vault are shared with it exclusively.
  jehoel = "HHZ2ZME-NTVYDQC-2MVT6VX-6KIKWI4-F3R2KDS-OM6WCKT-W4TDXUX-Y6ERQQI";
in
{
  flake.nixosModules.syncthing-follow =
    { config, lib, ... }:
    {
      systemd.tmpfiles.rules = [
        "d ${syncthingDir} 0755 ${userName} ${groupName}"
        "d ${syncthingConfigDir} 0755 ${userName} ${groupName}"
        "d ${st} 0755 ${userName} ${groupName}"
        # 0700: keepass vault (usage side: keepass.nix)
        "d ${vault} 0700 ${userName} ${groupName}"
      ];

      services.syncthing = {
        enable = true;
        user = userName;
        configDir = syncthingConfigDir;
        dataDir = syncthingDir;
        overrideDevices = true;
        overrideFolders = true;
        openDefaultPorts = true;
        settings = {
          devices = {
            "jehoel".id = jehoel;
          };
          folders = {
            "st" = {
              path = st;
              devices = [ "jehoel" ];
            };
            # Keepass vault, spoke side — mirrors the hub declaration in
            # syncthing-lead.nix (path, versioning, peers). Guarded:
            # uriel also imports this module but is NOT a vault peer
            # (decommission-bound); drop the mkIf when uriel is gone.
            "vault" = lib.mkIf (config.networking.hostName == "raphael") {
              path = vault;
              devices = [ "jehoel" ];
              versioning = {
                type = "staggered";
                params.maxAge = "31536000";
              };
            };
          };
        };
      };
    };
}
