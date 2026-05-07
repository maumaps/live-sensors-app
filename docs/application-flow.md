# Application flow

This document is the starting point for discussing the mobile app behavior with
new contributors.

## Startup

`AppController.init()` is the top-level boot path:

1. Initialize logging.
2. Build the OpenID client from the configured token endpoint.
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
2. Requests GPS permission.
3. Wires `Sender` to the backend API, in-memory queue, and storage object.
4. Initializes the user-agent string.
5. Wires `Tracker` to sensors, GPS positions, and queue.
6. Starts tracking and sending.

The app currently expects location permission for normal operation.

## Tracking

`Tracker.track()` listens to two streams:

- motion sensor samples are appended to the currently open `Snapshot`;
- each GPS position seals the current snapshot, starts a new one, and queues the
  sealed snapshot.

## Sending and offline replay

`Sender.run()` starts two loops:

- `sendSnapshotsFromQueue()` sends live in-memory snapshots to the backend.
- `sendSnapshotsFromStorage()` is present but currently disabled.

The current `main` branch still has persistent snapshot replay in the
maintainer backlog. See [todo.md](todo.md) before relying on offline replay
after app restart.

## Stop, pause, and logout

`pause()` stops adding sensor data to new snapshots but keeps the tracker object
wired.

`stop()` disposes tracker subscriptions, clears the in-memory queue, and stops
sender loops.

`logout()` clears OpenID tokens, stops the refresh cycle, drops secure-storage
session data, then stops tracking.

## Contributor call checklist

Use this checklist before a handoff or troubleshooting call:

- Confirm which backend URL and token URL the local build uses.
- Confirm whether the user is testing online startup, offline startup, or
  offline behavior after reconnect.
- Confirm whether tracking problems are GPS permission, snapshot creation,
  queue sending, or disabled stored replay.
- For build issues, compare the local command with `make precommit`,
  `make build-apk`, and the GitHub Actions run described in [ci.md](ci.md).

