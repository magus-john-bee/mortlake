# Minimal bootstrap config for Jehoel — just enough to boot, get WiFi,
# and nixos-rebuild switch to the full jehoel config.
{ self, ... }:
{
  flake.nixosModules.jehoelBootstrapConfiguration =
    { lib, pkgs, ... }:
    {
  imports = [
    self.nixosModules.jehoelHardware
    self.nixosModules.jehoelDisko
    self.nixosModules.preservation-common
  ];

  networking = {
    hostName = "humbled-jehoel";
    useDHCP = lib.mkDefault true;
    networkmanager.enable = true;
    firewall.enable = true;
  };

  # Password auth for bootstrap — no SSH keys deployed yet
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  users.mutableUsers = true;
  users.users.john = {
    isNormalUser = true;
    description = "john";
    extraGroups = [ "wheel" "networkmanager" ];
    hashedPassword = "$6$nhupSF2Neq$m61opyOxxlZAt10pdgSw/ORYlLOGa8efAF7dfKVRas8Wl4hVaSUI4d5poAk9VnMFY/xejKkZjst26INwMWrZZ.";
  };

  security.sudo.extraRules = [
    {
      users = [ "john" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];

  nix.settings.trusted-users = [ "root" "john" ];

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    networkmanager
  ];

  system.stateVersion = "25.11";
    };
}
