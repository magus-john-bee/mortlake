{
  self,
  inputs,
  lib,
  ...
}:
let
  # Shared wrapper definition — eliminates duplication between atuin (sync) and safe-atuin (local).
  # The only differences are auto_sync, sync_frequency, sync.records, and the login service.
  mkAtuinWrapper =
    sync:
    { pkgs }:
    inputs.wrapper-modules.lib.wrapPackage (
      { config, ... }:
      let
        fmt = pkgs.formats.toml { };
      in
      {
        options.settings = lib.mkOption {
          inherit (fmt) type;
          default = { };
        };

        config = {
          inherit pkgs;
          package = pkgs.atuin;

          settings = {
            auto_sync = sync;
            search_mode = "fuzzy";
            filter_mode = "global";
            style = "compact";
            keymap_mode = "vim-insert";
            theme.name = "nord";
            sync.records = sync;
          }
          // (lib.optionalAttrs sync { sync_frequency = "2m"; });

          env.ATUIN_CONFIG_DIR = dirOf config.constructFiles.configDir.path;

          constructFiles.configDir = {
            content = builtins.toJSON config.settings;
            relPath = "atuin/config.toml";
            builder = ''mkdir -p "$(dirname "$2")" && ${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
          };

          constructFiles.theme = {
            content = builtins.toJSON {
              colors = {
                AlertError = "#bf616a";
                AlertInfo = "#b48ead";
                AlertWarn = "#ebcb8b";
                Annotation = "#88c0d0";
                Base = "#8fbcbb";
                Guidance = "#81a1c1";
                Important = "#5e81ac";
                Title = "#eceff4";
              };
              theme = {
                name = "nord";
                parent = "default";
              };
            };
            relPath = "atuin/themes/nord.toml";
            builder = ''mkdir -p "$(dirname "$2")" && ${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
          };
        };
      }
    );
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.atuin = mkAtuinWrapper true { inherit pkgs; };
      packages.safe-atuin = mkAtuinWrapper false { inherit pkgs; };
    };

  # Synced atuin — needs sops secrets + login service
  flake.nixosModules.atuin =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) atuin;
    in
    {
      sops.secrets = {
        "atuin-username" = {
          owner = "john";
          sopsFile = ./supersecrets.yaml;
        };
        "atuin-password" = {
          owner = "john";
          sopsFile = ./supersecrets.yaml;
        };
        "atuin-key" = {
          owner = "john";
          sopsFile = ./supersecrets.yaml;
        };
      };

      environment.systemPackages = [ atuin ];

      programs.bash.blesh.enable = true;

      programs.bash.interactiveShellInit = ''
        eval "$(${lib.getExe atuin} init bash)"
      '';

      systemd.services.atuin-login = {
        description = "Atuin non-interactive login";
        after = [
          "sops-nix.service"
          "network-online.target"
        ];
        wants = [
          "sops-nix.service"
          "network-online.target"
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "john";
          ExecStart = toString (
            pkgs.writeShellScript "atuin-login" ''
              ${lib.getExe atuin} login \
                -u "$(cat ${config.sops.secrets.atuin-username.path})" \
                -p "$(cat ${config.sops.secrets.atuin-password.path})" \
                -k "$(cat ${config.sops.secrets.atuin-key.path})"
            ''
          );
          RemainAfterExit = true;
        };
        wantedBy = [ "multi-user.target" ];
      };
    };

  # Local-only atuin — no sync, no login service
  flake.nixosModules.safe-atuin =
    { pkgs, lib, ... }:
    let
      inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) safe-atuin;
    in
    {
      environment.systemPackages = [ safe-atuin ];

      programs.bash = {
        blesh.enable = true;
        interactiveShellInit = ''
          eval "$(${lib.getExe safe-atuin} init bash)"
        '';
      };
    };
}
