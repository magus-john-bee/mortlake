{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    wrapper-modules = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    preservation = {
      url = "github:nix-community/preservation";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # package repos
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    taskdog = {
      url = "github:Kohei-Wada/taskdog";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      inputs.import-tree ./modules
      // {
        # Utility for provisioning: print the age public key for this machine's
        # SSH host key. Works on any machine with nix — no mortlake build needed.
        #   nix run github:magus-john-bee/mortlake#get-age-key
        perSystem = { pkgs, ... }: {
          packages.get-age-key = pkgs.writeShellScriptBin "get-age-key" ''
            echo "Reading SSH host key from /persistent or /etc..." >&2
            for path in \
              /persistent/etc/ssh/ssh_host_ed25519_key.pub \
              /etc/ssh/ssh_host_ed25519_key.pub
            do
              if [ -f "$path" ]; then
                echo "Found: $path" >&2
                ${pkgs.ssh-to-age} < "$path"
                exit 0
              fi
            done
            echo "No SSH ed25519 host key found." >&2
            exit 1
          '';
        };
      }
    );
}
