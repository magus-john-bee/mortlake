# Nix binary cache server using nix-serve behind nginx with HTTPS.
#
# Server-side only — import on the cache host (mab).
# Clients (thoth etc.) configure substituter + post-build hook separately.
#
# The signing key pair must be generated before building. Run once:
#
#   nix-store --generate-binary-cache-key cache.otwell.dev \
#     /tmp/cache-private-key.pem /tmp/cache-public-key.pem
#
# Then add the private key to nix-serve-key.yaml:
#
#   echo "nix-serve-private-key: $(cat /tmp/cache-private-key.pem)" | \
#     sops --input-type yaml --output-type yaml \
#     --filename-override modules/features/nix-serve-key.yaml \
#     -e /dev/stdin > modules/features/nix-serve-key.yaml
#
# Alternatives if nix-serve proves insufficient:
#   - nix-serve-ng: drop-in Haskell replacement, faster
#   - Attic: feature-rich (dedup, GC, token auth, multi-tenant, S3-backed)
#   - Harmonia: Rust-based, fast, simple
#
let
  cacheDomain = "cache.otwell.dev";
in
{
  flake.nixosModules.nix-serve =
    { config, ... }:
    {
      services.nix-serve = {
        enable = true;
        secretKeyFile = config.sops.secrets."nix-serve-private-key".path;
      };

      # Private signing key — rendered from sops at activation time.
      # Stored in nix-serve-key.yaml (encrypted for thoth, mab, puck).
      sops.secrets."nix-serve-private-key" = {
        sopsFile = ./nix-serve-key.yaml;
      };

      # HTTPS reverse proxy via nginx + Let's Encrypt ACME.
      services.nginx.virtualHosts."${cacheDomain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass =
          "http://${config.services.nix-serve.bindAddress}:${toString config.services.nix-serve.port}";
      };

      # Allow `nix copy --to ssh://john@mab` from client machines.
      # Required for the post-build hook to push paths to this cache.
      #
      # On client machines, add a post-build hook like:
      #   nix.settings.post-build-hook = pkgs.writeShellScript "push-to-mab-cache" ''
      #     ${pkgs.nix}/bin/nix copy --to ssh://john@mab $OUT_PATHS
      #   '';
      nix.settings.trusted-users = [ "john" ];
    };
}
