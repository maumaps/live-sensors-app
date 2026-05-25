# Fidelity observations

Snapshots include a fidelity-compatible radio observation block when Android
exposes nearby radio data.

The block is written into GeoJSON feature properties as:

- `fidelity`: local sensor-state shape used by
  [`Komzpa/fidelity`](https://github.com/Komzpa/fidelity) observation logs:
  `gps` plus `wifi`, `cell`, and `bluetooth` rows.
- `fidelityGeolocate`: Ichnaea/MLS-compatible request shape accepted by
  fidelity's `/v1/geolocate` endpoint:
  `wifiAccessPoints`, `cellTowers`, `bluetoothBeacons`, `considerIp: false`,
  and `fallbacks.ipf: false`.

Android collection uses a Flutter method channel backed by `WifiManager`.
The app already requests fine location for GPS tracking; Android also requires
Wi-Fi state access before scan results can be read.
On Android 13 and newer it also requests the `NEARBY_WIFI_DEVICES` runtime
permission before reading nearby access points.
Access points whose SSID ends with `_nomap` are skipped before payload emission,
matching the MLS opt-out convention.

Cell tower collection uses `TelephonyManager.allCellInfo` and requires location
permission on modern Android versions.

BLE beacon collection runs a short low-latency scan before the snapshot is
queued. On Android 12 and newer the app requests `BLUETOOTH_SCAN`; older
versions use the same location permission gate as Wi-Fi scans.

If radio access is denied or unavailable, the snapshot is still sent with GPS
and motion data and empty radio lists.
