{ self, lib, ... }:
{
  flake.nixosModules.john =
    { config, pkgs, ... }:
    let
      home = config.users.users.john.home;
      sshDir = "${home}/.ssh";
      privateKey = "${sshDir}/id_ed25519";
      publicKey = "${privateKey}.pub";
    in
    {
      # After update-users-groups.pl writes /etc/group, nscd may still
      # serve stale "group not found" results from before the switch
      # (e.g. first migration to mutableUsers=false). This causes
      # cascading failures in sops, hermes, and other activation scripts
      # that resolve the "users" group. Force nscd to flush.
      system.activationScripts.users.text = lib.mkAfter ''
        systemctl reload-or-restart nscd 2>/dev/null || true
      '';

      # Generate an Ed25519 user SSH key on first boot / install. The
      # private key lives under ~/.ssh and is preserved by
      # preservation-common (users.john.directories includes ".ssh"), so
      # rerolls reuse the same key without manual ssh-keygen.
      system.activationScripts.john-ssh-keys.text = lib.mkAfter ''
        mkdir -p ${sshDir}
        chmod 0700 ${sshDir}
        if [ ! -f ${privateKey} ]; then
          ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" \
            -C "john@${config.networking.hostName}" \
            -f ${privateKey} </dev/null
          chown john:users ${privateKey} ${publicKey}
          chmod 0600 ${privateKey}
          chmod 0644 ${publicKey}
        fi
      '';

      users.mutableUsers = false;
      users.users.john = {
        isNormalUser = true;
        description = "john";
        shell = "${self.packages.${pkgs.stdenv.hostPlatform.system}.zsh}/bin/zsh";
        linger = true;
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
        hashedPassword = "$6$nhupSF2Neq$m61opyOxxlZAt10pdgSw/ORYlLOGa8efAF7dfKVRas8Wl4hVaSUI4d5poAk9VnMFY/xejKkZjst26INwMWrZZ.";
      };

      security.sudo.extraRules = [
        {
          users = [ "john" ];
          commands = [
            {
              command = "ALL";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];

      nix.settings.trusted-users = [
        "root"
        "john"
      ];
    };
}
