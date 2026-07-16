#!/usr/bin/env bash
# lib/fdroid.sh -- fdroidcl wrapper with idempotency
# Sourced by provision.sh, not run directly.

# ── Update F-Droid index ─────────────────────────────────
fdroid_update_index() {
  info "Updating F-Droid index"
  run_or_echo fdroidcl update
}

# ── Install an app via fdroidcl ──────────────────────────
# Skips if already installed at the latest version.
fdroid_install() {
  local app_id="$1" serial="${2:-}"

  # Check if already installed on device
  if is_installed "$serial" "$app_id"; then
    info "$app_id already installed, checking for updates..."
    # fdroidcl install handles upgrades too
    run_or_echo fdroidcl install "$app_id"
  else
    info "Installing $app_id via fdroidcl"
    run_or_echo fdroidcl install "$app_id"
  fi
}

# ── Verify all expected F-Droid apps are installed ───────
fdroid_verify() {
  local profile="$1" serial="${2:-}"
  local missing=0

  while IFS= read -r app_id; do
    if ! is_installed "$serial" "$app_id"; then
      warn "MISSING: $app_id"
      missing=$((missing + 1))
    fi
  done < <(yaml "$profile" '.fdroid[]?.id // empty' 2>/dev/null)

  if [[ "$missing" -eq 0 ]]; then
    info "All F-Droid apps installed."
  else
    warn "$missing F-Droid app(s) missing."
  fi
}
