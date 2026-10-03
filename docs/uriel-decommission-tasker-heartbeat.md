# Uriel decommission: phone-based heartbeat (Tasker)

Plan: 2026-10-01 (Hermes session, Discord). Status: DRAFT — not executed.
Context: uriel (cloud) being dropped; services move to jehoel. Always-on gap
covered by a phone heartbeat instead of a rented outpost box. See also:
nixos-anywhere outpost idea (deferred — phone makes it unnecessary for the
"house is dark" use case).

## Goal

Phone probes the public edge of jehoel over CELL DATA and notifies locally when
the home network is unreachable from outside. Catches the failure class
"outbound fine, inbound broken" (router reset to defaults, stale ddclient IP,
lost port-forward) — which jehoel-side or dead-man-switch monitoring cannot
see.

## Tasker profile (GrapheneOS Pixel 9 Pro)

1. **Profile: Time** — every 15 min (Tasker "Repeat" interval).
2. **Task: Heartbeat**, steps:
   - A1 **HTTP Request** (Tasker built-in, no plugin needed):
     - Method GET, URL `https://jellyfin.otwell.dev` (the lightest real vhost;
       any 2xx/3xx/4xx HTTP response = edge reachable — we care about TCP+TLS
       reachability, not content)
     - Timeout ~15s; on connection failure set local var `%err`
     - Optional second probe: `https://sb.otwell.dev` (second vhost confirms
       nginx/ACME health, not just one app)
   - A2 **If** `%err` set AND %previously_failed (global var) set:
     - A2.1 **Notify**: "jehoel unreachable over cell — 2 consecutive failures.
       Check router / ddclient / port-forwards."
   - A3 **Else If** `%err` set (first failure):
     - A3.1 **Variable Set** `%previously_failed` = true
   - A4 **Else**:
     - A4.1 **Variable Clear** `%previously_failed`
3. Force mobile data for the probe (else Wi-Fi probe would test the LAN, not
   the edge). Options, in order of preference:
   - Tasker "Mobile Data" action BEFORE the request + restore after (simplest),
   - or Tasker network binding via Java function if the simple action
     misbehaves (ask Hermes to generate the Java snippet),
   - or accept Wi-Fi+cell failover since Android marks no-internet Wi-Fi as
     validated=false and routes around it (weakest, but free).
4. Exempt the Tasker profile from battery optimization (Settings → Apps →
   Tasker → Battery → Unrestricted) or the 15-min timer will drift under Doze.

## Alert semantics

- 2 consecutive failures over cell → local notification. Threshold prevents
  single flaky-LTE-bar false positives.
- Recovery is implicit: next success clears `%previously_failed`; optionally
  add a "recovered" notify on the success-after-failure transition.
5. No outbound dependency on jehoel itself; nothing to deploy on jehoel; zero
  infra. Phone is on a different power AND network path (LTE vs home ISP).

## Limitations (accepted)

- No diagnosis vantage: when the alert fires, debugging happens from the
  phone. The nixos-anywhere outpost (public flake, jbotwell account, generic
  KVM disko profile, canary-only listening posture) remains the upgrade path
  if outages turn out to be frequent.
- 15-min granularity; a brief outage shorter than the interval is invisible.
- Tasker is a paid app (~$3.49); already-owned? If not, alternatives:
  Termux + termux-job-scheduler + termux-notifier (free, needs boot + battery
  exemptions), or automate via Lightning Wall/QuickEdit variants.

## Migration checklist (uriel → jehoel), pre-cancel

- [ ] Stand up silverbullet, taskdog, ebay-deletion vhosts on jehoel (nginx +
      ACME per-vhost; same pattern as jellyfin/transmission)
- [ ] Flip DNS for sb/taskdog/ebay-deletion to jehoel
- [ ] Verify Syncthing converges the vault (space /home/john/vault/sb)
- [ ] Migrate Hermes state: hermes-state-sync skill, uriel → jehoel (.hermes
      dir; cron jobs ride along — trash Tue 8AM etc.)
- [ ] Verify cron jobs fire on jehoel schedule
- [ ] Remove uriel host key from jehoel john.nix authorized keys (mortlake)
- [ ] Point the heartbeat at jehoel vhosts (above), run it for a week BEFORE
      canceling uriel — overlap proves the alert path end-to-end
- [ ] Cancel uriel billing
