# Herdr — agent multiplexer (herdr.dev). "tmux for coding agents."
# Manages panes for Pi, Hermes, etc. Tracks lifecycle state
# (idle/working/blocked) and provides session restore.
#
# Packaged in numtide/llm-agents.nix (buildRustPackage + vendored Zig deps
# for libghostty-vt). Binary cache at cache.numtide.com (configured in
# nix-qol.nix).
#
# No ~/.config/herdr persistence: herdr works without a config.toml (none
# exists on any host) — if one is ever needed, declare it in mortlake and
# symlink it in, same as nyxt.nix does for config.lisp. Session logs also live
# in ~/.config/herdr; they are deliberately ephemeral (tmpfs, reboot-wiped).
# Agent integrations land in each agent's own config dir (e.g.
# ~/.pi/agent/extensions/), persisted where the agent module says so:
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

      # Session/workspace state survives reboots; config does not (see header).
      preservation.preserveAt."/persistent".users.john.directories = [
        ".local/share/herdr"
      ];
    };
}
