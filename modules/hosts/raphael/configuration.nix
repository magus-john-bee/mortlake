{ self, ... }:
{
  flake.nixosModules.raphaelConfiguration =
    {
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        self.nixosModules.raphaelHardware
        self.nixosModules.raphaelDisko
        self.nixosModules.preservation-common
        self.nixosModules.john
        self.nixosModules.clock
        self.nixosModules.network
        self.nixosModules.packages
        self.nixosModules.the-aether
        self.nixosModules.nix-qol
        self.nixosModules.sops
        self.nixosModules.gh
        self.nixosModules.git
        self.nixosModules.zsh
        self.nixosModules.atuin
        self.nixosModules.helix
        self.nixosModules.zellij
        self.nixosModules.nerd-fonts
        self.nixosModules.niri
        self.nixosModules.greetd
        self.nixosModules.ghostty
        self.nixosModules.browser
        self.nixosModules.syncthing-follow
        # AI tooling
        self.nixosModules.pi
        self.nixosModules.herdr
        self.nixosModules.taskdog
      ];

      # Taskdog client — server lives on uriel (taskdog.otwell.dev).
      services.taskdog.client.enable = true;

      networking = {
        hostName = "raphael";
        useDHCP = lib.mkDefault true;
        networkmanager.enable = true;
      };

      environment.systemPackages = with pkgs; [
        grim
        slurp
      ];

      preservation.preserveAt."/persistent" = {
        directories = [
          "/etc/NetworkManager/system-connections"
          "/var/lib/bluetooth"
        ];
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
