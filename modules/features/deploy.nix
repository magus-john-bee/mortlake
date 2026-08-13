# deploy.nix — deploy-rs integration for NixOS hosts
#
# deploy-rs: a simple multi-profile Nix-flake deploy tool with magic rollback.
#
# Usage:
#   nix run github:serokell/deploy-rs .#jehoel   # Deploy a single host
#   nix run github:serokell/deploy-rs .            # Deploy all hosts
#
# Magic rollback activates a safety timer on the target: after activation it
# reconnects to confirm SSH is still available. If the connection fails (e.g.
# you broke networking/sshd/firewall), the target auto-rolls back to the
# previous generation — no console access required.
#
# To skip magic rollback for a particular deploy: deploy .#host -- --no-magic-rollback
#
# Add new machines by adding their node entry here and listing it in profilesOrder.
{ self, inputs, ... }:
let
  inherit (inputs) deploy-rs;
  deployLib = deploy-rs.lib.x86_64-linux;
in
{
  flake.deploy = {
    # Global defaults — can be overridden per-node or per-profile
    # autoRollback = true;   # Roll back if activation fails
    # magicRollback = true;  # Roll back if SSH is unreachable after activation

    nodes = {
      jehoel = {
        hostname = "ssh.otwell.dev";
        sshUser = "john";
        user = "root";

        profiles.system = {
          user = "root";
          path = deployLib.activate.nixos self.nixosConfigurations.jehoel;
        };
      };

      uriel = {
        hostname = "uriel";
        # sshUser must be a non-root user — PermitRootLogin is "no" on all
        # hosts (network.nix). john has NOPASSWD:ALL, so deploy-rs uses
        # sudo to switch as root.
        sshUser = "john";
        user = "root";

        profiles.system = {
          user = "root";
          path = deployLib.activate.nixos self.nixosConfigurations.uriel;
        };
      };

      raphael = {
        hostname = "raphael";
        sshUser = "john";
        user = "root";

        profiles.system = {
          user = "root";
          path = deployLib.activate.nixos self.nixosConfigurations.raphael;
        };
      };
    };
  };

  # Validates the deploy config structure — runs via `nix flake check`
  perSystem = { system, ... }: {
    checks = deploy-rs.lib.${system}.deployChecks self.deploy;
  };
}