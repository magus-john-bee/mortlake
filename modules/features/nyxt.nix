# Nyxt — keyboard-driven Common Lisp browser.
#
# Config is fully declarative: modules/features/nyxt/config.lisp is
# deployed to /etc/nyxt/config.lisp and symlinked into
# ~/.config/nyxt/config.lisp by the user service below (tmpfs home).
# Only browser STATE (~/.local/share/nyxt) is persisted; the config
# symlink is recreated each boot, so ~/.config/nyxt needs no
# preservation entry.
_: {
  flake.nixosModules.nyxt =
    { pkgs, ... }:
    {
      environment = {
        systemPackages = with pkgs; [ nyxt ];

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

      preservation.preserveAt."/persistent".users.john.directories = [ ".local/share/nyxt" ];
    };
}
