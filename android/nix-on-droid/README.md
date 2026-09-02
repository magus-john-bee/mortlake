# nix-on-droid setup reference

## What it gives you

A full Nix-managed Linux userspace on Android via a Termux fork. Access to nixpkgs' ~80K precompiled packages. NOT the Android app ecosystem -- this is for CLI/Linux tools only.

## Quick install

From Termux on the device:

```bash
# Download bootstrap
curl -fL https://github.com/nix-community/nix-on-droid/releases/download/24.05/bootstrap-aarch64.zip -o ~/nix.zip

# Verify
curl -fL https://github.com/nix-community/nix-on-droid/releases/download/24.05/bootstrap-aarch64.zip.sha256sum -o ~/nix.zip.sha256sum
sha256sum -c ~/nix.zip.sha256sum

# Install
unzip ~/nix.zip -d ~/nix && ~/nix/install
```

## Configuration

Edit `~/.config/nixpkgs/nix-on-droid.nix`:

```nix
{ config, lib, pkgs, ... }:

{
  # Packages available in the nix-on-droid environment
  environment.packages = with pkgs; [
    vim
    git
    openssh
    python3
    yq
    android-tools  # for self-provisioning
    fdroidcl        # for self-provisioning
  ];

  # Terminal font
  terminal.font = "${pkgs.nerdfonts}/share/fonts/truetype/NerdFonts/JetBrainsMono-Regular.ttf";

  # Extra files in /etc
  environment.etc = {
    "ssh/ssh_config".text = ''
      Host *
        ServerAliveInterval 60
    '';
  };
}
```

Apply: `nix-on-droid switch`

## Self-provisioning

Once nix-on-droid has `android-tools` and `fdroidcl`:

```bash
# Enable ADB over TCP on the device itself
adb tcpip 5555
adb connect localhost:5555

# Clone and run the provisioner
git clone https://github.com/jbotwell/corpus.git
cd corpus/phones
./provision.sh profiles/$(hostname).yaml
```

## Flake-based config (advanced)

For managing nix-on-droid config in your corpus flake:

```nix
# In corpus flake.nix outputs:
nixOnDroidConfigurations.pixel-9 = nix-on-droid.lib.nixOnDroidConfiguration {
  pkgs = import nixpkgs { system = "aarch64-linux"; };
  modules = [ ./phones/nix-on-droid/pixel-9.nix ];
};
```

Then on the device: `nix-on-droid switch --flake github:jbotwell/corpus#pixel-9`
