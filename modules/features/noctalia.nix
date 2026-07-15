{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.myNoctalia = inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
        inherit pkgs;
        settings =
          if builtins.pathExists ./noctalia.json then
            (builtins.fromJSON (builtins.readFile ./noctalia.json)).settings
          else
            { };
      };
    };
}
