# Packages lightpanda browser for AI agents and automation.
# Pre-built binaries from GitHub releases — the upstream flake.nix
# only provides a devShell (PR #1976 to add packages.default was rejected).
# Binary deps: glibc only (libc.so.6, libm.so.6).
#
# ── Pinning ──────────────────────────────────────────────────
# We pin to stable releases (not nightly) for reproducibility.
# Check available versions: https://github.com/lightpanda-io/browser/releases
# Nightlies exist but are unreproducible — only use for debugging.
#
# ── Upgrading ────────────────────────────────────────────────
# 1. Bump `version` below to the latest stable tag (e.g. "0.3.5").
# 2. Re-prefetch both arches:
#      nix-prefetch-url --type sha256 \
#        "https://github.com/lightpanda-io/browser/releases/download/<VERSION>/lightpanda-x86_64-linux"
#      nix-prefetch-url --type sha256 \
#        "https://github.com/lightpanda-io/browser/releases/download/<VERSION>/lightpanda-aarch64-linux"
# 3. Convert to SRI format:
#      nix hash to-sri --type sha256 <hash>
# 4. Update both `hash` fields below.
# 5. Verify: `nix build .#lightpanda`
{
  perSystem =
    { pkgs, ... }:
    let
      version = "0.3.7";

      srcs = {
        x86_64-linux = pkgs.fetchurl {
          url = "https://github.com/lightpanda-io/browser/releases/download/${version}/lightpanda-x86_64-linux";
          hash = "sha256-iVM5sCIFFxoYHd50OuAGi7RWSIQHb+rISCusqcISqlo=";
        };
        aarch64-linux = pkgs.fetchurl {
          url = "https://github.com/lightpanda-io/browser/releases/download/${version}/lightpanda-aarch64-linux";
          hash = "sha256-TA7LKLT8+21bzoLshuFfxs3onOoWjPOEBJTw7iZ1WFI=";
        };
      };

      src =
        srcs.${pkgs.stdenv.hostPlatform.system} or (throw "lightpanda: unsupported system ${pkgs.stdenv.hostPlatform.system}");
    in
    {
      packages.lightpanda = pkgs.stdenv.mkDerivation {
        inherit version src;

        pname = "lightpanda";
        system = pkgs.stdenv.hostPlatform.system;

        nativeBuildInputs = [
          pkgs.autoPatchelfHook
          pkgs.makeWrapper
        ];

        buildInputs = [
          pkgs.stdenv.cc.cc.lib
        ];

        sourceRoot = ".";

        dontUnpack = true;

        installPhase = ''
          runHook preInstall

          install -Dm755 $src $out/bin/lightpanda

          runHook postInstall
        '';

        # The binary reports telemetry by default; disable at the package
        # level so agents don't accidentally phone home.
        postInstall = ''
          wrapProgram $out/bin/lightpanda \
            --set-default LIGHTPANDA_DISABLE_TELEMETRY true
        '';

        meta = {
          description = "Headless browser built from scratch for AI agents and automation";
          homepage = "https://github.com/lightpanda-io/browser";
          license = pkgs.lib.licenses.agpl3Only;
          mainProgram = "lightpanda";
          platforms = [
            "x86_64-linux"
            "aarch64-linux"
          ];
          sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
        };
      };
    };
}
