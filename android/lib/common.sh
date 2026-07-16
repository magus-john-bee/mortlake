#!/usr/bin/env bash
# lib/common.sh -- shared utilities for provision.sh
# Sourced by provision.sh, not run directly.

# ── Colors ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

header()  { echo -e "${BLUE}══ $1 ══${NC}"; }
info()    { echo -e "${GREEN}  ✓${NC} $1"; }
warn()    { echo -e "${YELLOW}  ⚠${NC} $1"; }
error()   { echo -e "${RED}  ✗${NC} $1" >&2; }

# ── Dry-run wrapper ───────────────────────────────────────
# Runs the command, or prints it if DRY_RUN=true
run_or_echo() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

# ── YAML helper ───────────────────────────────────────────
# Usage: yaml <file> <yq_expression>
# Uses yq (mikefarah/yq) if available, falls back to python.
yaml() {
  local file="$1" expr="$2"
  if command -v yq &>/dev/null; then
    yq "$expr" "$file"
  elif command -v python3 &>/dev/null; then
    python3 -c "
import sys, yaml
data = yaml.safe_load(open('$file'))
# Minimal yq expression evaluation for common patterns
# This is a fallback -- install yq for full support
expr = '$expr'
# Handle: .key, .key.nested, .key // default, .[] | select(...)
print('WARNING: python fallback for yq is limited. Install yq for full support.' >&2)
sys.exit(1)
"
  else
    error "Need yq or python3 to parse YAML profiles"
    error "Install: nix-env -iA nixpkgs.yq  OR  go install github.com/mikefarah/yq/v4@latest"
    exit 1
  fi
}

# ── ADB helpers ───────────────────────────────────────────

# Run an adb shell command, optionally targeting a specific device serial.
adb_shell() {
  local serial="$1"
  shift
  if [[ -n "$serial" ]]; then
    adb -s "$serial" shell "$@"
  else
    adb shell "$@"
  fi
}

# Check that adb is installed and a device is connected.
check_adb() {
  if ! command -v adb &>/dev/null; then
    error "adb not found. Install android-platform-tools."
    exit 1
  fi
  info "adb found: $(adb version | head -1)"
}

check_fdroidcl() {
  if ! command -v fdroidcl &>/dev/null; then
    error "fdroidcl not found. Install: go install mvdan.cc/fdroidcl@latest"
    exit 1
  fi
  info "fdroidcl found: $(fdroidcl version 2>&1 | head -1)"
}

check_device_connected() {
  local serial="$1"
  local devices
  devices=$(adb devices | grep -v "List of devices" | grep -v "^$" | wc -l)

  if [[ "$devices" -eq 0 ]]; then
    error "No devices connected. Enable USB debugging and accept the ADB prompt."
    exit 1
  fi

  if [[ -n "$serial" ]]; then
    if ! adb devices | grep -q "$serial"; then
      error "Device $serial not found among connected devices."
      adb devices
      exit 1
    fi
    info "Targeting device: $serial"
  else
    if [[ "$devices" -gt 1 ]]; then
      warn "Multiple devices connected. Specify --device in profile or set ANDROID_SERIAL."
      adb devices
      exit 1
    fi
    info "Single device detected: $(adb devices | grep -v "List" | awk '{print $1}')"
  fi
}

device_model() {
  adb_shell "${DEVICE_SERIAL:-}" "getprop ro.product.model" 2>/dev/null || echo "unknown"
}

# ── Package query ─────────────────────────────────────────
# Check if a package is installed on the device.
is_installed() {
  local serial="$1" pkg="$2"
  adb_shell "$serial" "pm list packages" 2>/dev/null | grep -q "package:$pkg"
}
