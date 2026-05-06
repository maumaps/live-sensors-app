#!/bin/bash
set -euo pipefail

version="${GITHUB_REF_NAME:-}"
if [[ -z "${version}" ]]; then
  version="$(git describe --tags --exact-match 2>/dev/null || git describe --tags --always --dirty)"
fi
version="$(printf '%s' "${version}" | tr -c '[:alnum:]._+-' '-')"

dart_defines=()

required_define() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "${value}" ]]; then
    echo "Missing required ${name}; provide it as an environment variable." >&2
    exit 1
  fi
  dart_defines+=("--dart-define=${name}=${value}")
}

optional_define() {
  local name="$1"
  local value="${!name:-}"
  if [[ -n "${value}" ]]; then
    dart_defines+=("--dart-define=${name}=${value}")
  fi
}

required_define LIVE_SENSORS_API_URL
required_define LIVE_SENSORS_OPENID_TOKEN_URL
required_define LIVE_SENSORS_OPENID_CLIENT_ID
optional_define LIVE_SENSORS_MQTT_LOGS_ENABLED
optional_define LIVE_SENSORS_MQTT_ENDPOINT
optional_define LIVE_SENSORS_MQTT_PORT
optional_define LIVE_SENSORS_MQTT_TOPIC

flutter build apk --release "${dart_defines[@]}"

mkdir -p ./releases
cp ./build/app/outputs/flutter-apk/app-release.apk \
  "./releases/live-sensors-${version}-release.apk"
