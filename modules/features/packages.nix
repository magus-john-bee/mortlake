{ self, ... }:
{
  flake.nixosModules.packages =
    { pkgs, ... }:
    let
      # Utility scripts defined as flake packages (scripts.nix).
      # Also available via `nix run .#<name>`, but we add them to
      # systemPackages so they're in PATH directly on every host.
      flakePackages = builtins.attrValues (self.packages.${pkgs.stdenv.hostPlatform.system} or { });
    in
    {
      environment.systemPackages =
        with pkgs;
        [
          # ── Core ──
          curl
          wget
          vim
          ghostty.terminfo

          # ── Nix / config tooling ──
          age
          check-jsonschema
          direnv
          nickel
          nh
          sops
          ssh-to-age
          tldr
          tre-command

          # ── Dev ──
          bat
          bun
          fd
          fzf
          git
          jq
          jujutsu
          just
          nodejs
          pandoc
          python313
          uv
          yazi
        ]
        ++ flakePackages;
    };
}
