# IntelliShell — searchable shell command bookmarks with zsh hotkeys
# (ctrl+space search / ctrl+b bookmark / ctrl+l variables / ctrl+x fix,
# wired in zsh/zshrc.zsh) and cross-host sync via a GitHub gist.
#
# Sync model: daily pull-then-push union. Each host imports the gist's
# commands (merge, no duplicates — verified idempotent across repeated
# imports) then exports the union back. tldr-derived commands are not
# exported, so the gist stays user-bookmarks-only.
#
# The sync MUST run as john with HOME=/home/john: outside that env the
# binary reads a different storage db and no gist config, and export
# then PATCHes garbage (observed: 422s; an empty-content PATCH once
# deleted commands.sh from the gist). Never run it as root/hermes.
{
  flake.nixosModules.intellishell =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.intellishell;
    in
    {
      options.services.intellishell = {
        enable = lib.mkEnableOption "IntelliShell gist sync";
        gistId = lib.mkOption {
          type = lib.types.str;
          default = "4c83e47d1df90765651d45f73e87132c";
          description = "GitHub gist id used as the sync hub";
        };
        syncInterval = lib.mkOption {
          type = lib.types.str;
          default = "daily";
          description = "systemd OnCalendar expression for the sync timer";
        };
      };

      config = lib.mkIf cfg.enable {
        environment = {
          etc."intellishell/config.toml".text = ''
            check_updates = false
            inline = true

            [gist]
            id = "${cfg.gistId}"
            token = ""

            [tui]
            keyboard_enhancement = true

            [search]
            mode = "auto"
          '';

          systemPackages = [ pkgs.intelli-shell ];
        };

        # tmpfs root: ~/.config/intelli-shell (and its symlink to the
        # /etc config) only gets created by zshrc at first interactive
        # shell — too late for non-interactive runs. Recreate at boot.
        systemd = {
          services.intellishell-config-link = {
            description = "Symlink ~/.config/intelli-shell/config.toml to /etc";
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              ${pkgs.coreutils}/bin/mkdir -p /home/john/.config/intelli-shell
              ${pkgs.coreutils}/bin/ln -sfn /etc/intellishell/config.toml /home/john/.config/intelli-shell/config.toml
            '';
          };

          services.intellishell-sync = {
            description = "Sync intelli-shell bookmarks with GitHub gist";
            after = [
              "network-online.target"
              "intellishell-config-link.service"
            ];
            wants = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              User = "john";
              Group = "users";
            };
            environment.HOME = "/home/john";
            script = ''
              export GIST_TOKEN="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."gh-gist-token".path})"
              ${pkgs.intelli-shell}/bin/intelli-shell import gist || true
              ${pkgs.intelli-shell}/bin/intelli-shell export gist
            '';
          };

          timers.intellishell-sync = {
            description = "Daily intelli-shell gist sync";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = cfg.syncInterval;
              Persistent = true;
              RandomizedDelaySec = "10m";
            };
          };
        };

        preservation.preserveAt."/persistent" = {
          users.john.directories = [ ".local/share/intelli-shell" ];
        };
      };
    };
}
