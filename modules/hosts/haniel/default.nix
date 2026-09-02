# Haniel — flake output for the stock Pixel.
#
# Follows the same two-file pattern as the NixOS hosts (jehoel, raphael,
# uriel): default.nix produces the flake output; configuration.nix
# provides the module as a flake attribute so import-tree can safely
# evaluate both files as flake-parts modules.
{ self, inputs, ... }:
{
  flake.nixOnDroidConfigurations.haniel = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    pkgs = import inputs.nixpkgs { system = "aarch64-linux"; };
    modules = [ self.nixOnDroidModules.hanielConfiguration ];
  };
}
