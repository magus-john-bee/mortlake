# Chromium — ungoogled-chromium with KeePassXC integration.
#
# ── Config vs state ──────────────────────────────────────────
# ~/.config/chromium is 99% STATE (Cookies, Login Data, Bookmarks,
# History, Extension State, Local Storage, session restore) — persisted
# via the preservation entry below and never managed. Inside it,
# Default/Preferences and Local State look like config but are
# machine-written (Chromium rewrites them every launch with counters,
# timestamps, engagement caches); managing those declaratively is a fake
# — the interactive settings surface here is effectively empty, and
# anything worth owning belongs in POLICY:
#
#   managed    /etc/chromium/policies/managed/    = programs.chromium
#             .extraOpts — user CANNOT override; shows "managed by your
#             organization". Right for extensions + password-manager-off.
#   recommended /etc/chromium/policies/recommended/ = user-changeable
#             defaults (e.g. RestoreOnStartup). No nixpkgs option; add
#             via environment.etc."chromium/policies/recommended/..."
#             if ever needed — real JSON file, referenced not inlined.
#
# ── Extensions ───────────────────────────────────────────────
# programs.chromium.extensions becomes the ExtensionInstallForcelist
# policy. The IDs are NOT hashes of content and NOT version pins:
#
#   - An ID is the extension's stable IDENTITY: the first 128 bits of
#     SHA-256(public key of the extension's keypair), rendered base-16
#     with a-p in place of 0-f. It never changes across releases.
#   - Find one via chrome://extensions (Developer mode toggle) or the
#     32-letter string in the Web Store detail URL.
#
# Version-locking / upgrades:
#   - Force-installed extensions are NOT version-locked. Chromium
#     checks the Web Store for updates at startup and every few hours
#     and self-updates — "upgrading" requires no action here, ever.
#   - Adding an ID force-installs it silently on next launch; REMOVING
#     an ID auto-UNINSTALLS it (policy supersedes user installs).
#   - The only failure mode to watch: an extension abandoned/removed
#     from the store stops updating (chrome://extensions shows it).
#     Pinning a specific version would require ExtensionSettings with
#     pinned versions (Admin-console semantics) — deliberately not
#     wired up; if needed, switch to a managed-policy JSON with
#     installation_mode=force_installed + override_update_url.
#
# ── Password store ───────────────────────────────────────────
# --password-store=basic: no gnome-keyring dependency. Desktop hosts
# are tmpfs-root with greetd auto-login (no password ever typed), so
# the keyring can neither persist (~/.local/share/keyrings is wiped)
# nor auto-unlock via PAM — chromium prompted for a new keyring
# password every launch and cookies/logins died each boot. KeePassXC
# owns logins (PasswordManagerEnabled=false below), so the keyring
# guarded nothing of value; and with an unencrypted /persistent the
# basic store is no weaker than the rest of the profile on disk.
_: {
  flake.nixosModules.chromium =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        (ungoogled-chromium.override { commandLineArgs = "--password-store=basic"; })
      ];

      # Persist browser *state* only (profiles, logins, history, sessions).
      # Caches need no entry — preservation-common persists ~/.cache wholesale.
      preservation.preserveAt."/persistent".users.john.directories = [ ".config/chromium" ];

      # Declarative Chromium config via enterprise policy (see header:
      # managed = locked, this is the right channel for these two).
      programs.chromium = {
        enable = true;
        extensions = [
          # KeePassXC-Browser — official extension
          "oboonakemofpalcgghocfoadofidjkkk"
          # uBlock Origin
          "cjpalhdlnbpafiamejdnhcphjbkeiagm"
        ];
        extraOpts = {
          # Disable Chromium's built-in password manager — KeePassXC handles it
          "PasswordManagerEnabled" = false;
        };
      };

      # KeePassXC native messaging host for Chromium browser integration
      environment.etc."chromium/native-messaging-hosts/org.keepassxc.keepassxc_browser.json".source =
        "${pkgs.keepassxc}/share/keepassxc/browser/native-messaging-hosts/org.keepassxc.keepassxc_browser.json";
    };
}
