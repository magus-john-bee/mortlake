#!/usr/bin/env bash
# provision-hetzner — create (or reuse) a Hetzner Cloud VPS and provision it
# from scratch with nixos-anywhere + disko.
#
# This is the zero-UI path: hcloud CLI creates the server, nixos-anywhere
# kexec-bootstraps it, disko partitions it, and the flake config installs.
# The temporary base image (Ubuntu) only exists to provide an SSH endpoint
# for kexec — it's wiped during install.
#
# Prerequisites:
#   - HCLOUD_TOKEN env var (Hetzner Cloud API token, project-scoped)
#   - hcloud CLI available in PATH (or run via nix run .#provision-hetzner)
#   - SSH key registered in Hetzner Cloud (referenced by --ssh-key-id)
#   - Run from the mortlake repo root
#
# Usage:
#   HCLOUD_TOKEN=xxx nix run .#provision-hetzner -- uriel
#   HCLOUD_TOKEN=xxx nix run .#provision-hetzner -- uriel --server-type cx22
#   HCLOUD_TOKEN=xxx nix run .#provision-hetzner -- uriel --reinstall
#
# Flags:
#   --server-type <type>   Hetzner server type (default: cx22)
#   --ssh-key-id <id>      Name or ID of SSH key in Hetzner Cloud (default: john)
#   --image <image>        Base image for kexec (default: ubuntu-24.04)
#   --reinstall            Destroy existing server and recreate (DESTRUCTIVE)
#   --location <loc>       Hetzner location (default: ash — Ashburn, VA)
#   --extra-args <args>    Extra args passed to nixos-anywhere
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────
SERVER_TYPE="cx22"
SSH_KEY_ID="john"
IMAGE="ubuntu-24.04"
LOCATION="ash"
REINSTALL=false
EXTRA_ARGS=""

# ── Parse args ────────────────────────────────────────────────────────
HOST="${1:?Usage: provision-hetzner <hostname> [options]}"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server-type)  SERVER_TYPE="$2";  shift 2 ;;
    --ssh-key-id)   SSH_KEY_ID="$2";   shift 2 ;;
    --image)        IMAGE="$2";        shift 2 ;;
    --location)     LOCATION="$2";     shift 2 ;;
    --reinstall)    REINSTALL=true;    shift ;;
    --extra-args)   EXTRA_ARGS="$2";   shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ──────────────────────────────────────────────────────────
if [[ -z "${HCLOUD_TOKEN:-}" ]]; then
  echo "Error: HCLOUD_TOKEN env var is required" >&2
  echo "Create one at https://console.hetzner.cloud (project → API Tokens)" >&2
  exit 1
fi

export HCLOUD_TOKEN

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# ─-- Check if server already exists ───────────────────────────────────
SERVER_IP=$(hcloud server ip "$HOST" 2>/dev/null || true)

if [[ -n "$SERVER_IP" ]]; then
  if $REINSTALL; then
    echo "⟩ Destroying existing server '$HOST'..."
    hcloud server delete "$HOST"
    SERVER_IP=""
  else
    echo "⟩ Server '$HOST' already exists at $SERVER_IP"
    echo "  Use --reinstall to destroy and recreate"
    exit 0
  fi
fi

# ── Create server ─────────────────────────────────────────────────────
if [[ -z "$SERVER_IP" ]]; then
  echo "⟩ Creating server '$HOST' ($SERVER_TYPE, $LOCATION)..."
  hcloud server create \
    --name "$HOST" \
    --type "$SERVER_TYPE" \
    --image "$IMAGE" \
    --location "$LOCATION" \
    --ssh-key "$SSH_KEY_ID"

  SERVER_IP=$(hcloud server ip "$HOST")
  echo "⟩ Server created at $SERVER_IP"
fi

# ── Wait for SSH ──────────────────────────────────────────────────────
echo "⟩ Waiting for SSH on root@$SERVER_IP..."
for i in $(seq 1 30); do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@$SERVER_IP" true 2>/dev/null; then
    echo "⟩ SSH connected"
    break
  fi
  echo "  attempt $i/30..."
  sleep 5
done

# ── Run nixos-anywhere ────────────────────────────────────────────────
echo "⟩ Provisioning $HOST with nixos-anywhere..."
# EXTRA_ARGS is intentionally word-split: it carries multiple complete
# flags (e.g. '--kexec --debug'), not a single value. Quoting would
# pass them as one argument.
# shellcheck disable=SC2086
exec nix run github:nix-community/nixos-anywhere -- \
  --flake ".#$HOST" \
  --target-host "root@$SERVER_IP" \
  --ssh-option StrictHostKeyChecking=no \
  $EXTRA_ARGS
