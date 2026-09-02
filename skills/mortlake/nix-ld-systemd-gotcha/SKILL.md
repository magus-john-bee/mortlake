---
name: nix-ld-systemd-gotcha
description: nix-ld doesn't work inside systemd services on NixOS — inject LD_LIBRARY_PATH directly instead
---

# nix-ld Systemd Service Gotcha

## Problem

`programs.nix-ld` configures `envfs` to inject library preload stubs for user login sessions. Any binary run through a user shell (or `nix run`) gets these stubs automatically. But **systemd services call store paths directly**, bypassing the user environment entirely — `nix-ld` has no effect on them.

The hermes-agent service was failing to load `libopus.so.0` for Discord voice codec despite `opus` being in `nix-ld.libraries`.

## Solution

Inject `LD_LIBRARY_PATH` directly into the systemd service environment:

```nix
systemd.services.hermes-agent.serviceConfig.Environment = [
  "LD_LIBRARY_PATH=/run/current-system/sw/lib:${pkgs.stdenv.cc.cc.lib.outPath}/lib:${pkgs.libopus.outPath}/lib"
];
```

Add the same to `nix-ld.libraries` so user sessions continue working:

```nix
programs.nix-ld = {
  enable = true;
  libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    opus
  ];
};
```

## Critical: ldconfig vs LD_LIBRARY_PATH

**NOTE:** `LD_LIBRARY_PATH` is **not enough** for Python's `ctypes.util.find_library()` on Linux. That function uses `ldconfig`, which only searches paths in `/etc/ldconfig.conf` (typically `/run/current-system/sw/lib`). It does NOT consult `LD_LIBRARY_PATH`.

This matters for any Python/Ruby/etc. code that calls `find_library()` — e.g. `discord.py`'s opus codec loader.

**Fix:** symlink the library into `/run/current-system/sw/lib` using tmpfiles so ldconfig finds it:

```nix
systemd.tmpfiles.rules = [
  # ... other rules ...
  "L+ /run/current-system/sw/lib/libopus.so ${pkgs.libopus.outPath}/lib/libopus.so - -"
];
```

This creates a symlink `/run/current-system/sw/lib/libopus.so → /nix/store/...libopus.../lib/libopus.so`. Since `/run/current-system/sw/lib` IS in ldconfig's search path, `ctypes.util.find_library("opus")` will find it.

## Key Insight

- `programs.nix-ld` → user session only (envfs, `nix-ld` stub wrappers)
- `LD_LIBRARY_PATH` in systemd env → works for `dlopen()` but NOT `find_library()`
- `systemd.tmpfiles.rules` with `L+` type → works for both `dlopen()` AND `ldconfig`-based lookup
- For Python ctypes using `find_library()`, tmpfiles symlink into system lib is required

## When This Matters

Any NixOS module that wraps a daemon/service AND loads dynamic libraries (audio codecs, database drivers, etc.) that aren't already in the store's default library path.
