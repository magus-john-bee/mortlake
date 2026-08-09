{ self, inputs, ... }:
let
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    config = {
      allowUnfree = true;
    };
  };
in
{
  flake.nixosConfigurations.humbled-jehoel = inputs.nixpkgs.lib.nixosSystem {
    inherit pkgs;
    modules = [ self.nixosModules.jehoelBootstrapConfiguration ];
  };
}
