# Email — Proton Bridge + himalaya (jehoel only).
#
# Topology: Bridge (systemd user service, starts with the graphical
# session — greetd auto-login on jehoel) exposes IMAP on 127.0.0.1:1143
# with its own TLS CA. Himalaya reads through it; the account config
# (./himalaya/config.toml) has NO send backend — sending is impossible
# by construction. Drafts APPEND to the Drafts folder and sync to all
# Proton apps; the user sends. That is the enforced boundary:
# draft-yes, send-no. Deletes are move-to-Trash (recoverable);
# permadelete requires deleting from Trash itself — deliberate.
#
# One-time bootstrap (as john, on jehoel, before this is useful):
#   1. pass init <gpg-id>        # Bridge stores creds in a keyring;
#      `pass` is the headless one (needs a gpg key: gpg --full-generate-key
#      if none exists). If Bridge instead finds a dbus secret service,
#      gnome-keyring works too — verify at first deploy.
#   2. protonmail-bridge --cli   # log in; note the MAILBOX password it
#      shows (not the Proton account password)
#   3. sops --set '["proton-bridge-password"] "<mailbox password>"' \
#        modules/features/supersecrets.yaml   (placeholder until then)
#   4. rebuild; verify: himalaya envelope list
_:
{
  flake.nixosModules.email =
    { pkgs, ... }:
    {
      services.protonmail-bridge = {
        enable = true;
        # Credential store for headless Bridge (see bootstrap step 1).
        path = [ pkgs.pass ];
      };

      environment = {
        systemPackages = [ pkgs.himalaya ];
        # Real TOML file, referenced not inlined (house format rule).
        etc."himalaya/config.toml".source = ./himalaya/config.toml;
      };

      # Config symlink via tmpfiles L+ (house pattern — nyxt, intelli-shell).
      systemd.tmpfiles.rules = [
        "d /home/john/.config/himalaya 0755 john users - -"
        "L+ /home/john/.config/himalaya/config.toml - - - - /etc/himalaya/config.toml"
      ];

      # Bridge mailbox password (Bridge-generated, NOT the Proton
      # account password). Placeholder in supersecrets.yaml until the
      # bootstrap runs — himalaya auth just fails until rotated.
      sops.secrets."proton-bridge-password" = {
        owner = "john";
        sopsFile = ./supersecrets.yaml;
      };

      # Persistence: Bridge state (account session + its TLS CA cert,
      # which the himalaya config pins) and the pass/gpg material that
      # unlocks Bridge at boot.
      preservation.preserveAt."/persistent".users.john.directories = [
        ".local/share/protonmail/bridge"
        ".password-store"
        ".gnupg"
      ];
    };
}
