#!/usr/bin/env bash
# lib/system.sh -- Android system configuration via adb shell
# Sourced by provision.sh, not run directly.

# ── Dark mode ────────────────────────────────────────────
system_set_dark_mode() {
  local serial="${1:-}"
  info "Enabling dark mode"
  run_or_echo adb_shell "$serial" "cmd uimode night yes"
}

# ── Disable analytics ────────────────────────────────────
system_disable_analytics() {
  local serial="${1:-}"
  info "Disabling analytics"
  run_or_echo adb_shell "$serial" "settings put global analytics_enabled 0"
}

# ── Set default browser ──────────────────────────────────
system_set_default_browser() {
  local serial="${1:-}" browser_pkg="$2"
  info "Setting default browser to $browser_pkg"
  # This is tricky -- Android doesn't have a clean adb command for defaults.
  # Best effort: set the preferred activity
  run_or_echo adb_shell "$serial" "cmd role add-role-holder android.app.role.BROWSER $browser_pkg"
}

# ── Disable heads-up notifications ───────────────────────
system_disable_heads_up() {
  local serial="${1:-}"
  info "Disabling heads-up notifications"
  run_or_echo adb_shell "$serial" "settings put global heads_up_notifications_enabled 0"
}

# ── Set screen timeout (seconds) ─────────────────────────
system_set_screen_timeout() {
  local serial="${1:-}" timeout="${2:-120}"
  info "Setting screen timeout to ${timeout}s"
  run_or_echo adb_shell "$serial" "settings put system screen_off_timeout $((timeout * 1000))"
}

# ── Set stay awake while charging ────────────────────────
system_set_stay_awake() {
  local serial="${1:-}"
  info "Enabling stay awake while charging"
  run_or_echo adb_shell "$serial" "settings put global stay_on_while_plugged_in 3"
}

# ── Grant all runtime permissions to an app ──────────────
system_grant_all_permissions() {
  local serial="${1:-}" pkg="$2"
  info "Granting all permissions to $pkg"
  local perms
  perms=$(adb_shell "$serial" "pm dump $pkg" 2>/dev/null | grep "permission" | grep "android" | awk '{print $1}')
  while IFS= read -r perm; do
    [[ -z "$perm" ]] && continue
    run_or_echo adb_shell "$serial" "pm grant $pkg $perm" 2>/dev/null
  done <<< "$perms"
}
