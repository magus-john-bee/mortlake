# Herdr — agent multiplexer (herdr.dev). "tmux for coding agents."
# Manages panes for Pi, Codex, Hermes, etc. Tracks lifecycle state
# (idle/working/blocked) and provides session restore.
#
# Per-user integrations are installed after first boot:
#   herdr integration install pi      (lifecycle hooks)
#   herdr integration install hermes   (lifecycle hooks)
#   herdr integration install codex    (session identity)
{ ... }:
{
  flake.nixosModules.herdr =
    { pkgs, ... }:
    {
      # TODO: Check nixpkgs availability. If not packaged, may need
      # flake input from GitHub releases or manual install script.
      environment.systemPackages = [ pkgs.herdr ];

      preservation.preserveAt."/persistent".users.john.directories = [
        ".config/herdr"
        ".local/share/herdr"
      ];
    };
}
