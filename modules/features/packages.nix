{ pkgs, ... }:
{
  flake.nixosModules.packages = {
    environment.systemPackages = with pkgs; [
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
      tre-command

      # ── Dev ──
      bat
      bun
      fd
      fzf
      git
      jujutsu
      just
      nodejs
      pandoc
      python313
      uv
    ];
  };
}
