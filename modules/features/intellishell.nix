# IntelliShell — searchable shell command bookmarks with zsh hotkeys
# (ctrl+space search / ctrl+b bookmark / ctrl+l variables / ctrl+x fix,
# wired in zsh/zshrc.zsh).
#
# Cross-host sync is manual via the CLI (gist configured below):
#   intelli-shell import gist   # pull + union
#   intelli-shell export gist   # push the union back
# GIST_TOKEN is exported by zshrc, so both work from any interactive
# shell. Import is a union merge (idempotent); export PATCHes the gist —
# run it as john in a real shell only. An earlier systemd-timer sync was
# dropped as overkill; see git history if it's ever wanted back.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  flake.nixosModules.intellishell =
    _:
    let
      cfg = config.services.intellishell;
    in
    {
      options.services.intellishell = {
        enable = lib.mkEnableOption "IntelliShell (package + config; sync is manual)";
        gistId = lib.mkOption {
          type = lib.types.str;
          default = "4c83e47d1df90765651d45f73e87132c";
          description = "GitHub gist id used as the sync hub";
        };
      };

      config = lib.mkIf cfg.enable {
        environment = {
          etc."intellishell/config.toml".text = ''
            check_updates = false
            inline = true

            [gist]
            id = "${cfg.gistId}"
            token = ""

            [tui]
            keyboard_enhancement = true

            [search]
            mode = "auto"
          '';

          systemPackages = [ pkgs.intelli-shell ];
        };

        # tmpfs root: the bookmarks db must survive reboots.
        preservation.preserveAt."/persistent" = {
          users.john.directories = [ ".local/share/intelli-shell" ];
        };
      };
    };
}
