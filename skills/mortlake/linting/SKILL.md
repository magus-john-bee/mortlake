---
name: linting
description: Nix linting workflow — nixfmt, statix, deadnix via just recipes
category: corpus
---

# Linting

Before committing Nix changes, run linting to catch issues early.

## Quick Fix

```bash
just lint-fix
```

Auto-fixes formatting (nixfmt), unused bindings (statix fix), and dead code (deadnix --edit).

**Not all issues can be auto-fixed.** If `just lint-fix` doesn't clear everything, read the errors from `just lint` and fix manually:
- statix may suggest `inherit` rewrites or restructuring that it can't auto-apply
- deadnix may flag unused args that require understanding context to remove safely
- After manual fixes, re-run `just lint` to verify

## Check Only

```bash
just lint
```

Reports issues without modifying files.

## Pre-commit Hooks

The devshell (`nix develop`) installs pre-commit hooks that run nixfmt, statix, and deadnix on every commit. If a commit fails, run `just lint-fix` and retry.

## Tools

| Tool | What it catches | Fix command |
|------|----------------|-------------|
| nixfmt | Formatting | `nixfmt <file>` |
| statix | Unused bindings, style issues | `statix fix .` |
| deadnix | Dead/unused let bindings, unused pattern args | `deadnix --edit .` |
