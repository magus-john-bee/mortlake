---
name: nix-wrapper-modules
description: Use when wrapping a program with baked-in config using nix-wrapper-modules — covers the .wrap pattern for programs with dedicated wrappers, wrapPackage for custom wrappers, constructFiles for generating config files, and the env/flags/makeWrapper API.
---

# nix-wrapper-modules

Creates wrapped executables as self-contained derivations with baked-in configuration. No NixOS or Home Manager required — the config is in the package itself.

**Wrapped packages are:**
- Runnable standalone via `nix run .#<name>`
- Proper dependencies (pulls in programs referenced via `lib.getExe`)
- Build-validated where the upstream tool supports it

## Simple Pattern — Dedicated Wrapper Module

For programs with built-in wrapper modules (alacritty, niri, tmux, mpv, git, etc.):

```nix
perSystem = { pkgs, lib, self', ... }: {
  packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
    inherit pkgs;
    settings = {
      binds."Mod+Return".spawn-sh = lib.getExe pkgs.kitty;
      layout.gaps = 5;
    };
  };
};
```

- `wrappers.<program>.wrap { ... }` — returns a derivation
- `wrappers.<program>.apply { ... }` — returns `config` (for chaining)
- **ALWAYS `inherit pkgs;`** — missing this breaks the build

## Custom Pattern — wrapPackage

For programs without a dedicated wrapper module:

```nix
perSystem = { pkgs, lib, ... }: {
  packages.atuin = inputs.wrapper-modules.lib.wrapPackage (
    { config, wlib, ... }:
    let
      fmt = pkgs.formats.toml { };
    in
    {
      options.settings = lib.mkOption {
        type = fmt.type;
        default = { };
      };

      config = {
        pkgs = pkgs;
        package = pkgs.atuin;

        settings = {
          auto_sync = true;
          sync_frequency = "2m";
        };

        env.ATUIN_CONFIG_DIR = dirOf config.constructFiles.configDir.path;

        constructFiles.configDir = {
          content = builtins.toJSON config.settings;
          relPath = "atuin/config.toml";
          builder = ''mkdir -p "$(dirname "$2")" && ${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
        };
      };
    }
  );
};
```

### When using `options`/`config` split

`pkgs` and `package` **MUST go inside `config`**, not at the top level. The Nix module system rejects freeform top-level attrs alongside `options`.

### When NOT using options/config split

Simple attrset — `pkgs` and `package` go at the top level:

```nix
inputs.wrapper-modules.lib.wrapPackage ({ config, wlib, ... }: {
  pkgs = pkgs;
  package = pkgs.curl;
  env.CURL_HOME = "/some/path";
});
```

## constructFiles — Generate Config Files

Creates files at build time inside the wrapper derivation.

| Option | Description |
|--------|-------------|
| `content` | File content (passed via `passAsFile`) |
| `relPath` | Relative path within the output (no leading `/`) |
| `builder` | Bash command: `$1` = input, `$2` = output. Default: `cp "$1" "$2"` |
| `path` | **Read-only** — path with `${placeholder "out"}` — usable inside the module only |
| `outPath` | **Read-only** — resolved store path — usable outside the module |

Multiple entries can share a parent directory (e.g., `app/config.toml` + `app/themes/nord.toml`).

### TOML generation

```nix
constructFiles.config = {
  content = builtins.toJSON config.settings;
  relPath = "app/config.toml";
  builder = ''mkdir -p "$(dirname "$2")" && ${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
};
```

### Getting the config directory for env vars

```nix
env.MY_CONFIG_DIR = dirOf config.constructFiles.configFile.path;
```

## env — Environment Variables

```nix
env = {
  MY_VAR = "value";
  NULL_VAR = null;  # unsets the variable
};
```

### ⚠️ env leaks to child processes

Every variable set in `env` is `export`ed by the wrapper script. This means **all child processes inherit them**. For programs that spawn shells (terminal emulators, editors with embedded terminals), this can cause breakage:

