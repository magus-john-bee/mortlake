---
name: nix-heredoc-percent-gotcha
description: Handling % characters in Nix double-single-quoted ('') heredoc strings — especially for zsh zstyle completion format strings
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [nix, nixos, zsh, heredoc, escaping]
    related_skills: [nixos-rebuild-dry-run]
---

# Nix `''` Heredoc `%` Escaping Gotcha

## The Problem

In Nix, `%` inside `''` (double-single-quoted) heredoc strings can cause cryptic parse errors:

```
error: syntax error, unexpected invalid token
  at ...zsh.nix:49:24
      48|                 zstyle ':completion:*' group-name ''
      49|                 zstyle ':completion:*' format '%B%d%b'
```

This happens with zsh completion format strings like:
- `'%B%d%b'` — bold + description + resetting
- `'%B%F{yellow}%d%f%b'` — bold + yellow fg + description + reset
- `'header: %d'` — completion header with description

## Why It Happens

Nix's `''` heredoc syntax has special `${}` interpolation semantics. While `%` isn't a Nix interpolation character, it appears the parser can still choke on certain `%` sequences in specific contexts.

## Workarounds (in order of cleanliness)

1. **Remove the zstyle lines entirely** — formatting is cosmetic; completions still work without it
2. **Move zstyle configs to the wrapped package's `rcfiles.zshrc`** — plain shell strings, no Nix parsing
3. **Source a separate shell script file** from `interactiveShellInit` rather than embedding the code
4. **Use double-quoted strings** with explicit escape handling — but this creates `${}` interpolation conflicts, so it's messy

## Example: Removing cosmetic zstyles (simplest fix)

```nix
# Before (broken):
''
  zstyle ':completion:*' format '%B%d%b'
''

# After (works):
# zstyle formatting omitted — completions still function without it
```

The zstyle format strings are purely visual polish for completion menu display. Removing them doesn't break completion behavior.
