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
    { config, pkgs, ... }:
    let
      p = config.sops.placeholder;
    in
    {
      # Static config — always present via NixOS /etc management
      environment.etc."gh/config.yml".text = ''
        version: 1
        git_protocol: https
        editor:
        prompt: enabled
        prefer_editor_prompt: disabled
        pager:
        aliases:
            co: pr checkout
        http_unix_socket:
        browser:
        color_labels: disabled
        accessible_colors: disabled
        accessible_prompter: disabled
        spinner: enabled
      '';

      # Auth token — rendered by sops-nix alongside the static config
      sops.templates."gh-hosts.yml" = {
        content = ''
          github.com:
            users:
              jbotwell:
                oauth_token: ${p.gh-oauth-token}
            oauth_token: ${p.gh-oauth-token}
            user: jbotwell
        '';
        path = "/etc/gh/hosts.yml";
        owner = "john";
        mode = "0600";
      };

      environment.systemPackages = [
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.gh
      ];
    };
}