- **Bad**: `env.XDG_CONFIG_HOME = <nix-store-path>` in a ghostty wrapper — atuin in the spawned shell tries to create `$XDG_CONFIG_HOME/atuin/` inside the read-only nix store → crash
- **Good**: Use `flags."--config-file"` to pass config as a CLI argument (app-specific, no env pollution), or use app-specific env vars (like `ATUIN_CONFIG_DIR`, `ZELLIJ_CONFIG_DIR`) that don't affect other programs

Prefer `flags` or app-specific config env vars over broad env vars like `XDG_CONFIG_HOME` or `XDG_DATA_HOME` when wrapping process-spawning programs.

Exception: some programs (e.g., helix) resolve multiple config files from `XDG_CONFIG_HOME` with no alternative flag for all of them. For these, `env.XDG_CONFIG_HOME` is acceptable if the program does not primarily spawn shells.

## flags — Command-Line Flags

```nix
flags = {
  "--config" = ./path/to/config;   # path interpolated
  "--silent" = true;                # flag without value
  "--verbose" = false;              # flag omitted
  "--format" = [ "json" "pretty" ]; # repeated
};
```

### Prefer flags over env.XDG_CONFIG_HOME for config discovery

When the wrapped program supports a `--config-file` flag (ghostty, many CLI tools), use `flags` instead of `env.XDG_CONFIG_HOME`. This avoids leaking a custom `XDG_CONFIG_HOME` into child processes:

```nix
# ✅ Good — config as CLI flag, no env pollution
flags."--config-file" = config.constructFiles.configFile.path;
constructFiles.configFile = {
  content = builtins.readFile ./config;
  relPath = "app/config";
};

# ❌ Bad — leaks XDG_CONFIG_HOME to all child processes
env.XDG_CONFIG_HOME = dirOf (dirOf config.constructFiles.configFile.path);
constructFiles.configFile = {
  content = builtins.readFile ./config;
  relPath = "app/config.toml";
};
```

## Other Useful Options

| Option | Description |
|--------|-------------|
| `extraPackages` | Added to PATH |
| `runtimeLibraries` | Added to LD_LIBRARY_PATH |
| `runShell` | Shell commands before main program |
| `wrapperImplementation` | `"nix"` (default), `"shell"`, `"binary"` |

## Chaining

Wrappers support `.wrap`, `.apply`, `.eval` on both `config` and `passthru`:

```nix
let
  step1 = wrappers.tmux.eval { plugins = [ pkgs.tmuxPlugins.onedark-theme ]; };
  step2 = step1.config.apply { modeKeys = "vi"; };
  final = step2.wrap { inherit pkgs; };
in final
```

## Gotchas

1. **ALWAYS `inherit pkgs;`** in `.wrap` calls
2. **`pkgs`/`package` inside `config`** when using options/config split
3. **`path` vs `outPath`** — `path` has `${placeholder "out"}`, only usable inside the module; `outPath` has resolved store path, usable outside
4. **`wrapPackage` auto-includes `wlib.modules.default`** (makeWrapper + symlinkScript + constructFiles); `evalPackage` does not
5. **`self'` not available in `flake.nixosModules`** — use `self.packages.${pkgs.system}.<name>` to reference wrapped packages from NixOS modules
6. **Avoid `env.XDG_CONFIG_HOME` for wrappers that spawn child processes** (terminal emulators, editors with shell features) — `env` exports to ALL child processes, causing apps like atuin to try writing into the read-only nix store. Use `flags."--config-file"` instead (or app-specific env vars like `ATUIN_CONFIG_DIR`, `ZELLIJ_CONFIG_DIR`).

## References

- wrapper-modules: https://github.com/BirdeeHub/nix-wrapper-modules
- wrapper-modules docs: https://birdeehub.github.io/nix-wrapper-modules/md/intro.html
- vimjoyer template: https://github.com/vimjoyer/flake-parts-wrapped-template
- vimjoyer vid79 page: https://www.vimjoyer.com/vid79-parts-wrapped
