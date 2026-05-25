# Continuous integration

GitHub Actions workflow: `.github/workflows/android-release.yml`.

The local verification entrypoints are:

- `make lint`: format check plus analyzer/lints.
- `make test`: Flutter tests.
- `make precommit`: lint plus tests.
- `make build-apk`: Android release APK build.
- `make verify`: precommit plus Android release APK build.

`make build-apk` requires the same endpoint configuration as the app runtime:

```
LIVE_SENSORS_API_URL=https://example.test/live-sensor
LIVE_SENSORS_OPENID_TOKEN_URL=https://example.test/token
LIVE_SENSORS_OPENID_CLIENT_ID=maumaps_live_sensors
```

The workflow has two jobs:

- `verify` installs Flutter `3.13.1` and runs `make precommit`.
- `android` depends on `verify`, builds the release APK through
  `make build-apk`, uploads the APK as a workflow artifact, and publishes a
  GitHub release asset for `v*.*.*` tags.
  The build job passes required `LIVE_SENSORS_*` Dart defines from repository
  variables, with explicit placeholder values for non-production CI artifacts.

Analyzer configuration lives in `analysis_options.yaml`.
It promotes dead code plus unused imports/locals to errors and enables a small
set of style lints that the current codebase can satisfy consistently.
Strict casts, inference, and raw type checks are enabled so JSON and platform
channel payloads stay typed at their boundaries.

Production release signing is configured through either `local.properties`:

```
maumaps.releaseStoreFile=/path/to/release.keystore
maumaps.releaseStorePassword=...
maumaps.releaseKeyAlias=...
maumaps.releaseKeyPassword=...
```

or environment variables:

```
MAUMAPS_ANDROID_KEYSTORE=/path/to/release.keystore
MAUMAPS_ANDROID_KEYSTORE_PASSWORD=...
MAUMAPS_ANDROID_KEY_ALIAS=...
MAUMAPS_ANDROID_KEY_PASSWORD=...
```

CI sets `MAUMAPS_ALLOW_DEBUG_RELEASE_SIGNING=true` only for non-production APK
artifacts. Production builds should not set that variable.

The workflow intentionally uses the same Flutter version as the existing
devcontainer so local, container, and CI builds agree.
