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
_: {
  flake.nixosModules.email =
    { pkgs, ... }:
    {
      services.protonmail-bridge = {
        enable = true;
        # Credential store for headless Bridge (see bootstrap step 1).
        # pass holds ONE thing: Bridge's vault key — a machine/infra
        # secret that must answer non-interactively at boot (greetd
        # auto-login; nobody types a password). NOT a password manager
        # competing with keepass: user passwords live in kp-vault.
        # KeePassXC-as-Secret-Service was considered and rejected — its
        # boot-time unlock dependency would kill headless email reads.
        # gnupg goes in systemPackages, not just the service path: pass
        # shells out to gpg, and the user needs `pass init` in their own
        # shell during bootstrap.
        path = [ pkgs.pass ];
      };

      environment = {
        # Wrapper instead of plain pkgs.himalaya + HIMALAYA_CONFIG env var:
        # himalaya v2.0.0 DROPPED HIMALAYA_CONFIG (upstream restored it only
        # after 2.0.0), so the env var silently found no config and bare
        # `himalaya` fell into its first-run wizard. The wrapper pins
        # --config explicitly and is version-proof.
        systemPackages = [
          (pkgs.writeShellScriptBin "himalaya" ''
            exec ${pkgs.himalaya}/bin/himalaya --config /etc/himalaya/config.toml "$@"
          '')
          pkgs.pass
          pkgs.gnupg
        ];
        # Real TOML file, referenced not inlined (house format rule).
        etc."himalaya/config.toml".source = ./himalaya/config.toml;
        # Bridge's self-signed loopback cert, pinned in-repo (public
        # material) — config.toml points here instead of chasing
        # Bridge's lazily-exported state-dir copy.
        etc."himalaya/bridge-cert.pem".source = ./himalaya/bridge-cert.pem;
      };

      # Bridge mailbox password (Bridge-generated, NOT the Proton
      # account password). Placeholder in supersecrets.yaml until the
      # bootstrap runs — himalaya auth just fails until rotated.
      sops.secrets."proton-bridge-password" = {
        owner = "john";
        sopsFile = ./supersecrets.yaml;
      };

      # Persistence: the whole protonmail namespace (Bridge keeps config
      # in ~/.config/protonmail/bridge-v3, data in ~/.local/share/
      # protonmail/bridge-v3 — incl. the TLS CA the himalaya config
      # pins), plus the pass/gpg material that unlocks Bridge at boot.
      preservation.preserveAt."/persistent".users.john.directories = [
        ".config/protonmail"
        ".local/share/protonmail"
        ".password-store"
        ".gnupg"
      ];
    };
}
