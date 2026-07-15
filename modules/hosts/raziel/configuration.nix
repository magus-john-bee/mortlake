# Raziel — GrapheneOS Pixel (de-Googled, privacy-focused)
#
# GrapheneOS ships without Google Play Services.  This nix-on-droid
# config provides a full Linux userspace for CLI work, development,
# and self-provisioning via ADB (android-tools + fdroidcl are
# available in-path so the device can provision itself).
#
# Exposed as flake.nixOnDroidModules.razielConfiguration so that
# import-tree evaluates this file as a flake-parts module (the actual
# nix-on-droid module is the inner function).
{ self, ... }:
{
  flake.nixOnDroidModules.razielConfiguration =
    { pkgs, ... }:
    let
      # ── Shared base package list ──────────────────────────────
      # Identical across raziel and haniel.  If you add a tool here,
      # mirror it in haniel/configuration.nix.
      basePackages = with pkgs; [
        vim
        git
        openssh
        python3
        yq
        android-tools # self-provisioning via ADB
        fdroidcl # self-provisioning via F-Droid
        neovim
        fzf
        bat
        fd
        ripgrep
        tmux
      ];
    in
    {
      # ── Packages ──────────────────────────────────────────────
      environment.packages = basePackages ++ (with pkgs; [
        # Raziel-specific (privacy / crypto)
        gnupg
        pass
      ]);

      # ── Terminal / SSH ────────────────────────────────────────
      environment.etc = {
        "ssh/ssh_config".text = ''
          Host *
            ServerAliveInterval 60
            # GrapheneOS devices may sleep aggressively; keep connections alive.
            ServerAliveCountMax 3
        '';
      };

      environment.etc."profile.d/nix-editor.sh".text = ''
        export EDITOR=nvim
        export NIX_REMOTE=daemon
      '';

      # ── Nix ───────────────────────────────────────────────────
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        # Use the same binary cache as the mortlake NixOS hosts.
        extra-substituters = [ "https://cache.otwell.dev" ];
        extra-trusted-public-keys = [
          "cache.otwell.dev:1uNVs/iKY7NnLUcSoS++Zl2+iWl9qw1VuC0Fa5Lkt4I="
        ];
      };

      # ── State version ─────────────────────────────────────────
      system.stateVersion = "24.05";
    };
}
