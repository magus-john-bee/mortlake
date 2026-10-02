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

      # Declarative config, deployed via tmpfiles (house pattern — same
      # mechanism as dev-dirs/syncthing): L+ creates/repairs the symlink
      # at every activation AND boot, before the user session starts (no
      # race with an autostarted nyxt). Target is the stable /etc path —
      # activation repoints /etc/nyxt/config.lisp across generations, so
      # the symlink itself never goes stale.
      systemd.tmpfiles.rules = [
        "d /home/john/.config/nyxt 0755 john users - -"
        "L+ /home/john/.config/nyxt/config.lisp - - - - /etc/nyxt/config.lisp"
      ];

      preservation.preserveAt."/persistent".users.john.directories = [ ".local/share/nyxt" ];
    };
}
