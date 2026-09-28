# Packages okf — git-native persistent project memory for AI coding agents
# (Google OKF v0.2 bundles: knowledge/ dirs of markdown + YAML frontmatter,
# BM25 search, MCP server over stdio, validation, search-before-write).
# https://github.com/okf-memory/okf-agent-memory
#
# Context (2026-09): not in nixpkgs, not in numtide/llm-agents.nix, no
# upstream flake — this is our wrap. Vendored upstream later if it lands in
# llm-agents.nix (good fit; they'd take over version bumps).
#
# Not actually zero-dependency despite README claims: go.mod requires
# golang.org/x/crypto (direct) + golang.org/x/sys (indirect) → real vendorHash.
#
# ── Pinning ──────────────────────────────────────────────────
# Pinned to stable release tags (default branch is `develop`; single main
# contributor — bus-factor-one upstream, review bumps before upgrading).
# Check available versions: https://github.com/okf-memory/okf-agent-memory/releases
#
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
        version = "0.4.2";

        src = pkgs.fetchFromGitHub {
          owner = "okf-memory";
          repo = "okf-agent-memory";
          rev = "v${version}";
          sha256 = "0l2z74pkjhhrczgvgjr56vnraj0sni1dis7m4n0p7b72nhb6mn4s";
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
