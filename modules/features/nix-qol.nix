{ inputs, ... }:
{
  flake.nixosModules.nix-qol =
    { pkgs, config, ... }:
    {
      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];

          extra-substituters = [ "https://cache.otwell.dev" ];
          extra-trusted-public-keys = [
            "cache.otwell.dev:1uNVs/iKY7NnLUcSoS++Zl2+iWl9qw1VuC0Fa5Lkt4I="
          ];
        };

        registry = pkgs.lib.mapAttrs (_: value: { flake = value; }) inputs;

        nixPath = pkgs.lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
      };

      # nix-ld: critical for running pre-built binaries (MCP servers, Pi tools)
      programs.nix-ld = {
        enable = true;
        libraries = with pkgs; [
          stdenv.cc.cc.lib
          zlib
          opus
        ];
      };

      # envfs: provides /usr/bin/env
      services.envfs.enable = true;
    };
}
