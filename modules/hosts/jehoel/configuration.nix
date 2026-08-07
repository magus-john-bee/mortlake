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

        # GPU + game streaming
        self.nixosModules.sunshine

        # VFIO GPU passthrough (5700 XT → SteamOS VM for SteamVR).
        # Enabled via "VFIO" specialisation — boot into that entry to
        # reserve the GPU for the VM. Default boot leaves GPU on host.
        self.nixosModules.vfio

        # AI tooling
        self.nixosModules.herdr
        self.nixosModules.taskdog
      ];

      networking = {
        hostName = "jehoel";
        useDHCP = lib.mkDefault true;
      };

      # VFIO specialisation: boot into "VFIO" entry to reserve the 5700 XT
      # for the SteamOS VM. Default boot keeps the GPU on the host for
      # Sunshine / desktop use. Two distinct modes, no runtime conflict.
      specialisation = {
        "VFIO".configuration = {
          system.nixos.tags = [ "VFIO" ];
          vfio.enable = true;
        };
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
          "/var/lib/acme"
          "/var/lib/nginx"
          {
            directory = "/var/lib/jellyfin";
            user = "john";
            group = "users";
          }
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

      nix.settings.post-build-hook =
        let
          hook = pkgs.writeShellScript "push-to-cache" ''
            ${pkgs.nix}/bin/nix copy --to ssh://john@jehoel $OUT_PATHS || true
          '';
        in
        "${hook}";

      system.stateVersion = "25.11";
    };
}
