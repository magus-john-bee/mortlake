{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.gh = inputs.wrapper-modules.lib.wrapPackage (_: {
        inherit pkgs;
        package = pkgs.gh;
        env.GH_CONFIG_DIR = "/etc/gh";
      });
    };

  flake.nixosModules.gh =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # sops-nix: ${p.<key>} in a template resolves to the rendered secret
      # value at activation — secret values never enter the Nix store.
      p = config.sops.placeholder;

      # gh's stock credential helper only serves the ACTIVE account; this
      # routes any other username via `gh auth token --user`.
      credRouter = pkgs.writeShellScript "gh-cred-router" (builtins.readFile ./gh-cred-router.sh);
    in
    {
      # Consumed by git.nix: appended to git's credential.helper chain.
      options.gh.credRouter = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Credential helper routing git auth by username via gh auth token --user.";
      };

      config = {
        environment.etc."gh/config.yml".source = ./gh-config.yml;

        sops.secrets = {
          "uriel-gh-pat-for-jehoel".sopsFile = ./secrets.yaml;
          "magus-gh-pat-for-jehoel".sopsFile = ./secrets.yaml;
        };

        # Both identities on every host: magus-john-bee active for
        # interactive shells; uriel-mortlake served to Hermes sessions via
        # GH_TOKEN (hermes.nix). Git picks per-remote identities from the
        # username hints in remote URLs (gh-remote-hints.sh), not the
        # active account.
        sops.templates."gh-hosts.yml" = {
          content = ''
            github.com:
              users:
                magus-john-bee:
                  oauth_token: ${p."magus-gh-pat-for-jehoel"}
                uriel-mortlake:
                  oauth_token: ${p."uriel-gh-pat-for-jehoel"}
              oauth_token: ${p."magus-gh-pat-for-jehoel"}
              user: magus-john-bee
          '';
          path = "/etc/gh/hosts.yml";
          owner = "john";
          mode = "0600";
        };

        # No-op where the mortlake clone is absent.
        system.activationScripts.ghRemoteHints.text = builtins.readFile ./gh-remote-hints.sh;

        environment.systemPackages = [
          inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.gh
        ];

        gh.credRouter = credRouter;
      };
    };
}
