# Continuous integration

GitHub Actions workflow: `.github/workflows/android-release.yml`.

The workflow has two jobs:

- `verify` installs Flutter `3.13.1`, runs `flutter pub get`, checks
  `dart format`, runs `flutter analyze`, and runs `flutter test`.
- `android` depends on `verify`, builds the release APK through
  `./scripts/build.sh`, uploads the APK as a workflow artifact, and publishes a
  GitHub release asset for `v*.*.*` tags.

The release APK is signed with the debug signing config inherited from the
current Flutter project.
That preserves the existing behavior, but it is not suitable for production app
store distribution.
Use a proper Android signing key before publishing outside internal testing.

The workflow intentionally uses the same Flutter version as the existing
devcontainer so local, container, and CI builds agree.
