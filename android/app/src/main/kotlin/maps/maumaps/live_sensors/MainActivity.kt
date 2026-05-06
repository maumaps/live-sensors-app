package maps.maumaps.live_sensors

import android.annotation.SuppressLint
import android.Manifest
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult as BleScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.telephony.CellIdentityCdma
import android.telephony.CellIdentityGsm
import android.telephony.CellIdentityLte
import android.telephony.CellIdentityNr
import android.telephony.CellIdentityWcdma
import android.telephony.CellInfo
import android.telephony.CellInfoCdma
import android.telephony.CellInfoGsm
import android.telephony.CellInfoLte
import android.telephony.CellInfoNr
import android.telephony.CellInfoWcdma
import android.telephony.CellSignalStrength
import android.telephony.TelephonyManager
import android.net.wifi.ScanResult
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity: FlutterActivity() {
    private val radioPermissionRequestCode = 4201

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "live_sensors/fidelity"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestRadioPermissions" -> {
                    requestMissingRadioPermissions()
                    result.success(true)
                }
                "getRadioFingerprint" -> collectRadioFingerprint { fingerprint ->
                    result.success(fingerprint)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun collectRadioFingerprint(callback: (Map<String, Any>) -> Unit) {
        val collectedAt = System.currentTimeMillis()
        val wifiAccessPoints = collectWifiAccessPoints()
        val cellTowers = collectCellTowers()

        collectBluetoothBeacons { bluetoothBeacons ->
            callback(
                mapOf(
                    "collectedAt" to collectedAt,
                    "wifiAccessPoints" to wifiAccessPoints,
                    "cellTowers" to cellTowers,
                    "bluetoothBeacons" to bluetoothBeacons
                )
            )
        }
    }

    @SuppressLint("MissingPermission")
    private fun collectBluetoothBeacons(callback: (List<Map<String, Any>>) -> Unit) {
        if (!hasRequiredBluetoothPermissions()) {
            callback(emptyList())
            return
        }

        val scanner = (applicationContext.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)
            ?.adapter
            ?.bluetoothLeScanner

        if (scanner == null) {
            callback(emptyList())
            return
        }

        val beacons = linkedMapOf<String, Map<String, Any>>()
        var completed = false
        fun finish(rows: List<Map<String, Any>>) {
            if (completed) return
            completed = true
            callback(rows)
        }

        val scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: BleScanResult) {
                bluetoothBeacon(result)?.let { beacons[it["macAddress"] as String] = it }
            }

            override fun onBatchScanResults(results: MutableList<BleScanResult>) {
                results.mapNotNull(::bluetoothBeacon).forEach {
                    beacons[it["macAddress"] as String] = it
                }
            }

            override fun onScanFailed(errorCode: Int) {
                finish(emptyList())
            }
        }

        try {
            scanner.startScan(
                emptyList(),
                ScanSettings.Builder()
                    .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                    .build(),
                scanCallback
            )
        } catch (_: SecurityException) {
            callback(emptyList())
            return
        }

        Handler(Looper.getMainLooper()).postDelayed(
            {
                try {
                    scanner.stopScan(scanCallback)
                } catch (_: SecurityException) {
                    // Best effort stop; the app should still send the snapshot.
                }
                finish(beacons.values.toList())
            },
            2000
        )
    }

    private fun bluetoothBeacon(scanResult: BleScanResult): Map<String, Any>? {
        val address = scanResult.device?.address
            ?.takeUnless { it.isBlank() }
            ?: return null

        return mutableMapOf<String, Any>(
            "macAddress" to address.uppercase(Locale.US),
            "signalStrength" to scanResult.rssi
        ).apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                put("age", ((System.nanoTime() - scanResult.timestampNanos) / 1_000_000).toInt())
            }
        }
    }

    private fun collectCellTowers(): List<Map<String, Any>> {
        if (!hasLocationPermission()) {
            return emptyList()
        }

        val telephonyManager = applicationContext
            .getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return emptyList()

        return try {
            telephonyManager.allCellInfo
                ?.mapNotNull(::cellTower)
                ?.distinctBy {
                    listOf(
                        it["radioType"],
                        it["mobileCountryCode"],
                        it["mobileNetworkCode"],
                        it["locationAreaCode"],
                        it["cellId"],
                    )
                } ?: emptyList()
        } catch (_: SecurityException) {
            emptyList()
        }
    }

    private fun collectWifiAccessPoints(): List<Map<String, Any>> {
        if (!hasRequiredWifiPermissions()) {
            return emptyList()
        }

        val wifiManager = applicationContext
            .getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return emptyList()

        return try {
            wifiManager.scanResults
                .mapNotNull(::wifiAccessPoint)
                .distinctBy { it["macAddress"] }
        } catch (_: SecurityException) {
            emptyList()
        }
    }

    private fun requestMissingRadioPermissions() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val missingPermissions = mutableListOf<String>()
        if (!hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)) {
            missingPermissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            !hasPermission(Manifest.permission.NEARBY_WIFI_DEVICES)
        ) {
            missingPermissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        }
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !hasPermission(Manifest.permission.BLUETOOTH_SCAN)
        ) {
            missingPermissions.add(Manifest.permission.BLUETOOTH_SCAN)
        }

        if (missingPermissions.isNotEmpty()) {
            requestPermissions(
                missingPermissions.toTypedArray(),
                radioPermissionRequestCode
            )
        }
    }

    private fun hasRequiredWifiPermissions(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        if (!hasLocationPermission()) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            hasPermission(Manifest.permission.NEARBY_WIFI_DEVICES)
    }

    private fun hasRequiredBluetoothPermissions(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        if (!hasLocationPermission()) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            hasPermission(Manifest.permission.BLUETOOTH_SCAN)
    }

    private fun hasLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) ||
            hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
    }

    private fun hasPermission(permission: String): Boolean {
        return checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun wifiAccessPoint(scanResult: ScanResult): Map<String, Any>? {
        val ssid = scanResult.SSID
            ?.takeUnless { it.isBlank() }
        if (ssid?.endsWith("_nomap") == true) {
            return null
        }

        val bssid = scanResult.BSSID
            ?.takeUnless { it.isBlank() }
            ?.takeUnless { it == "02:00:00:00:00:00" }
            ?: return null

        return mutableMapOf<String, Any>(
            "macAddress" to bssid.uppercase(Locale.US),
            "signalStrength" to scanResult.level,
            "frequency" to scanResult.frequency
        ).apply {
            channelFromFrequency(scanResult.frequency)?.let { put("channel", it) }
            ssid?.let { put("ssid", it) }
        }
    }

    private fun cellTower(cellInfo: CellInfo): Map<String, Any>? {
        return when (cellInfo) {
            is CellInfoGsm -> gsmCell(cellInfo.cellIdentity, cellInfo.cellSignalStrength)
            is CellInfoWcdma -> wcdmaCell(cellInfo.cellIdentity, cellInfo.cellSignalStrength)
            is CellInfoLte -> lteCell(cellInfo.cellIdentity, cellInfo.cellSignalStrength)
            is CellInfoCdma -> cdmaCell(cellInfo.cellIdentity, cellInfo.cellSignalStrength)
            is CellInfoNr -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    nrCell(cellInfo.cellIdentity as CellIdentityNr, cellInfo.cellSignalStrength)
                } else {
                    null
                }
            }
            else -> null
        }
    }

    private fun gsmCell(
        identity: CellIdentityGsm,
        signalStrength: CellSignalStrength
    ): Map<String, Any>? {
        return cellMap("gsm", identity.mcc, identity.mnc, identity.lac, identity.cid).apply {
            putSignal(signalStrength)
            putValid("arfcn", identity.arfcn)
            putValid("bsic", identity.bsic)
        }.takeIf { it.hasRequiredCellIds() }
    }

    private fun wcdmaCell(
        identity: CellIdentityWcdma,
        signalStrength: CellSignalStrength
    ): Map<String, Any>? {
        return cellMap("wcdma", identity.mcc, identity.mnc, identity.lac, identity.cid).apply {
            putSignal(signalStrength)
            putValid("psc", identity.psc)
            putValid("uarfcn", identity.uarfcn)
        }.takeIf { it.hasRequiredCellIds() }
    }

    private fun lteCell(
        identity: CellIdentityLte,
        signalStrength: CellSignalStrength
    ): Map<String, Any>? {
        return cellMap("lte", identity.mcc, identity.mnc, identity.tac, identity.ci).apply {
            putSignal(signalStrength)
            putValid("pci", identity.pci)
            putValid("earfcn", identity.earfcn)
        }.takeIf { it.hasRequiredCellIds() }
    }

    private fun cdmaCell(
        identity: CellIdentityCdma,
        signalStrength: CellSignalStrength
    ): Map<String, Any>? {
        return mutableMapOf<String, Any>(
            "radioType" to "cdma",
            "cellId" to identity.basestationId
        ).apply {
            putSignal(signalStrength)
            putValid("locationAreaCode", identity.networkId)
            putValid("mobileNetworkCode", identity.systemId)
        }.takeIf { it["cellId"] != Int.MAX_VALUE }
    }

    private fun nrCell(
        identity: CellIdentityNr,
        signalStrength: CellSignalStrength
    ): Map<String, Any>? {
        return mutableMapOf<String, Any>(
            "radioType" to "nr",
            "mobileCountryCode" to identity.mccString.orEmpty(),
            "mobileNetworkCode" to identity.mncString.orEmpty(),
            "locationAreaCode" to identity.tac,
            "cellId" to identity.nci
        ).apply {
            putSignal(signalStrength)
            putValid("pci", identity.pci)
            putValid("nrarfcn", identity.nrarfcn)
        }.takeIf { it.hasRequiredCellIds() }
    }

    private fun cellMap(
        radioType: String,
        mcc: Int,
        mnc: Int,
        locationAreaCode: Int,
        cellId: Int
    ): MutableMap<String, Any> {
        return mutableMapOf(
            "radioType" to radioType,
            "mobileCountryCode" to mcc,
            "mobileNetworkCode" to mnc,
            "locationAreaCode" to locationAreaCode,
            "cellId" to cellId
        )
    }

    private fun MutableMap<String, Any>.putSignal(signalStrength: CellSignalStrength) {
        put("signalStrength", signalStrength.dbm)
    }

    private fun MutableMap<String, Any>.putValid(key: String, value: Int) {
        if (value != Int.MAX_VALUE && value != Int.MIN_VALUE && value >= 0) {
            put(key, value)
        }
    }

    private fun Map<String, Any>.hasRequiredCellIds(): Boolean {
        return this["mobileCountryCode"] != Int.MAX_VALUE &&
            this["mobileNetworkCode"] != Int.MAX_VALUE &&
            this["locationAreaCode"] != Int.MAX_VALUE &&
            this["cellId"] != Int.MAX_VALUE
    }

    private fun channelFromFrequency(frequency: Int): Int? {
        return when (frequency) {
            in 2412..2472 -> (frequency - 2407) / 5
            2484 -> 14
            in 5170..5895 -> (frequency - 5000) / 5
            in 5955..7115 -> (frequency - 5950) / 5
            else -> null
        }
    }
}
