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
      environment = {
        packages =
          basePackages
          ++ (with pkgs; [
            # Raziel-specific (privacy / crypto)
            gnupg
            pass
          ]);

        # ── Terminal / SSH ────────────────────────────────────────
        # Shared aliases + pinned host keys + keep-alive — single source
        # of truth in modules/features/ssh-aliases.nix.
        etc = {
          "ssh/ssh_config".text = self.sshClient.configText;
          "ssh/ssh_known_hosts".text = self.sshClient.knownHostsText;
          "profile.d/nix-editor.sh".text = ''
            export EDITOR=nvim
            export NIX_REMOTE=daemon
          '';
        };
      };

      # ── Nix ───────────────────────────────────────────────────
      # nix-on-droid has no nix.settings — flat options instead, and
      # the listOf ones merge with the module defaults (cache.nixos.org
      # and nix-on-droid.cachix.org survive).
      nix = {
        extraOptions = ''
          experimental-features = nix-command flakes
        '';
        # Use the same binary caches as the mortlake NixOS hosts (nix-qol.nix).
        # numtide serves aarch64 for the llm-agents.nix packages (pi, herdr).
        substituters = [
          "https://cache.otwell.dev"
          "https://cache.numtide.com"
        ];
        trustedPublicKeys = [
          "cache.otwell.dev:1uNVs/iKY7NnLUcSoS++Zl2+iWl9qw1VuC0Fa5Lkt4I="
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        ];
      };

      # ── State version ─────────────────────────────────────────
      system.stateVersion = "24.05";
    };
}
