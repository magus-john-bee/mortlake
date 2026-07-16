# phones/ -- GrapheneOS provisioning scripts

Declarative phone provisioning for GrapheneOS devices. A poor man's NixOS config for Android.

## Quick Start

1. Install prerequisites on your computer:
   ```bash
   # NixOS
   nix-env -iA nixpkgs.android-tools nixpkgs.yq nixpkgs.fdroidcl

   # Or standalone
   go install mvdan.cc/fdroidcl@latest
   go install github.com/mikefarah/yq/v4@latest
   ```

2. Connect your GrapheneOS device via USB with USB debugging enabled.

3. Run the provisioner:
   ```bash
   ./provision.sh profiles/pixel-9.yaml
   ```

4. For a dry run first:
   ```bash
   ./provision.sh --dry-run profiles/pixel-9.yaml
   ```

## Profiles

Each YAML file in `profiles/` defines a device configuration:

- **obtainium**: Apps tracked directly from source releases (GitHub, GitLab, F-Droid repos)
- **fdroid**: Apps installed via `fdroidcl` over ADB (fully automated)
- **aurora**: Apps only on Google Play (manual checklist -- Aurora Store can't be scripted)
- **system**: Device settings (dark mode, analytics, etc.)
- **nix-on-droid**: Bootstrap config for the Linux userspace on the device

See `profiles/example.yaml` for the full schema.

## Source Priority

When an app is available from multiple sources:

1. **Obtainium** (preferred) -- tracks the developer's own releases, fastest updates
2. **fdroidcl** (secondary) -- reproducible builds from F-Droid, good for FOSS apps
3. **Aurora Store** (fallback) -- anything only on Google Play, must be done manually

Don't list the same app in multiple sources -- signature mismatches will prevent cross-source updates.

## Phases

| Phase | Description | Automated? |
|-------|-------------|------------|
| 0 | Prerequisites check | Yes |
| 1 | Bootstrap Obtainium + push export | Semi (one manual import step) |
| 2 | F-Droid apps via fdroidcl | Yes |
| 3 | Aurora Store checklist | No (prints shopping list) |
| 4 | System settings | Yes |
| 5 | nix-on-droid setup | No (prints instructions) |

Run a single phase: `./provision.sh --phase 2 profiles/pixel-9.yaml`

## nix-on-droid

[nix-on-droid](https://github.com/nix-community/nix-on-droid) gives you a Nix-managed Linux environment on the phone via Termux. It's orthogonal to the Android app provisioning -- it provides CLI tools (vim, git, ssh, python, etc.) but can't install APKs.

### Self-provisioning workflow (optional)

With nix-on-droid set up, you can run the provisioning script from the phone itself:

1. Install Termux (Phase 2 of this script)
2. Set up nix-on-droid (Phase 5 instructions)
3. In nix-on-droid: `nix profile install nixpkgs#android-tools nixpkgs#yq nixpkgs#fdroidcl`
4. Clone this repo on the phone
5. Enable wireless ADB: `adb tcpip 5555 && adb connect localhost:5555`
6. Run `./provision.sh` from the phone

No computer needed after initial Termux install.

## Idempotency

The script is safe to re-run:
- Obtainium import is additive (skips already-tracked apps)
- `fdroidcl install` is a no-op for already-installed apps
- System settings re-apply harmlessly
- Use `--dry-run` to preview without acting

## Adding a new device

Copy an existing profile and customize:

```bash
cp profiles/pixel-9.yaml profiles/my-tablet.yaml
# Edit apps, system settings, etc.
./provision.sh profiles/my-tablet.yaml
```
