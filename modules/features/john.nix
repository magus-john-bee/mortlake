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

      # Default ACL: any file/dir created under /home/john — even by root
      # via sudo — automatically gets rwx for john. Eliminates the chown
      # dance when root writes into john's home (common with restic restores,
      # sops, manual fixes, etc.). Applies to new files only (-d = default).
      system.activationScripts.john-default-acls.text = lib.mkAfter ''
        if [ -d /home/john ]; then
          ${pkgs.acl}/bin/setfacl -R -d -m u:john:rwx /home/john
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

      security.sudo = {
        # No password for john — single-user machine, sudo is a formality.
        extraRules = [
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
        # Suppress the first-use lecture ("We trust you have received...").
        extraConfig = ''
          Defaults lecture = never
        '';
      };

      # Polkit: allow wheel users to perform privileged actions without
      # a password prompt. This is the *other* auth stack — even with
      # NOPASSWD sudo, desktop prompts (mounting, networking, systemd
      # service control via GUI) route through polkit and would still
      # ask for a password. On a single-user machine this is pure friction.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (subject.isInGroup("wheel")) {
            return polkit.Result.YES;
          }
        });
      '';

      nix.settings.trusted-users = [
        "root"
        "john"
      ];
    };
}
