# Ramiel — GrapheneOS Pixel Tablet (de-Googled, privacy-focused)
#
# GrapheneOS tablet. Shares the same base nix-on-droid userspace as raziel.
# Exposed as flake.nixOnDroidModules.remielConfiguration so that import-tree
# evaluates this file as a flake-parts module.
{ self, ... }:
{
  flake.nixOnDroidModules.remielConfiguration =
    { pkgs, ... }:
    let
      # Shared base — keep in sync with raziel/haniel
      basePackages = with pkgs; [
        vim
        git
        openssh
        python3
        yq
        android-tools
        fdroidcl
        neovim
        fzf
        bat
        fd
        ripgrep
        tmux
      ];
    in
    {
      environment.packages = basePackages ++ (with pkgs; [
        gnupg
        pass
      ]);

      # Shared aliases + pinned host keys + keep-alive — single source
      # of truth in modules/features/ssh-aliases.nix.
      environment.etc = {
        "ssh/ssh_config".text = self.sshClient.configText;
        "ssh/ssh_known_hosts".text = self.sshClient.knownHostsText;
      };

      environment.etc."profile.d/nix-editor.sh".text = ''
        export EDITOR=nvim
        export NIX_REMOTE=daemon
      '';

      # nix-on-droid has no nix.settings — flat options instead, and
      # the listOf ones merge with the module defaults (cache.nixos.org
      # and nix-on-droid.cachix.org survive).
      nix = {
        extraOptions = ''
          experimental-features = nix-command flakes
        '';
        substituters = [ "https://cache.otwell.dev" ];
        trustedPublicKeys = [
          "cache.otwell.dev:1uNVs/iKY7NnLUcSoS++Zl2+iWl9qw1VuC0Fa5Lkt4I="
        ];
      };

      system.stateVersion = "24.05";
    };
}
