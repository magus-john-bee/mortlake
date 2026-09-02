_: {
  flake.nixosModules.nginx = _: {
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
    };

    # Nginx uses PrivateTmp which needs /tmp to exist as a mount point.
    # On tmpfs-root systems, /tmp is bind-mounted from /persistent by
    # preservation.target, which may not be ready during nixos-rebuild switch.
    systemd.services.nginx = {
      after = [ "tmp.mount" ];
      requires = [ "tmp.mount" ];
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        email = "johnbee@otwell.dev";
        group = "nginx";
      };
    };
  };
}
