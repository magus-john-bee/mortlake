# Herdr — agent multiplexer (herdr.dev). "tmux for coding agents."
# Manages panes for Pi, Hermes, etc. Tracks lifecycle state
# (idle/working/blocked) and provides session restore.
#
# Packaged in numtide/llm-agents.nix (buildRustPackage + vendored Zig deps
# for libghostty-vt). Binary cache at cache.numtide.com (configured in pi.nix).
#
# Per-user integrations are installed after first boot:
#   herdr integration install pi      (lifecycle hooks)
#   herdr integration install hermes  (lifecycle hooks)
{ inputs, ... }:
{
  flake.nixosModules.herdr =
    { pkgs, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;
      herdr = inputs.llm-agents.packages.${system}.herdr;
    in
    {
      environment.systemPackages = [ herdr ];

      preservation.preserveAt."/persistent".users.john.directories = [
        ".config/herdr"
        ".local/share/herdr"
      ];
    };
}
