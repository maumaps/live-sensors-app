# Maumaps Live Sensors App

Flutter application for collecting mobile GPS and motion sensor snapshots and
sending them to the live-sensor backend.

This repository is the Maumaps fork of
[`konturio/live-sensors-app`](https://github.com/konturio/live-sensors-app).
The Android/iOS package identifiers use Maumaps IDs; legacy Kontur backend
compatibility must be supplied explicitly through build-time configuration.

## Development

### Dev container 
This project have config for [vscode dev container](https://code.visualstudio.com/docs/devcontainers/containers)
So in case you open project in vscode and you have docker installed in system - you just run command `Dev containers: reopen in dev container` command to get all dev environment
> Note: If you use podman an additional configuration may required
> https://jahed.dev/2023/05/27/remote-development-with-vs-code-podman/


### Devbox 
Another options is using [devbox](https://github.com/jetpack-io/devbox) tool for install unnecessary environment
```
devbox install
```

### Scripts
Repository have set of scripts that helps build, test, and release app.

## Build

```
flutter pub get
make precommit
LIVE_SENSORS_API_URL=https://example.test/live-sensor \
LIVE_SENSORS_OPENID_TOKEN_URL=https://example.test/token \
LIVE_SENSORS_OPENID_CLIENT_ID=maumaps_live_sensors \
  make build-apk
```

`./scripts/build.sh` creates
`releases/live-sensors-<version>-release.apk`.
For tagged builds the version comes from the tag name.
For local builds it comes from `git describe`.

Runtime endpoints are required build configuration:

```
flutter build apk --release \
  --dart-define=LIVE_SENSORS_API_URL=https://example.test/live-sensor \
  --dart-define=LIVE_SENSORS_OPENID_TOKEN_URL=https://example.test/token \
  --dart-define=LIVE_SENSORS_OPENID_CLIENT_ID=maumaps_live_sensors
```

Remote MQTT app logs are disabled unless
`LIVE_SENSORS_MQTT_LOGS_ENABLED=true` and `LIVE_SENSORS_MQTT_ENDPOINT` are
provided.

## Continuous integration

GitHub Actions runs formatting, analysis, tests, and Android release APK build
on pull requests, pushes to `main`, and version tags.
Tagged builds also publish the APK as a GitHub release asset.
CI calls the same `make precommit` and `make build-apk` targets used locally.

See [docs/ci.md](docs/ci.md) for details.

## Useful links
- [Remote debugging on real device](https://dev.to/petrussola/how-to-debug-flutter-app-with-real-android-phone-693)
- [Use a native language debugger](https://docs.flutter.dev/testing/native-debugging)


## Architecture
All top level logic described in `/main/controller.dart` module

### Initialization stage
When app boots it tries to recover the previous user session.
If stored tokens can be refreshed, the app goes to `setup` stage.
If the auth server is unavailable, the app keeps the restored session and works
in a degraded offline mode until refresh succeeds later.
Only a confirmed refresh-token rejection clears the session.
If there is no stored session, the user is redirected to the login screen, and
`setup` runs after successful login.

### Setup stage
During the installation process, the program requests the necessary accesses, instantiates the services

### Http client

- ApiClient - describe backend api
  - OpenIdClient - handle auth logic - login / logout / handle 401 errors / keep tokens fresh
    -  OpenIdApi - describe auth api

### Snapshot

Contain all sensors records during period of time


### Tracker 

- Listens to sensors and fills snapshots with sensor data
- listens to gps channel and create new snapshot on every position change
- enriches finalized snapshots with fidelity-compatible GPS, Wi-Fi, cell tower,
  and BLE observations when the platform exposes radio scan results
- Adding new snapshots to `queue`

### Sender

Sending snapshots from `queue` to backend


### Dataflow
```
Sensors + GPS ---(data)--> Tracker ---(Snapshot)--> Queue --> Sender --> Client --> Backend
```

See [docs/fidelity-observations.md](docs/fidelity-observations.md) for the
radio observation payload shape.
See [docs/application-flow.md](docs/application-flow.md) for a fuller
contributor-oriented walkthrough of startup, login, tracking, sending, offline
replay, and mobile permissions.

## Current backlog

See [docs/todo.md](docs/todo.md) for issues found while taking over the fork.
