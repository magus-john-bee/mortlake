# Transmission — torrent client with done script that copies completed
# torrents from an allowed tracker to the Syncthing share directory.
# The tracker pattern comes from sops (not hardcoded) so the repo can be public.
_:
{
  flake.nixosModules.transmission =
    { pkgs, config, ... }:
    let
      transmissionPort = 9091;
      transmissionPeerPort = 51413;
      syncthingStDir = "/var/lib/syncthing/st";

      # Tracker pattern rendered by sops — not hardcoded in the Nix store.
      trackerPatternFile = config.sops.templates."transmission-tracker-pattern".path;

      copyTorrentToSyncthing = pkgs.writeShellApplication {
        name = "copy-torrent-to-syncthing";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
        ];
        text = ''
          set -euo pipefail

          torrent_path="''${TR_TORRENT_DIR}/''${TR_TORRENT_NAME}"

          if [[ ! -e "$torrent_path" ]]; then
            echo "Transmission done script: path does not exist: $torrent_path" >&2
            exit 0
          fi

          # Only act on torrents from the allowed tracker.
          # Pattern comes from sops-rendered file (not in the Nix store).
          if [[ -z "''${TR_TORRENT_TRACKERS:-}" ]] || ! grep -Eiqf "${trackerPatternFile}" <<< "$TR_TORRENT_TRACKERS"; then
            echo "Transmission done script: not from allowed tracker, skipping" >&2
            exit 0
          fi

          mkdir -p "${syncthingStDir}"

          if [[ -f "$torrent_path" ]]; then
            cp -a "$torrent_path" "${syncthingStDir}/"
            echo "Transmission done script: copied $torrent_path to ${syncthingStDir}/"
          else
            dest="${syncthingStDir}/''${TR_TORRENT_NAME}"
            if [[ -e "$dest" ]]; then
              echo "Transmission done script: destination already exists, skipping: $dest" >&2
              exit 0
            fi
            cp -a "$torrent_path" "${syncthingStDir}/"
            echo "Transmission done script: copied $torrent_path to ${syncthingStDir}/"
          fi
        '';
      };
    in
    {
      # Tracker pattern — encrypted, not visible in Nix store or repo
      sops.secrets."torrent-tracker-pattern" = {
        owner = "john";
        sopsFile = ./supersecrets.yaml;
      };

      sops.templates."transmission-tracker-pattern" = {
        content = "${config.sops.placeholder.torrent-tracker-pattern}";
        owner = "john";
      };

      mortlake.restic = {
        paths = [ "/var/lib/transmission" ];
      };

      services.transmission = {
        enable = true;
        package = pkgs.transmission_4;
        openRPCPort = true;
        user = "john";
        settings = {
          peer-port = transmissionPeerPort;
          rpc-port = transmissionPort;
          rpc-authentication-required = false;
          rpc-bind-address = "0.0.0.0";
          rpc-whitelist-enabled = true;
          rpc-host-whitelist-enabled = false;
          rpc-whitelist = "127.0.0.1,192.168.*.*,10.*.*.*";
          watch-dir-enabled = false;
          script-torrent-done-enabled = true;
          script-torrent-done-filename = "${copyTorrentToSyncthing}/bin/copy-torrent-to-syncthing";
        };
      };

      systemd.services.transmission = {
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig.BindPaths = [ "${syncthingStDir}" ];
      };

      networking.firewall.allowedTCPPorts = [
        transmissionPort
        transmissionPeerPort
      ];
    };
}
