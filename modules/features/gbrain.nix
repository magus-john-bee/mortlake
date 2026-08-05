# GBrain — semantic memory + synthesis + auto-wiring knowledge graph.
# The only tool that does gap analysis (tells you what's missing).
# PGLite backend for local use (no Docker, 2-second init).
# Install: bun install -g github:garrytan/gbrain
#
# CLI is first-class — Pi calls gbrain as shell commands:
#   gbrain init --pglite
#   gbrain import ~/vault/
#   gbrain query "what themes show up across my notes?"
#   gbrain think "synthesize what I know about X"
#
# TODO: Evaluate running `gbrain serve --http` on uriel as a shared
# brain for other machines (raphael, jehoel) to connect to in thin-client
# mode, avoiding per-machine PGLite copies.
{ ... }:
{
  flake.nixosModules.gbrain =
    { pkgs, ... }:
    {
      # gbrain needs bun for install, then runs as a standalone CLI
      environment.systemPackages = [ pkgs.bun ];

      # gbrain state: PGLite database, config, imported pages
      preservation.preserveAt."/persistent".users.john.directories = [
        ".gbrain"
      ];
    };
}
