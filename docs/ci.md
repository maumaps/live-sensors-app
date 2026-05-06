# Continuous integration

GitHub Actions workflow: `.github/workflows/android-release.yml`.

The local verification entrypoints are:

- `make lint`: format check plus analyzer/lints.
- `make test`: Flutter tests.
- `make precommit`: lint plus tests.
- `make build-apk`: Android release APK build.
- `make verify`: precommit plus Android release APK build.

The workflow has two jobs:

- `verify` installs Flutter `3.13.1` and runs `make precommit`.
- `android` depends on `verify`, builds the release APK through
  `make build-apk`, uploads the APK as a workflow artifact, and publishes a
  GitHub release asset for `v*.*.*` tags.

Analyzer configuration lives in `analysis_options.yaml`.
It promotes dead code plus unused imports/locals to errors and enables a small
set of style lints that the current codebase can satisfy consistently.

The release APK is signed with the debug signing config inherited from the
current Flutter project.
That preserves the existing behavior, but it is not suitable for production app
store distribution.
Use a proper Android signing key before publishing outside internal testing.

The workflow intentionally uses the same Flutter version as the existing
devcontainer so local, container, and CI builds agree.
