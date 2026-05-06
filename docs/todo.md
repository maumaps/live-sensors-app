# Maintainer backlog

Issues found while taking over the Maumaps fork.

## Fixed in the initial Maumaps pass

- Offline auth no longer clears the stored session on transport failure.
  `invalid_grant` remains the only refresh failure that logs the user out.
- Access-token refresh now returns and clears the shared refresh future instead
  of leaving callers with `null` or a stale completed future.
- Startup refresh now saves the refreshed tokens instead of re-saving the old
  restored tokens.
- Empty stored sessions can be parsed without crashing.
- MQTT logging no longer mutates the pending queue during iteration and no
  longer assumes `connectionStatus` is always non-null while offline.
- CI now runs format, analyzer, tests, and Android APK build.

## Still open

- Snapshot storage is stubbed out.
  `Sender.sendSnapshotsFromStorage()` is disabled, so app restarts can lose
  queued sensor snapshots.
  This is the next important offline reliability fix.
- MQTT logging uses a hard-coded public broker endpoint and unauthenticated
  port `1883`.
  Decide whether Maumaps still needs remote MQTT app logs, then move endpoint
  and credentials into build-time configuration.
- `device.crt`, `client.key`, and `ca.pem` are committed and packaged as app
  assets.
  Audit whether they are test credentials, rotate them if they were ever real,
  and replace the pattern with environment-specific provisioning.
- Backend and Keycloak URLs are hard-coded to Kontur infrastructure.
  Maumaps deployments should use flavor or build-time configuration before any
  public release.
- The Android release build still uses the debug signing config.
  Configure a real signing key before distributing production APKs.
- Android and iOS package identifiers still use `kontur.io.*`.
  Keep them only if upgrade compatibility with existing installs is required;
  otherwise migrate to Maumaps identifiers deliberately.
- `Tracker.track()` can create new subscriptions if `start()` is called more
  than once without a prior `stop()`.
  Guard repeated starts or make tracking lifecycle idempotent.
