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
- CI and local development now share Makefile entrypoints for linting, tests,
  precommit checks, and Android APK builds.
- Snapshots now include fidelity-compatible GPS and Android Wi-Fi observations.
- Android 13+ Wi-Fi observations now request the `NEARBY_WIFI_DEVICES`
  permission instead of silently returning empty scan results.
- Snapshot queueing is FIFO and fidelity enrichment is serialized, so async
  Wi-Fi collection cannot reorder GPS snapshots.
- Failed transient sends are persisted to SQLite and replayed after restarts.
- Stored snapshot replay drops malformed SQLite payload rows and continues with
  the next row instead of letting one bad row block all offline replay.
- MQTT remote logs are disabled by default and configurable through
  `--dart-define` instead of using a hard-coded public broker.
- The committed `device.crt`, `client.key`, and `ca.pem` app assets were
  removed from the package.
- Backend and OpenID token endpoints are build-time configuration, not Kontur
  runtime defaults.
- Android and iOS package identifiers now use Maumaps identifiers.
- Android release signing supports a Maumaps keystore through Gradle
  properties or environment variables; debug release signing must be requested
  explicitly for non-production CI/dev artifacts.
- Dart analyzer strict mode is enabled and the existing JSON/parsing typing
  issues were cleaned up.
- Android fidelity collection now includes Wi-Fi, cell towers, and a short BLE
  beacon scan with explicit runtime permission handling.

## Still open

- Validate Android Wi-Fi, BLE, and cell tower collection on real field devices
  before treating the radio payload quality as production-calibrated.
