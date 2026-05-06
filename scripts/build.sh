#!/bin/bash
set -euo pipefail

version="${GITHUB_REF_NAME:-}"
if [[ -z "${version}" ]]; then
  version="$(git describe --tags --exact-match 2>/dev/null || git describe --tags --always --dirty)"
fi

flutter build apk --release

mkdir -p ./releases
cp ./build/app/outputs/flutter-apk/app-release.apk \
  "./releases/live-sensors-${version}-release.apk"
