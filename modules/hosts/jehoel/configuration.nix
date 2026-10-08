{ self, ... }:
{
  flake.nixosModules.jehoelConfiguration =
    { pkgs, lib, ... }:
    {
      imports = [
        self.nixosModules.jehoelHardware
        self.nixosModules.jehoelDisko
        self.nixosModules.preservation-common
        self.nixosModules.clock
        self.nixosModules.network
        self.nixosModules.packages
        self.nixosModules.john
        self.nixosModules.nix-qol
        self.nixosModules.sops
        self.nixosModules.gh
        self.nixosModules.git
        self.nixosModules.zsh
        self.nixosModules.atuin
        self.nixosModules.intellishell
        self.nixosModules.helix
        self.nixosModules.zellij
        self.nixosModules.dev-dirs
        self.nixosModules.restic
        self.nixosModules.nerd-fonts

        # Server role
        self.nixosModules.nginx
        self.nixosModules.jellyfin
        self.nixosModules.jellyfin-public
        self.nixosModules.transmission
        self.nixosModules.mealie
        self.nixosModules.syncthing-lead
        self.nixosModules.dd-client
        self.nixosModules.nix-serve

        # Desktop role
        self.nixosModules.niri
        self.nixosModules.greetd
        self.nixosModules.ghostty
        self.nixosModules.chromium
        self.nixosModules.nyxt
        self.nixosModules.keepass
        self.nixosModules.email
        self.nixosModules.sound
        self.nixosModules.printing

        # AI tooling
        self.nixosModules.pi
        self.nixosModules.herdr
        self.nixosModules.taskdog
        self.nixosModules.silverbullet

        # Uriel cutover staging (docs/uriel-decommission-tasker-heartbeat.md):
        # hermes module imported now so secrets/env/packages render early,
        # but the service stays OFF — both instances share one Discord bot
        # token and two live gateways flap. eBay deletion endpoint ditto:
        # its ACME vhost can't issue while deletion.otwell.dev still
        # resolves to uriel.
        self.nixosModules.hermes
        self.nixosModules.ebayDeletion
      ];

      services = {

        # Taskdog: server local; public URL activates at cutover
        # (taskdog.otwell.dev nginx vhost is commented out in taskdog.nix).
        # SilverBullet likewise runs loopback-only (sb.otwell.dev vhost
        # commented in silverbullet.nix) — ports 3000/8000 stay
        # loopback-only until cutover.
        taskdog = {
          client.enable = true;
          server.enable = true;
        };

        # CUTOVER(uriel→jehoel): flip both at the migration sitting.
        # hermes-agent: only after hermes-state-sync lands /var/lib/hermes
        # AND uriel's hermes-agent is stopped (shared Discord token, see
        # import comment). ebayDeletion: only once DNS resolves here, else
        # the ACME HTTP-01 challenge hits uriel's nginx and issuance loops.
        # The sb/taskdog vhost uncommenting + dd-client domain additions
        # belong to the same cutover commit.
        hermes-agent.enable = true;
        ebayDeletion.enable = true;
      };

      networking = {
        hostName = "jehoel";
        useDHCP = lib.mkDefault true;
        networkmanager.enable = true;
      };

      networking.firewall.allowedTCPPorts = [
        22
        80
        443
      ];

      environment.systemPackages = with pkgs; [
        ffmpeg
        yt-dlp
        magic-wormhole
      ];

      # TV output toggles for the phantom HDMI display (fiber HDMI holds HPD
      # forever; niri keeps it off at startup by EDID — see niri.nix). The
      # niri IPC socket name changes each session, so resolve it at runtime.
      # Audio is unaffected either way (HDMI sink is independent of the niri
      # output state — verified live with playback during output-off).
      # CAVEAT: these hardcode the connector name — `niri msg` cannot match
      # by EDID. If the bar ever moves to a different connector, update the
      # name here (check `niri msg outputs`); the startup default in niri.nix
      # is EDID-matched and immune.
      environment.shellAliases =
        let
          niriMsg = "niri msg";
          withSocket = ''NIRI_SOCKET="$(ls -t /run/user/$(id -u)/niri.*.sock 2>/dev/null | head -1)" XDG_RUNTIME_DIR=/run/user/$(id -u) ${niriMsg}'';
        in
        {
          tv-is-on = "${withSocket} output HDMI-A-1 on";
          tv-is-off = "${withSocket} output HDMI-A-1 off";
        };

      preservation.preserveAt."/persistent" = {
        directories = [
          "/var/lib/bluetooth"
          "/var/lib/acme"
          "/var/lib/nginx"
          # Hermes state (sessions, cron jobs, skills, memory) — pre-staged
          # for the cutover; hermes-state-sync fills it at migration time.
          "/var/lib/hermes"
          "/etc/NetworkManager/system-connections"
        ];

        users.john.directories = [ "data" ];
      };

      # No post-build-hook here: this host RUNS the cache (nix-serve reads
      # straight from the local store), so pushing to itself is a no-op that
      # just burns an SSH round-trip (and fails host-key verification) per
      # build. Clients (raphael, thoth) push here; jehoel only serves.

      system.stateVersion = "25.11";
    };
}
