# Systemd Service PATH Debugging: Worked Example

## Symptom

The agentmemory systemd user service was crash-looping:
```
agentmemory[PID]: ●  Non-interactive environment detected — auto-installing iii-engine.
agentmemory[PID]: ▲  curl or sh not found. Cannot auto-install iii-engine.
agentmemory[PID]: ■  Could not start iii-engine.
```

## What We Tried (and why each was insufficient)

### Attempt 1: Add iii and curl
```nix
path = [ iiiPkg pkgs.curl ];
```
Result: Same error. curl and iii were on PATH, but the error persisted.

### Attempt 2: Add bash too
```nix
path = [ iiiPkg pkgs.curl pkgs.bash ];
```
Result: Same error. sh was now on PATH via bash, but still failing.

### Attempt 3 (fix): Add which
```nix
path = [ iiiPkg pkgs.curl pkgs.bash pkgs.which ];
```
Result: Service starts successfully.

## Root Cause

The agentmemory Node.js binary uses `whichBinary()` internally:
```javascript
function whichBinary(name) {
  const cmd = IS_WINDOWS ? "where" : "which";
  try {
    return execFileSync(cmd, [name], { encoding: "utf-8", stdio: [...] });
  } catch { return null; }
}
```

It calls `execFileSync("which", ["curl"])` to find curl. Even though curl was in the service's PATH, the `which` command itself was not — so every binary lookup returned null.

## Diagnosis Steps

1. Check the unit file PATH:
   ```bash
   cat /etc/systemd/user/agentmemory.service | grep PATH
   ```

2. Check service logs:
   ```bash
   journalctl --user -u agentmemory -n 30
   ```

3. Verify the binaries are actually findable via the unit's PATH:
   ```bash
   env -i PATH="<from-unit-file>" bash -c 'command -v curl; command -v sh; command -v which'
   ```

4. Search the Nix store package source for the error message:
   ```bash
   grep -r "not found" /nix/store/...agentmemory.../lib/agentmemory/dist/cli.mjs
   ```

5. Read the surrounding code to find the discovery mechanism.

## General Pattern

On NixOS, if a service reports "X not found" but X is in the unit PATH, the program's binary-discovery mechanism (often `which`, `command -v`, or a shell builtin) may itself be missing from the minimal systemd environment. Always check what the code actually calls to find binaries.
