{ self, inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.ghostty = inputs.wrapper-modules.lib.wrapPackage (
        { config, ... }:
        {
          config = {
            inherit pkgs;
            package = pkgs.ghostty;

            flags."--config-file" = { sep = "="; data = config.constructFiles.configFile.path; };

            constructFiles.configFile = {
              content = builtins.readFile ./ghostty/config.ghostty;
              relPath = "ghostty/config";
            };
          };
        }
      );
    };

  flake.nixosModules.ghostty =
    { pkgs, ... }:
    let
      inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) ghostty;
    in
    {
      environment.systemPackages = [ ghostty ];
    };
}
