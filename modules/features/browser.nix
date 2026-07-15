# Browser — nyxt + ungoogled-chromium with persistence + KeePassXC integration.
# Fixes the corpus bug where browser data was NOT persisted on tmpfs-root hosts
# (every reboot = fresh browser, no logins).
_:
{
  flake.nixosModules.browser =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        nyxt
        ungoogled-chromium
      ];

      # Persist browser data across reboots (tmpfs-root hosts)
      preservation.preserveAt."/persistent".users.john.directories = [
        ".config/chromium"
        ".config/nyxt"
        ".local/share/nyxt"
        ".cache/nyxt"
      ];

      # Declarative Chromium extensions via enterprise policy
      programs.chromium = {
        enable = true;
        extensions = [
          # KeePassXC-Browser — official extension
          # https://chromewebstore.google.com/detail/keepassxc-browser/oboonakemofpalcgghocfoadofidjkkk
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

      # TODO: Declarative Nyxt config (nyxt-config.lisp) with KeePassXC
      # password interface. Nyxt has built-in keepassxc support via
      # password-keepassxc.lisp — no extension needed, just config.
    };
}
