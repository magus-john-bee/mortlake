# Herdr — agent multiplexer (herdr.dev). "tmux for coding agents."
# Manages panes for Pi, Hermes, etc. Tracks lifecycle state
# (idle/working/blocked) and provides session restore.
#
# Packaged in numtide/llm-agents.nix (buildRustPackage + vendored Zig deps
# for libghostty-vt). Binary cache at cache.numtide.com (configured in
# nix-qol.nix).
#
# Config: declarative via wrapper (HERDR_CONFIG_PATH -> /etc herdr/config.toml,
# herdr/config.toml below) — no symlink, per the atuin shape. Herdr writes
# config.toml for in-TUI settings edits; those fail against the read-only
# /etc path, so settings live here. Session logs in ~/.config/herdr are
# deliberately ephemeral (tmpfs, reboot-wiped).
# Agent integrations land in each agent's own config dir (e.g.
# ~/.pi/agent/extensions/), persisted where the agent module says so:
#   herdr integration install pi      (lifecycle hooks)
#   herdr integration install hermes  (lifecycle hooks)
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.herdr = inputs.wrapper-modules.lib.wrapPackage (_: {
        inherit pkgs;
        package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
        env.HERDR_CONFIG_PATH = "/etc/herdr/config.toml";
      });
    };

  flake.nixosModules.herdr =
    { pkgs, ... }:
    {
      environment.etc."herdr/config.toml".source = ./herdr/config.toml;

      environment.systemPackages = [
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.herdr
      ];

      # Session/workspace state survives reboots; config does not (see header).
      preservation.preserveAt."/persistent".users.john.directories = [
        ".local/share/herdr"
      ];
    };
}
