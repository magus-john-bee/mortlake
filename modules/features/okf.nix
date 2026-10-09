# ── Upgrading ────────────────────────────────────────────────
# 1. Bump `version` below to the latest tag (e.g. "0.5.0").
# 2. Re-prefetch the source tarball (on jehoel):
#      nix-prefetch-url --unpack \
#        "https://github.com/okf-memory/okf-agent-memory/archive/refs/tags/v<VERSION>.tar.gz"
#    → update `sha256`.
# 3. Re-fetch vendorHash: set `vendorHash = lib.fakeHash;`, then on jehoel:
#      cd /tmp/okf-pkg && nix build .#okf 2>&1 | grep "got:"
#    → update `vendorHash` (go.mod requires change → hash changes).
# 4. Verify on jehoel: `nix build github:magus-john-bee/mortlake#okf` and
#    smoke `okf version` + `okf search <q> <knowledge-dir>`.
# 5. go.mod's `go` directive must stay <= nixpkgs' go.version.
{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages.okf = pkgs.buildGoModule rec {
        pname = "okf";
        version = "0.6.0";

        src = pkgs.fetchFromGitHub {
          owner = "okf-memory";
          repo = "okf-agent-memory";
          rev = "v${version}";
          sha256 = "0l9j2xp6ir3rsr6558k1v01s7c3hv66nacbbg3g6ick5szdng2la";
        };

        vendorHash = "sha256-NP0Lyu9UqpqdgIU/e46FHtJtdRHvEyTd3qT4H84pCHg=";

        subPackages = [ "cmd/okf" ];

        ldflags = [
          "-s"
          "-w"
          "-X main.Version=v${version}"
        ];

        meta = {
          description = "Git-native persistent memory for AI coding agents (OKF v0.2)";
          homepage = "https://github.com/okf-memory/okf-agent-memory";
          license = lib.licenses.mit;
          mainProgram = "okf";
        };
      };
    };
}
