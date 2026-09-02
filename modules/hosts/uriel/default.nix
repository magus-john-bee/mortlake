{ self, inputs, ... }:
let
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
{
  flake.nixosConfigurations.uriel = inputs.nixpkgs.lib.nixosSystem {
    inherit pkgs;
    modules = [ self.nixosModules.urielConfiguration ];
  };
}
