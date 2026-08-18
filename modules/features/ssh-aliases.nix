# Shared SSH client definitions — the single source of truth for host
# aliases, pinned host keys, and keep-alive settings.
#
# Consumed by:
#   - modules/features/network.nix         (NixOS: programs.ssh.*)
#   - modules/hosts/{haniel,raziel,remiel} (nix-on-droid: environment.etc —
#     that API has no programs.ssh module, so the same strings are written
#     to /etc/ssh/ssh_config and /etc/ssh/ssh_known_hosts directly)
#
# Key provenance (verified 2026-08-18):
#   - uriel AAAA…qq5X (root@thoth): on-disk read on uriel itself,
#     byte-identical to what 87.99.146.205:22 presents. The comment
#     predates the thoth->uriel rename.
#   - jehoel AAAA…p0z: keyscan-presented == john@uriel's known_hosts
#     entry, and derives via ssh-to-age to the &jehoel anchor in
#     .sops.yaml — only the holder of that private key could produce a
#     working sops decryptor.
{ lib, ... }:
let
  hosts = {
    uriel = {
      address = "87.99.146.205";
      user = "john";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA8+i8bREEEwTtYIGoldz0OQaB4YFKt+wG+MHf1caq5X";
    };
    jehoel = {
      address = "ssh.otwell.dev";
      user = "john";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDPeQiYDQJGWpEnXZSwVIFm8CJ+95iOwhl06SfGnap0z";
    };
  };

  aliasBlocks = builtins.concatStringsSep "\n\n" (builtins.attrValues (
    builtins.mapAttrs (name: h: "Host ${name}\n  HostName ${h.address}\n  User ${h.user}") hosts
  ));

  configText = ''
    Host *
      ServerAliveInterval 60
      ServerAliveCountMax 3

    ${aliasBlocks}
  '';

  knownHostsText =
    builtins.concatStringsSep "\n" (
      builtins.attrValues (builtins.mapAttrs (_: h: "${h.address} ${h.publicKey}") hosts)
    ) + "\n";
in
{
  options.flake.sshClient = {
    hosts = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = "Shared SSH host registry (address, user, pinned publicKey).";
    };
    configText = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "ssh_config text: keep-alive defaults + Host aliases.";
    };
    knownHostsText = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "ssh_known_hosts lines: one 'address key' per host.";
    };
  };

  config.flake.sshClient = { inherit hosts configText knownHostsText; };
}
