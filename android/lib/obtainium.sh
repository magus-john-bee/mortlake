#!/usr/bin/env bash
# lib/obtainium.sh -- Obtainium JSON export generation and bootstrap
# Sourced by provision.sh, not run directly.

OBTAINIUM_DIR="/tmp/phone-provision-obtainium"

# ── Bootstrap: install Obtainium itself via ADB ───────────
obtainium_install_bootstrap() {
  local app_id="$1" url="$2" name="$3"

  if is_installed "${DEVICE_SERIAL:-}" "$app_id"; then
    info "$name already installed, skipping."
    return
  fi

  info "Downloading $name from $url"
  local apk_url arch apk_file

  # Determine architecture
  arch=$(adb_shell "${DEVICE_SERIAL:-}" "getprop ro.product.cpu.abi" 2>/dev/null || echo "arm64-v8a")
  case "$arch" in
    arm64-v8a)  arch="arm64-v8a" ;;
    armeabi-v7a) arch="armeabi-v7a" ;;
    x86_64)     arch="x86_64" ;;
    *)          arch="arm64-v8a" ;;  # default
  esac

  mkdir -p "$OBTAINIUM_DIR"

  # Fetch latest release info from GitHub API
  local repo
  repo=$(echo "$url" | sed 's|https://github.com/||')
  local release_json
  release_json=$(curl -sL "https://api.github.com/repos/$repo/releases/latest")

  # Find matching APK
  apk_url=$(echo "$release_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for asset in data.get('assets', []):
    name = asset['name'].lower()
    if name.endswith('.apk') and '$arch' in name and 'fdroid' not in name:
        print(asset['browser_download_url'])
        break
" 2>/dev/null)

  if [[ -z "$apk_url" ]]; then
    # Fallback: just grab the generic APK
    apk_url=$(echo "$release_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for asset in data.get('assets', []):
    name = asset['name'].lower()
    if name.endswith('.apk') and not any(x in name for x in ['fdroid', '.idsig', '.sha256']):
        print(asset['browser_download_url'])
        break
" 2>/dev/null)
  fi

  if [[ -z "$apk_url" ]]; then
    error "Could not find APK for $name at $url"
    return 1
  fi

  apk_file="$OBTAINIUM_DIR/${app_id}.apk"
  info "Downloading $apk_url"
  run_or_echo curl -L -o "$apk_file" "$apk_url"

  if [[ "$DRY_RUN" != "true" ]]; then
    if [[ -f "$apk_file" ]]; then
      info "Installing $name via ADB"
      adb_shell "${DEVICE_SERIAL:-}" "pm install -r $(basename "$apk_file")" 2>&1 || \
        run_or_echo adb install -r "$apk_file"
    fi
  else
    echo "  [dry-run] would install $apk_file"
  fi
}

# ── Generate Obtainium JSON export from profile ──────────
obtainium_generate_export() {
  local profile="$1" output="$2"

  info "Generating Obtainium export JSON"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] would generate $output"
    return
  fi

  python3 -c "
import yaml, json, sys

with open('$profile') as f:
    data = yaml.safe_load(f)

apps = []
for app in data.get('obtainium', []):
    # Skip bootstrap apps (already installed)
    if app.get('bootstrap'):
        continue
    entry = {
        'id': app['id'],
        'url': app['url'],
        'author': app.get('author', ''),
        'name': app.get('name', app['id']),
        'installedVersion': None,
        'latestVersion': '',
        'apkUrls': '[]',
        'otherAssetUrls': '[]',
        'preferredApkIndex': 0,
        'additionalSettings': json.dumps({
            'trackOnly': False,
            'versionDetection': True,
            'autoApkFilterByArch': True,
            'exemptFromBackgroundUpdates': False,
            'skipUpdateNotifications': False,
        }),
        'lastUpdateCheck': 0,
        'pinned': False,
        'categories': [app.get('category', '')] if app.get('category') else [],
        'releaseDate': None,
        'changeLog': '',
        'overrideSource': None,
    }
    apps.append(entry)

export = {'apps': apps}
with open('$output', 'w') as f:
    json.dump(export, f, indent=2)

print(f'  Generated export with {len(apps)} apps')
"
}

# ── Push Obtainium export to device ──────────────────────
obtainium_push_export() {
  local json_file="$1" serial="${2:-}"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] would push $json_file to /sdcard/Download/"
    return
  fi

  if [[ ! -f "$json_file" ]]; then
    error "Export file not found: $json_file"
    return 1
  fi

  info "Pushing Obtainium export to device"
  adb_shell "$serial" "mkdir -p /sdcard/Download" 2>/dev/null
  if [[ -n "$serial" ]]; then
    adb -s "$serial" push "$json_file" /sdcard/Download/obtainium-export.json
  else
    adb push "$json_file" /sdcard/Download/obtainium-export.json
  fi
  info "Export pushed to /sdcard/Download/obtainium-export.json"
}
