{ inputs, ... }:
{
  imports = [ inputs.git-hooks-nix.flakeModule ];

  perSystem =
    { config, pkgs, ... }:
    {
      pre-commit.settings.hooks = {
        nixfmt.enable = true;
        statix.enable = true;
        deadnix.enable = true;
      };

      devShells.default = pkgs.mkShell {
        inherit (config.pre-commit) shellHook;

        packages =
          with pkgs;
          [
            nil
            nixd
            nix-output-monitor
            bash-language-server
            shellcheck
          ]
          ++ config.pre-commit.settings.enabledPackages;
      };
    };
}
