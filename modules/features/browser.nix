# Browser — nyxt + ungoogled-chromium with persistence + KeePassXC integration.
# Fixes the corpus bug where browser data was NOT persisted on tmpfs-root hosts
# (every reboot = fresh browser, no logins).
{ pkgs, ... }:
{
  flake.nixosModules.browser =
    { pkgs, ... }:
    {
      environment = {
        systemPackages = with pkgs; [
          nyxt
          ungoogled-chromium
        ];

        # Declarative Nyxt config (vim keybindings, search engines, ad blocking)
        etc."nyxt/config.lisp".source = ./nyxt/config.lisp;
      };

      # Symlink Nyxt config into ~/.config/nyxt/ for the john user
      # (Nyxt reads from $XDG_CONFIG_HOME/nyxt/config.lisp)
      systemd.user.services.nyxt-config-link = {
        script = ''
          mkdir -p /home/john/.config/nyxt
          ln -sf /etc/nyxt/config.lisp /home/john/.config/nyxt/config.lisp
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        wantedBy = [ "default.target" ];
      };

      # Persist browser data across reboots (tmpfs-root hosts)
      preservation.preserveAt."/persistent".users.john.directories = [
        ".config/chromium"
        ".cache/chromium"
        ".config/nyxt"
        ".local/share/nyxt"
        ".cache/nyxt"
      ];

      # Declarative Chromium extensions via enterprise policy
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
