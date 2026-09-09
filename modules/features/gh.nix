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
      # jehoel builds/pulls from private uriel-mortlake repos and pushes to the
      # public magus-john-bee repo — hosts.yml carries both identities (PATs in
      # supersecrets.yaml), magus-john-bee active (the human at the terminal).
      # Git per-remote auth is disambiguated by username hints baked into the
      # clone's remote URLs (stamped below), not by the active account.
      # Other hosts keep the read-only jbotwell identity (secrets.yaml).
      isJehoel = config.networking.hostName == "jehoel";
      # gh's stock git-credential helper only serves the ACTIVE account; for
      # any other username it silently returns nothing and git falls back to
      # a password prompt. This wrapper routes by requested username using
      # `gh auth token --user` (works for non-active accounts).
      credRouter = pkgs.writeShellScript "gh-cred-router" ''
        op="''${1:-}"
        [ "$op" = "get" ] || exit 0
        user=""
        while IFS= read -r line && [ -n "$line" ]; do
          case "$line" in username=*) user="''${line#username=}" ;; esac
        done
        # No username or the active account: let the stock gh helper
        # (first in programs.git config order) answer.
        [ -z "$user" ] && exit 0
        [ "$user" = "magus-john-bee" ] && exit 0
        token="$(gh auth token --user "$user" 2>/dev/null)" || exit 0
        if [ -n "$token" ]; then
          printf 'protocol=https\nhost=github.com\nusername=%s\npassword=%s\n' "$user" "$token"
        fi
        exit 0
      '';
    in
    {
      # Consumed by the git module: when non-null, appended to git's
      # credential.helper chain to serve NON-active gh accounts (jehoel's
      # dual identity). gh's stock helper only ever answers the active one.
      options.gh.credRouter = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Credential helper that routes git auth by username via gh auth token --user.";
      };

      config = lib.mkMerge [
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
            "magus-gh-pat-for-jehoel" = {
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
                      magus-john-bee:
                        oauth_token: ${p."magus-gh-pat-for-jehoel"}
                      uriel-mortlake:
                        oauth_token: ${p."uriel-gh-pat-for-jehoel"}
                    oauth_token: ${p."magus-gh-pat-for-jehoel"}
                    user: magus-john-bee
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

          # Idempotently bake per-remote auth hints into jehoel's mortlake clone.
          # gh's git-credential helper keys off the username in the remote URL, so
          # origin (staging) always resolves the uriel-mortlake token and public
          # always resolves magus-john-bee — regardless of the active account.
          system.activationScripts.ghRemoteHints = lib.mkIf isJehoel ''
            repo=/home/john/src/mortlake
            if [ -d "$repo/.git" ] && command -v git >/dev/null 2>&1; then
              origin=$(git -C "$repo" remote get-url origin 2>/dev/null || printf "")
              case "$origin" in
                https://uriel-mortlake@github.com/*) : ;;
                *) git -C "$repo" remote set-url origin https://uriel-mortlake@github.com/uriel-mortlake/mortlake.git 2>/dev/null || true ;;
              esac
              public=$(git -C "$repo" remote get-url public 2>/dev/null || printf "")
              case "$public" in
                https://magus-john-bee@github.com/*) : ;;
                *) git -C "$repo" remote set-url public https://magus-john-bee@github.com/magus-john-bee/mortlake.git 2>/dev/null || true ;;
              esac
            fi
          '';

          environment.systemPackages = [
            inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.gh
          ];
        }

        (lib.mkIf isJehoel { gh.credRouter = credRouter; })
      ];
    };
}
