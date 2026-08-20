{ inputs, ... }:
{
  flake.nixosModules.nix-qol =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];

          # Own binary cache — added everywhere except the cache host itself
          # (services.nix-serve.enable). The cache host's store already backs
          # the cache, so querying itself is pure overhead and couples its
          # nix to local nginx/ACME health.
          extra-substituters = lib.optionals (!config.services.nix-serve.enable) [
            "https://cache.otwell.dev"
          ];
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
