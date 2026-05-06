# Application flow

This document is the starting point for discussing the mobile app behavior with
new contributors.

## Runtime configuration

The Maumaps fork does not ship backend defaults. Every runnable build must
provide:

```sh
--dart-define=LIVE_SENSORS_API_URL=https://example.test/live-sensor
--dart-define=LIVE_SENSORS_OPENID_TOKEN_URL=https://example.test/token
--dart-define=LIVE_SENSORS_OPENID_CLIENT_ID=maumaps_live_sensors
```

Remote MQTT logs are opt-in. They stay disabled unless
`LIVE_SENSORS_MQTT_LOGS_ENABLED=true` and a log broker endpoint are provided.

## Startup

`AppController.init()` is the top-level boot path:

1. Initialize logging and SQLite snapshot storage.
2. Build the OpenID client from configured token endpoint and client ID.
3. Build the authenticated API client.
4. Restore the latest secure-storage session, when one exists.
5. Try to refresh the restored refresh token.
6. Mark the app booted so the UI can show either login or tracking state.

If token refresh succeeds, the app continues as an authorized session. If the
auth backend is temporarily unavailable, the restored session is kept and the
app starts in degraded offline mode. Only a confirmed refresh-token rejection
logs the user out. See [offline-auth.md](offline-auth.md).

## Login and setup

Password login goes through `OpenIdClient.loginByPassword()`.
After login or successful session restore, `_postLogin()`:

1. Marks the app authorized.
2. Requests GPS and radio permissions.
3. Wires `Sender` to the backend API, in-memory queue, and SQLite storage.
4. Initializes the user-agent string.
5. Wires `Tracker` to sensors, GPS positions, queue, and the fidelity collector.
6. Starts tracking and sending.

The app currently expects location permission for normal operation. Android
radio enrichment also asks for nearby Wi-Fi and Bluetooth scan permissions on
newer Android versions.

## Tracking

`Tracker.track()` listens to two streams:

- motion sensor samples are appended to the currently open `Snapshot`;
- each GPS position seals the current snapshot, starts a new one, and queues the
  sealed snapshot after optional radio enrichment.

Radio enrichment is serialized so slower Wi-Fi/BLE/cell collection cannot
reorder GPS snapshots. If tracking is stopped while enrichment is still in
flight, the old snapshot is dropped instead of being reintroduced after
teardown. A quick stop/start increments a run generation so old asynchronous
work cannot leak into the new session.

## Sending and offline replay

`Sender.run()` starts two loops:

- `sendSnapshotsFromQueue()` sends live in-memory snapshots to the backend.
- `sendSnapshotsFromStorage()` replays snapshots previously written to SQLite.

Live snapshots are removed from the queue only after either successful send,
backend `400 Bad Request`, or successful persistence for replay. If persistence
fails, the snapshot remains in memory and the queue loop stays alive.

Stored snapshots are replayed FIFO by `created_at` and `id`. Bad request drops
the stored row. Temporary send failures leave the row for later retry. Malformed
stored payloads are logged, deleted, and skipped so one bad row cannot block the
whole offline backlog. Stored rows are replayed only for the current
authenticated user; rows from another user are dropped before upload so offline
data cannot leak across logout/login cycles on the same device.

## Stop, pause, and logout

`pause()` stops adding sensor data to new snapshots but keeps the tracker object
wired.

`stop()` disposes tracker subscriptions, clears the in-memory queue, and stops
sender loops. Stored SQLite snapshots are not cleared by stop, so offline replay
can continue in a later valid session.

`logout()` clears OpenID tokens, stops the refresh cycle, drops secure-storage
session data, then stops tracking.

## Fidelity payloads

Finalized snapshots can include a fidelity-compatible radio block with GPS,
Wi-Fi access points, cell towers, and BLE beacons. The same data is exposed in a
local compact shape and an Ichnaea/MLS-style geolocate shape.

Android skips Wi-Fi networks whose SSID ends with `_nomap`, matching the MLS
opt-out convention.

See [fidelity-observations.md](fidelity-observations.md) for payload details.

## Contributor call checklist

Use this checklist before a handoff or troubleshooting call:

- Confirm which backend URL, token URL, and OpenID client ID the local build
  uses.
- Confirm whether the user is testing online startup, offline startup, or
  offline replay after reconnect.
- Confirm whether tracking problems are GPS permission, radio permission,
  snapshot creation, queue sending, or stored replay.
- For Android radio issues, capture Android version, granted permissions, and
  whether Wi-Fi/cell/BLE rows are expected on that device.
- For build issues, compare the local command with `make precommit`,
  `make build-apk`, and the GitHub Actions run described in [ci.md](ci.md).
