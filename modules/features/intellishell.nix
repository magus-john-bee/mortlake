# IntelliShell — searchable shell command bookmarks with zsh hotkeys
# (ctrl+space search / ctrl+b bookmark / ctrl+l variables / ctrl+x fix,
# wired in zsh/zshrc.zsh). Import-based like podman/nginx/gh: no options
# — every host that imports this module gets it.
#
# Cross-host sync is manual via the CLI (gist id below); zshrc aliases:
#   iig  # intelli-shell import gist && intelli-shell export gist
#   ieg  # intelli-shell export gist
# GIST_TOKEN is exported by zshrc. Import is a union merge (idempotent);
# export PATCHes the gist — run it as john in a real shell only. An
# earlier options + systemd-timer version was simplified away; see git
# history.
{ pkgs, ... }:
{
  flake.nixosModules.intellishell = {
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

    # tmpfs root: the bookmarks db must survive reboots.
    preservation.preserveAt."/persistent" = {
      users.john.directories = [ ".local/share/intelli-shell" ];
    };
  };
}
