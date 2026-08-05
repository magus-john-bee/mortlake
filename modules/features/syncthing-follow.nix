let
  userName = "john";
  groupName = "users";
  syncthingDir = "/var/lib/syncthing";
  syncthingConfigDir = "${syncthingDir}/config";
  st = "${syncthingDir}/st";
  mab = "D7H24MQ-MQYRB7T-TZUFCIT-V2F77AK-6FVKX3Z-MKS7I5V-63JCDZR-7VMPRQJ";
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
          "mab".id = mab;
        };
        folders = {
          "st" = {
            path = st;
            devices = [ "mab" ];
          };
        };
      };
    };
  };
}
