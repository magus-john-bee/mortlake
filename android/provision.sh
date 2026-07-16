#!/usr/bin/env bash
# provision.sh -- provision a GrapheneOS device from a YAML profile
# Usage: ./provision.sh [options] <profile.yaml>
#
# Options:
#   --dry-run    Print what would be done without acting
#   --phase N    Run only a specific phase (0-5)
#   --verbose    Verbose output
#   --help       Show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ──────────────────────────────────────────────
DRY_RUN=false
PHASE=""
VERBOSE=false
PROFILE=""

# ── Parse args ────────────────────────────────────────────
usage() {
  sed -n '2,/^$/s/^# //p' "$0"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)  DRY_RUN=true; shift ;;
    --phase)    PHASE="$2"; shift 2 ;;
    --verbose)  VERBOSE=true; shift ;;
    --help|-h)  usage ;;
    -*)         echo "Unknown option: $1" >&2; exit 1 ;;
    *)          PROFILE="$1"; shift ;;
  esac
done

if [[ -z "$PROFILE" ]]; then
  echo "Error: no profile specified" >&2
  echo "Usage: $0 <profile.yaml>" >&2
  exit 1
fi

if [[ ! -f "$PROFILE" ]]; then
  echo "Error: profile not found: $PROFILE" >&2
  exit 1
fi

# ── Source libraries ──────────────────────────────────────
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/obtainium.sh"
source "$SCRIPT_DIR/lib/fdroid.sh"
source "$SCRIPT_DIR/lib/system.sh"

# ── Resolve YAML values ──────────────────────────────────
# All yaml() calls go through a single helper so the parser
# backend (yq vs python) is centralized in common.sh.

PROFILE_NAME=$(yaml "$PROFILE" '.profile.name')
DEVICE_SERIAL=$(yaml "$PROFILE" '.profile.device // ""')

# ── Phase runners ────────────────────────────────────────

run_phase_0() {
  header "Phase 0: Prerequisites"
  check_adb
  check_fdroidcl
  check_device_connected "$DEVICE_SERIAL"
  info "Profile: $PROFILE_NAME"
  info "Device: $(device_model)"
}

run_phase_1() {
  header "Phase 1: Bootstrap Obtainium"
  local bootstrap_apps
  bootstrap_apps=$(yaml "$PROFILE" '.obtainium[] | select(.bootstrap == true) | .id')

  if [[ -z "$bootstrap_apps" ]]; then
    warn "No bootstrap apps found in profile. Skipping."
    return
  fi

  while IFS= read -r app_id; do
    local url name
    url=$(yaml "$PROFILE" ".obtainium[] | select(.id == \"$app_id\") | .url")
    name=$(yaml "$PROFILE" ".obtainium[] | select(.id == \"$app_id\") | .name")
    obtainium_install_bootstrap "$app_id" "$url" "$name"
  done <<< "$bootstrap_apps"

  # Generate and push the Obtainium export JSON
  obtainium_generate_export "$PROFILE" "/tmp/obtainium-export.json"
  obtainium_push_export "/tmp/obtainium-export.json" "$DEVICE_SERIAL"

  echo ""
  info "On your device: Open Obtainium > Import/Export > Import from Downloads"
  info "Then tap each app to install it."
}

run_phase_2() {
  header "Phase 2: F-Droid apps (fdroidcl)"
  local fdroid_apps
  fdroid_apps=$(yaml "$PROFILE" '.fdroid[]?.id // empty')

  if [[ -z "$fdroid_apps" ]]; then
    info "No F-Droid apps in profile."
    return
  fi

  fdroid_update_index
  while IFS= read -r app_id; do
    fdroid_install "$app_id" "$DEVICE_SERIAL"
  done <<< "$fdroid_apps"
}

run_phase_3() {
  header "Phase 3: Aurora Store apps (manual)"
  local aurora_apps
  aurora_apps=$(yaml "$PROFILE" '.aurora[]?.id // empty')

  if [[ -z "$aurora_apps" ]]; then
    info "No Aurora Store apps in profile."
    return
  fi

  # Verify Aurora Store is installed
  if ! adb_shell "$DEVICE_SERIAL" "pm list packages" | grep -q "com.aurora.store"; then
    warn "Aurora Store not installed. Install it via F-Droid first."
    return
  fi

  echo ""
  info "Open Aurora Store and install these apps:"
  while IFS= read -r app_id; do
    local name
    name=$(yaml "$PROFILE" ".aurora[] | select(.id == \"$app_id\") | .name")
    echo "  [ ] $name ($app_id)"
  done <<< "$aurora_apps"
  echo ""
}

run_phase_4() {
  header "Phase 4: System configuration"
  local dark_mode disable_analytics
  dark_mode=$(yaml "$PROFILE" '.system.dark_mode // false')
  disable_analytics=$(yaml "$PROFILE" '.system.disable_analytics // false')

  [[ "$dark_mode" == "true" ]] && system_set_dark_mode "$DEVICE_SERIAL"
  [[ "$disable_analytics" == "true" ]] && system_disable_analytics "$DEVICE_SERIAL"

  # Extra commands
  local extra_cmds
  extra_cmds=$(yaml "$PROFILE" '.system.extra[]? // empty')
  if [[ -n "$extra_cmds" ]]; then
    info "Running extra system commands..."
    while IFS= read -r cmd; do
      run_or_echo "adb shell $cmd"
    done <<< "$extra_cmds"
  fi
}

run_phase_5() {
  header "Phase 5: nix-on-droid"
  local enabled
  enabled=$(yaml "$PROFILE" '.nix-on-droid.enabled // false')

  if [[ "$enabled" != "true" ]]; then
    info "nix-on-droid not enabled for this profile."
    return
  fi

  info "Termux should already be installed (Phase 2)."
  info "To set up nix-on-droid, open Termux on the device and run:"
  echo ""
  echo "  curl -fL https://github.com/nix-community/nix-on-droid/releases/download/24.05/bootstrap-aarch64.zip -o /tmp/nix.zip"
  echo "  curl -fL https://github.com/nix-community/nix-on-droid/releases/download/24.05/bootstrap-aarch64.zip.sha256sum -o /tmp/nix.zip.sha256sum"
  echo "  sha256sum -c /tmp/nix.zip.sha256sum && unzip /tmp/nix.zip -d /tmp/nix && /tmp/nix/install"
  echo ""

  local flake_url
  flake_url=$(yaml "$PROFILE" '.nix-on-droid.flake_url // ""')
  if [[ -n "$flake_url" ]]; then
    info "After install, apply your flake config:"
    echo "  nix-on-droid switch --flake $flake_url"
  fi
}

# ── Main ──────────────────────────────────────────────────

echo "╔══════════════════════════════════════════╗"
echo "║   GrapheneOS Phone Provisioner v0.1.0    ║"
echo "╚══════════════════════════════════════════╝"
echo ""

case "${PHASE:-all}" in
  0) run_phase_0 ;;
  1) run_phase_1 ;;
  2) run_phase_2 ;;
  3) run_phase_3 ;;
  4) run_phase_4 ;;
  5) run_phase_5 ;;
  all)
    run_phase_0
    echo ""
    run_phase_1
    echo ""
    run_phase_2
    echo ""
    run_phase_3
    echo ""
    run_phase_4
    echo ""
    run_phase_5
    ;;
  *) echo "Error: unknown phase '$PHASE'" >&2; exit 1 ;;
esac

echo ""
header "Done"
info "Verify installed packages:"
echo "  $0 --phase 0 $PROFILE  # re-check prerequisites"
echo "  adb shell pm list packages -3  # list all third-party packages"
