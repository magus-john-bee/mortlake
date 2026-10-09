# Atuin — shell history sync, via the upstream NixOS module.
#
# One atuin: no wrapped package, no custom theme (marine is builtin in
# atuin 18.21, the nixpkgs pin), no login service. The encryption key
# is a sops secret pointed at by key_path; the session token lives in
# meta.db inside the persisted data dir. `atuin login` is therefore a
# ONE-TIME manual step per host (session tokens don't expire), as john,
# after activation (prompts for the password via stdin — atuin's
# documented-preferred form):
#
#   atuin login -u <username> -k "$(cat /run/secrets/atuin-key)"
#   atuin sync
#
# (Historical: uriel could not decrypt the old supersecrets.yaml; the
# 2026-10-08 merge into secrets.yaml made that split moot.)
# (see .sops.yaml key_groups) and is being decommissioned. It still gets
# the plain pkgs.atuin binary via zsh.nix systemPackages.
_: {
  flake.nixosModules.atuin =
    { config, ... }:
    {
      programs.atuin = {
        enable = true;

        # House shell is zsh; the init snippet is evaluated once in
        # zsh/zshrc.zsh INSIDE zvm_after_init — atuin's keybinds must be
        # installed after zsh-vi-mode's or zvm clobbers them. The module's
        # own zsh hook would double-init (it lands in /etc/zshrc, which
        # runs before ZDOTDIR's .zshrc). The module DOES set
        # ATUIN_CONFIG_DIR=/etc/atuin globally — which is what makes the
        # plain pkgs.atuin binary (eval'd by zshrc.zsh at a store path, no
        # wrapper env) read the settings below.
        enableZshIntegration = false;

        # Sync runs via the shell hook (auto_sync + sync_frequency, checked
        # per command); the daemon socket unit would exist but never be
        # used — atuin's own [daemon] enabled defaults to false.
        daemon.enable = false;

        settings = {
          auto_sync = true;
          sync_frequency = "2m";
          search_mode = "fuzzy";
          filter_mode = "global";
          style = "compact";
          keymap_mode = "vim-insert";
          # Builtin theme — no theme file, no programs.atuin.themes entry.
          theme.name = "marine";
          sync.records = true;
          # Encryption key from sops: declarative and survives /persistent
          # loss, unlike a key file inside the data dir.
          key_path = config.sops.secrets."atuin-key".path;
        };
      };

      # The only sops secret atuin needs long-term: the encryption key,
      # pointed at by key_path above. Username/password are NOT stored —
      # the one-time manual login (above) prompts for the password via
      # stdin. Re-login is rare: new host, or the session token is
      # revoked (the token itself lives in the persisted meta.db).
      sops.secrets."atuin-key" = {
        owner = "john";
        sopsFile = ./secrets.yaml;
      };

      # The reason the old atuin-login service existed: without this,
      # tmpfs root wipes meta.db (session) + history.db every boot and
      # a service had to re-login and re-sync the world. Persist the
      # data dir instead; restic already snapshots this exact path on
      # jehoel/raphael (restic.nix).
      preservation.preserveAt."/persistent".users.john.directories = [
        ".local/share/atuin"
      ];
    };
}
