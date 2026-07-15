_: {
  # Ouroboros is now invoked via `uvx --from ouroboros-ai[mcp] ouroboros` —
  # no Nix package build needed. This module only deploys the config file
  # to ~/.ouroboros/config.yaml and creates the directory.

  flake.nixosModules.ouroboros =
    _:
    let
      ouroborosConfig = builtins.readFile ./ouroboros/config.yaml;
    in
    {
      systemd.tmpfiles.rules = [
        "d /home/john/.ouroboros 0700 john users - -"
      ];

      system.activationScripts.ouroboros-config = ''
        cp --remove-destination ${builtins.toFile "ouroboros-config.yaml" ouroborosConfig} /home/john/.ouroboros/config.yaml
        chown john:users /home/john/.ouroboros/config.yaml
      '';
    };
}
