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
      p = config.sops.placeholder;
      # jehoel builds/pulls from private uriel-mortlake repos — it authenticates
      # as uriel-mortlake (privileged classic PAT, supersecrets.yaml). Other
      # hosts keep the read-only jbotwell identity (secrets.yaml).
      isJehoel = config.networking.hostName == "jehoel";
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

      sops.secrets = lib.mkIf isJehoel {
        "uriel-gh-pat-for-jehoel" = {
          sopsFile = ./supersecrets.yaml;
        };
      };

      # Auth token — rendered by sops-nix alongside the static config
      sops.templates."gh-hosts.yml" = {
        content =
          if isJehoel then
            ''
              github.com:
                users:
                  uriel-mortlake:
                    oauth_token: ${p."uriel-gh-pat-for-jehoel"}
                oauth_token: ${p."uriel-gh-pat-for-jehoel"}
                user: uriel-mortlake
            ''
          else
            ''
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
