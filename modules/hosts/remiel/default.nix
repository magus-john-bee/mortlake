# Ramiel — flake output for the GrapheneOS Pixel Tablet.
#
# Same nix-on-droid pattern as raziel/haniel: default.nix produces the flake
# output; configuration.nix provides the module as a flake attribute.
{ self, inputs, ... }:
{
  flake.nixOnDroidConfigurations.remiel =
    inputs.nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = import inputs.nixpkgs { system = "aarch64-linux"; };
      modules = [ self.nixOnDroidModules.remielConfiguration ];
    };
}
