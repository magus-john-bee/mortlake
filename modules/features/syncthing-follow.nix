let
  userName = "john";
  groupName = "users";
  syncthingDir = "/var/lib/syncthing";
  syncthingConfigDir = "${syncthingDir}/config";
  st = "${syncthingDir}/st";
  # Hub = jehoel (syncthing-lead). Hub-and-spoke: this device only knows
  # the hub; st is shared with it exclusively.
  jehoel = "HHZ2ZME-NTVYDQC-2MVT6VX-6KIKWI4-F3R2KDS-OM6WCKT-W4TDXUX-Y6ERQQI";
in
{
  flake.nixosModules.syncthing-follow = _: {
    systemd.tmpfiles.rules = [
      "d ${syncthingDir} 0755 ${userName} ${groupName}"
      "d ${syncthingConfigDir} 0755 ${userName} ${groupName}"
      "d ${st} 0755 ${userName} ${groupName}"
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
        };
      };
    };
  };
}
