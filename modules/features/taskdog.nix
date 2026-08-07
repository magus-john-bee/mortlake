# Taskdog — terminal task manager with CLI/TUI + REST API server.
# uv2nix-built venv from github:Kohei-Wada/taskdog.
# Server runs as a systemd user service (per-user SQLite at ~/.local/share/taskdog).
{ self, inputs, ... }:
{
  flake.nixosModules.taskdog =
    { pkgs, lib, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;
      taskdog = inputs.taskdog.packages.${system}.default;
    in
    {
      environment.systemPackages = [ taskdog ];

      # systemd user service — john (or any user) enables with:
      #   systemctl --user enable --now taskdog-server
      systemd.user.services.taskdog-server = {
        description = "Taskdog REST API server";
        after = [ "network.target" ];
        wantedBy = [ "default.target" ];
        serviceConfig = {
          ExecStart = "${taskdog}/bin/taskdog-server";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      # Persist taskdog's SQLite database + config across rebuilds.
      preservation.preserveAt."/persistent".users.john.directories = [
        ".local/share/taskdog"
      ];
    };
}
