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

      environment.etc = {
        "ssh/ssh_config".text = ''
          Host *
            ServerAliveInterval 60
            ServerAliveCountMax 3
        '';
      };

      environment.etc."profile.d/nix-editor.sh".text = ''
        export EDITOR=nvim
        export NIX_REMOTE=daemon
      '';

      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        extra-substituters = [ "https://cache.otwell.dev" ];
        extra-trusted-public-keys = [
          "cache.otwell.dev:1uNVs/iKY7NnLUcSoS++Zl2+iWl9qw1VuC0Fa5Lkt4I="
        ];
      };

      system.stateVersion = "24.05";
    };
}
