import 'dart:io';

import 'package:flutter/services.dart';
import 'package:live_sensors/fidelity/fidelity_observation.dart';
import 'package:live_sensors/geolocator/position.dart';

class FidelityCollector {
  static const MethodChannel _channel = MethodChannel('live_sensors/fidelity');

  const FidelityCollector();

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('requestRadioPermissions');
    }
  }

  Future<FidelityObservation> collect(Position position) async {
    final Map<dynamic, dynamic> radioFingerprint =
        Platform.isAndroid ? await _androidRadioFingerprint() : {};

    return FidelityObservation(
      time: DateTime.now(),
      source: 'maumaps-live-sensors-app',
      gps: position,
      wifiAccessPoints: _androidWifiAccessPoints(radioFingerprint),
      cellTowers: _androidCellTowers(radioFingerprint),
      bluetoothBeacons: _androidBluetoothBeacons(radioFingerprint),
    );
  }

  Future<Map<dynamic, dynamic>> _androidRadioFingerprint() async {
    final dynamic response = await _channel.invokeMethod('getRadioFingerprint');
    if (response is! Map) {
      return {};
    }
    return response;
  }

  List<FidelityWifiAccessPoint> _androidWifiAccessPoints(
    Map<dynamic, dynamic> response,
  ) {
    final dynamic rows = response['wifiAccessPoints'];
    if (rows is! List) {
      return [];
    }

    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map(FidelityWifiAccessPoint.fromJson)
        .toList();
  }

  List<FidelityCellTower> _androidCellTowers(Map<dynamic, dynamic> response) {
    final dynamic rows = response['cellTowers'];
    if (rows is! List) {
      return [];
    }

    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map(FidelityCellTower.fromJson)
        .toList();
  }

  List<FidelityBluetoothBeacon> _androidBluetoothBeacons(
    Map<dynamic, dynamic> response,
  ) {
    final dynamic rows = response['bluetoothBeacons'];
    if (rows is! List) {
      return [];
    }

    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map(FidelityBluetoothBeacon.fromJson)
        .toList();
  }
}
