# GUI packages — no zed-editor, no zed/garnix cache. keepassxc instead of proton-pass.
_: {
  flake.nixosModules.gui-packages =
    { pkgs, ... }:
    let
      ankiWith = pkgs.anki.withAddons [
        pkgs.ankiAddons.anki-connect
      ];
    in
    {
      environment.systemPackages = with pkgs; [
        ankiWith
        keepassxc
        librewolf
        logseq
        meld
        kdePackages.okular
        vlc
      ];

      # Electron apps (logseq, anki) may need this
      nixpkgs.config.permittedInsecurePackages = [
        "electron-39.8.10"
      ];
    };
}
