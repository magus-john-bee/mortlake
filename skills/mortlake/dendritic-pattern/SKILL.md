---
name: dendritic-pattern
description: General reference for the dendritic pattern — flake-parts + import-tree auto-discovery, cross-referencing rules (self vs self'), host/feature file layout, and boilerplate. Use this when you need to understand WHAT the pattern IS and how files reference each other. For corpus-specific conventions (module organization, hostname switching, persistence migration, PR scope, systemd debugging), use corpus-nixos-modules instead.
---

# Dendritic Pattern

Every `.nix` file under `modules/` is a **flat flake-parts module**, auto-discovered by `import-tree`. No manual imports, no relative paths — everything references by name through `self`.

## Entry Point

```nix
# flake.nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; }
  (inputs.import-tree ./modules);
```

`import-tree` recursively discovers all `.nix` files under `modules/`. Files starting with `_` are excluded.

## Key Inputs

- **flake-parts** — `mkFlake` wraps the NixOS module system around flake outputs
- **import-tree** — auto-discovers and imports all `.nix` files
- **nix-wrapper-modules** — wraps programs with baked-in config (see `nix-wrapper-modules` skill)
- **disko** — declarative disk partitioning
- **sops-nix** — secrets management (see `sops-nix` skill)

## Boilerplate — Every File Follows This Pattern

```nix
{ self, inputs, ... }: {
  # flake-level outputs
  flake.nixosModules.<name> = { pkgs, lib, ... }: { /* NixOS config */ };
  flake.nixosConfigurations.<name> = inputs.nixpkgs.lib.nixosSystem { /* ... */ };

  # per-system outputs (auto-generated for each system)
  perSystem = { pkgs, lib, self', ... }: {
    packages.<name> = /* derivation */;
  };
}
```

- `flake.nixosModules.<name>` — reusable NixOS module, referenceable from any file
- `flake.nixosConfigurations.<name>` — a complete NixOS system
- `perSystem` — packages, devShells, apps (auto-per-architecture)

## Host Files (`modules/hosts/<name>/`)

Each host has 3-4 files:

| File | Purpose |
|------|---------|
| `default.nix` | Wires up `flake.nixosConfigurations.<name>` with pkgs (allowUnfree set here) |
| `configuration.nix` | `flake.nixosModules.<name>Configuration` — imports feature modules |
| `hardware.nix` | `flake.nixosModules.<name>Hardware` — filesystems, boot, kernel |
| `disko.nix` | `flake.nixosModules.<name>Disko` — disk partitioning (optional) |

### default.nix Pattern

```nix
{ self, inputs, ... }:
let
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in {
  flake.nixosConfigurations.thoth = inputs.nixpkgs.lib.nixosSystem {
    inherit pkgs;
    modules = [ self.nixosModules.thothConfiguration ];
  };
}
```

`allowUnfree` MUST be set here (at pkgs creation), not inside NixOS modules — the module system rejects post-instantiation config changes.

### configuration.nix Pattern

```nix
{ self, inputs, ... }: {
  flake.nixosModules.thothConfiguration = { pkgs, lib, ... }: {
    imports = [
      self.nixosModules.thothHardware
      self.nixosModules.thothDisko
      inputs.disko.nixosModules.disko
      self.nixosModules.common
      self.nixosModules.users
      # ... more feature modules
    ];
  };
}
```

## Feature Files (`modules/features/`)

```nix
{ self, inputs, ... }: {
  flake.nixosModules.someFeature = { pkgs, lib, ... }: {
    environment.systemPackages = [ /* ... */ ];
  };

  perSystem = { pkgs, lib, self', ... }: {
    packages.someFeature = /* wrapped or unwrapped derivation */;
  };
}
```

## Cross-Referencing Rules

| Context | Use | Example |
|---------|-----|---------|
| Reference a NixOS module | `self.nixosModules.<name>` | `self.nixosModules.common` |
| Reference a package in `perSystem` | `self'.packages.<name>` | `self'.packages.atuin` |
| Reference a package in `flake.nixosModules` | `self.packages.${pkgs.system}.<name>` | `self.packages.${pkgs.system}.atuin` |
| Get a binary path in `perSystem` | `lib.getExe self'.packages.<name>` | keybinds, service executables |
| Get a binary path anywhere | `lib.getExe pkgs.<pkg>` | system packages |

**`self'` is NOT available in `flake.nixosModules`** — use the `${pkgs.system}` form instead.

## Systems List

Defined in `modules/parts.nix`:

```nix
{ ... }: {
  systems = [ "x86_64-linux" ];
}
```

## References

- flake-parts docs: https://flake.parts/
- import-tree: https://github.com/vic/import-tree
- vimjoyer video 76: https://www.youtube.com/watch?v=-TRbzkw6Hjs
- vimjoyer video 79: https://www.youtube.com/watch?v=aNgujRXDTdE
