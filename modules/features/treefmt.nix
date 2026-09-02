{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";

      programs = {
        nixfmt.enable = true;
        nickel.enable = true;
        shfmt.enable = true;
      };
    };
  };
}
