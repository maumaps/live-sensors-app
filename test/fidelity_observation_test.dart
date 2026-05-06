import 'package:flutter_test/flutter_test.dart';
import 'package:live_sensors/entities/user.dart';
import 'package:live_sensors/fidelity/fidelity_observation.dart';
import 'package:live_sensors/geolocator/position.dart';
import 'package:live_sensors/snapshot/snapshot.dart';
import 'package:live_sensors/snapshot/snapshot_to_geojson.dart';

void main() {
  test('FidelityObservation emits fidelity sensor and geolocate shapes', () {
    final position = _position();
    final observation = FidelityObservation(
      time: DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      source: 'test',
      gps: position,
      wifiAccessPoints: [
        FidelityWifiAccessPoint(
          macAddress: 'AA:BB:CC:00:11:22',
          ssid: 'example',
          signalStrength: -63,
          frequency: 2412,
          channel: 1,
        ),
      ],
      cellTowers: [
        FidelityCellTower(
          radioType: 'lte',
          mobileCountryCode: 282,
          mobileNetworkCode: 1,
          locationAreaCode: 101,
          cellId: 202,
          signalStrength: -95,
          physicalCellId: 3,
        ),
      ],
      bluetoothBeacons: [
        FidelityBluetoothBeacon(
          macAddress: '11:22:33:44:55:66',
          signalStrength: -80,
          age: 25,
        ),
      ],
    );

    expect(observation.toJson(), {
      'time': 1700000000000,
      'source': 'test',
      'gps': {
        'latitude': 41.0,
        'longitude': 44.0,
        'accuracy': 5.0,
        'altitude': 120.0,
        'heading': 90.0,
        'speed': 1.5,
        'time': 1700000001000,
      },
      'wifi': [
        {
          'mac': 'AA:BB:CC:00:11:22',
          'ssid': 'example',
          'ss': -63,
          'frequency': 2412,
          'channel': 1,
        },
      ],
      'cell': [
        {
          'radio': 'lte',
          'mcc': 282,
          'mnc': 1,
          'lac': 101,
          'cid': 202,
          'ss': -95,
          'pci': 3,
        },
      ],
      'bluetooth': [
        {
          'mac': '11:22:33:44:55:66',
          'ss': -80,
          'age': 25,
        },
      ],
    });

    expect(observation.toGeolocateJson(), {
      'wifiAccessPoints': [
        {
          'macAddress': 'AA:BB:CC:00:11:22',
          'ssid': 'example',
          'signalStrength': -63,
          'frequency': 2412,
          'channel': 1,
        },
      ],
      'cellTowers': [
        {
          'radioType': 'lte',
          'mobileCountryCode': 282,
          'mobileNetworkCode': 1,
          'locationAreaCode': 101,
          'cellId': 202,
          'signalStrength': -95,
          'physicalCellId': 3,
        },
      ],
      'bluetoothBeacons': [
        {
          'macAddress': '11:22:33:44:55:66',
          'signalStrength': -80,
          'age': 25,
        },
      ],
      'considerIp': false,
      'fallbacks': {'ipf': false},
    });
  });

  test('snapshot GeoJSON includes fidelity-compatible radio observation', () {
    final snapshot = Snapshot.init(User(id: 'user'), 'agent');
    snapshot.fidelityObservation = FidelityObservation(
      time: DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      source: 'test',
      gps: _position(),
      wifiAccessPoints: [
        FidelityWifiAccessPoint(
          macAddress: 'AA:BB:CC:00:11:22',
          signalStrength: -63,
        ),
      ],
      cellTowers: const [],
      bluetoothBeacons: const [],
    );
    snapshot.seal(_position());

    final properties = snapshotToGeoJson(snapshot).features.first.properties!;

    expect(properties['fidelity'], isA<Map<String, dynamic>>());
    expect(properties['fidelityGeolocate'], {
      'wifiAccessPoints': [
        <String, dynamic>{
          'macAddress': 'AA:BB:CC:00:11:22',
          'signalStrength': -63,
        },
      ],
      'cellTowers': <Map<String, dynamic>>[],
      'bluetoothBeacons': <Map<String, dynamic>>[],
      'considerIp': false,
      'fallbacks': {'ipf': false},
    });
  });

  test('snapshot JSON round-trips persisted fidelity observations', () {
    final snapshot = Snapshot.init(User(id: 'user'), 'agent');
    snapshot.fidelityObservation = FidelityObservation(
      time: DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      source: 'test',
      gps: _position(),
      wifiAccessPoints: [
        FidelityWifiAccessPoint(
          macAddress: 'AA:BB:CC:00:11:22',
          ssid: 'example',
          signalStrength: -63,
        ),
      ],
    );
    snapshot.seal(_position());

    final restored = Snapshot.fromJson(snapshot.toJson());

    expect(restored.id, snapshot.id);
    expect(restored.user.id, 'user');
    expect(restored.position, _position());
    expect(
      restored.fidelityObservation?.toJson(),
      snapshot.fidelityObservation?.toJson(),
    );
  });
}

Position _position() {
  return Position(
    longitude: 44.0,
    latitude: 41.0,
    timestamp: DateTime.fromMillisecondsSinceEpoch(1700000001000, isUtc: true),
    accuracy: 5.0,
    altitude: 120.0,
    heading: 90.0,
    speed: 1.5,
    speedAccuracy: 0.5,
  );
}
