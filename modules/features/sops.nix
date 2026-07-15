{ inputs, ... }:
{
  flake.nixosModules.sops =
    { pkgs, ... }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];

      environment = {
        systemPackages = [ pkgs.ssh-to-age ];
        sessionVariables.SOPS_AGE_KEY_CMD = "sudo ssh-to-age -private-key -i /persistent/etc/ssh/ssh_host_ed25519_key";
      };

      sops = {
        defaultSopsFile = ./secrets.yaml;
        defaultSopsFormat = "yaml";

        age.sshKeyPaths = [ "/persistent/etc/ssh/ssh_host_ed25519_key" ];

        secrets =
          let
            john = {
              owner = "john";
            };
          in
          {
            "elevenlabs-api-key" = john;
            "exa-api-key" = john;
            "glm-api-key" = john;
            "groq-api-key" = john;
            "deepseek-api-key" = john;
            "openrouter-api-key" = john;
            "hf-token" = john;
            "discord-bot-token" = john;
            "discord-allowed-users" = john;
            "discord-home-channel" = john;
            "minimax-api-key" = john;
            "gh-oauth-token" = john;
            "gh-gist-token" = john;
          };
      };
    };
}
