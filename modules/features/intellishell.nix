_: {
  flake.nixosModules.intellishell =
    { pkgs, ... }:
    {
      environment = {
        etc."intellishell/config.toml".text = ''
          check_updates = false
          inline = true

          [gist]
          id = "4c83e47d1df90765651d45f73e87132c"
          token = ""

          [tui]
          keyboard_enhancement = true

          [search]
          mode = "auto"
        '';

        systemPackages = [ pkgs.intelli-shell ];
      };

      preservation.preserveAt."/persistent" = {
        users.john.directories = [ ".local/share/intelli-shell" ];
      };
    };
}
