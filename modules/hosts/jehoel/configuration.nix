{ self, ... }:
{
  flake.nixosModules.jehoelConfiguration =
    { pkgs, lib, ... }:
    {
      imports = [
        self.nixosModules.jehoelHardware
        self.nixosModules.jehoelDisko
        self.nixosModules.preservation-common
        self.nixosModules.clock
        self.nixosModules.network
        self.nixosModules.packages
        self.nixosModules.john
        self.nixosModules.nix-qol
        self.nixosModules.sops
        self.nixosModules.gh
        self.nixosModules.git
        self.nixosModules.zsh
        self.nixosModules.atuin
        self.nixosModules.helix
        self.nixosModules.zellij
        self.nixosModules.dev-dirs
        self.nixosModules.restic
        self.nixosModules.nerd-fonts

        # Server role
        self.nixosModules.nginx
        self.nixosModules.jellyfin
        self.nixosModules.transmission
        self.nixosModules.mealie
        self.nixosModules.syncthing-lead
        self.nixosModules.dd-client
        self.nixosModules.nix-serve

        # Desktop role
        self.nixosModules.niri
        self.nixosModules.greetd
        self.nixosModules.ghostty
        self.nixosModules.browser
        self.nixosModules.sound

        # AI tooling
        self.nixosModules.pi
        self.nixosModules.herdr
        self.nixosModules.taskdog
      ];

      networking = {
        hostName = "jehoel";
        useDHCP = lib.mkDefault true;
      };

      networking.firewall.allowedTCPPorts = [
        22
        80
        443
      ];

      environment.systemPackages = with pkgs; [
        ffmpeg
        yt-dlp
        magic-wormhole
      ];

      preservation.preserveAt."/persistent" = {
        directories = [
          "/var/lib/bluetooth"
          "/var/lib/acme"
          "/var/lib/nginx"
          {
            directory = "/var/lib/transmission";
            user = "john";
            group = "users";
          }
          {
            directory = "/var/lib/mealie";
            user = "john";
            group = "users";
          }
        ];

        users.john.directories = [ "data" ];
      };

      # No post-build-hook here: this host RUNS the cache (nix-serve reads
      # straight from the local store), so pushing to itself is a no-op that
      # just burns an SSH round-trip (and fails host-key verification) per
      # build. Clients (raphael, thoth) push here; jehoel only serves.

      system.stateVersion = "25.11";
    };
}
