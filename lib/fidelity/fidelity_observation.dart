import 'package:live_sensors/geolocator/position.dart';

class FidelityWifiAccessPoint {
  final String macAddress;
  final String? ssid;
  final int? signalStrength;
  final int? frequency;
  final int? channel;
  final int? age;
  final int? signalToNoiseRatio;

  FidelityWifiAccessPoint({
    required this.macAddress,
    this.ssid,
    this.signalStrength,
    this.frequency,
    this.channel,
    this.age,
    this.signalToNoiseRatio,
  });

  factory FidelityWifiAccessPoint.fromJson(Map<dynamic, dynamic> json) {
    return FidelityWifiAccessPoint(
      macAddress: (json['macAddress'] ?? json['mac']).toString(),
      ssid: json['ssid']?.toString(),
      signalStrength: _toInt(json['signalStrength'] ?? json['ss']),
      frequency: _toInt(json['frequency']),
      channel: _toInt(json['channel']),
      age: _toInt(json['age']),
      signalToNoiseRatio: _toInt(json['signalToNoiseRatio'] ?? json['snr']),
    );
  }

  Map<String, dynamic> toGeolocateJson() => _withoutNulls({
        'macAddress': macAddress,
        'ssid': ssid,
        'signalStrength': signalStrength,
        'frequency': frequency,
        'channel': channel,
        'age': age,
        'signalToNoiseRatio': signalToNoiseRatio,
      });

  Map<String, dynamic> toFidelitySensorJson() => _withoutNulls({
        'mac': macAddress,
        'ssid': ssid,
        'ss': signalStrength,
        'frequency': frequency,
        'channel': channel,
        'age': age,
        'snr': signalToNoiseRatio,
      });
}

class FidelityCellTower {
  final String radioType;
  final int? mobileCountryCode;
  final int? mobileNetworkCode;
  final int? locationAreaCode;
  final int? cellId;
  final int? signalStrength;
  final int? primaryScramblingCode;
  final int? physicalCellId;
  final int? absoluteRadioFrequencyChannelNumber;

  FidelityCellTower({
    required this.radioType,
    this.mobileCountryCode,
    this.mobileNetworkCode,
    this.locationAreaCode,
    this.cellId,
    this.signalStrength,
    this.primaryScramblingCode,
    this.physicalCellId,
    this.absoluteRadioFrequencyChannelNumber,
  });

  factory FidelityCellTower.fromJson(Map<dynamic, dynamic> json) {
    return FidelityCellTower(
      radioType: (json['radioType'] ?? json['radio'] ?? 'unknown').toString(),
      mobileCountryCode: _toInt(json['mobileCountryCode'] ?? json['mcc']),
      mobileNetworkCode: _toInt(json['mobileNetworkCode'] ?? json['mnc']),
      locationAreaCode: _toInt(json['locationAreaCode'] ?? json['lac']),
      cellId: _toInt(json['cellId'] ?? json['cid']),
      signalStrength: _toInt(json['signalStrength'] ?? json['ss']),
      primaryScramblingCode:
          _toInt(json['primaryScramblingCode'] ?? json['psc'] ?? json['bsic']),
      physicalCellId: _toInt(json['physicalCellId'] ?? json['pci']),
      absoluteRadioFrequencyChannelNumber: _toInt(
        json['absoluteRadioFrequencyChannelNumber'] ??
            json['arfcn'] ??
            json['uarfcn'] ??
            json['earfcn'] ??
            json['nrarfcn'],
      ),
    );
  }

  Map<String, dynamic> toGeolocateJson() => _withoutNulls({
        'radioType': radioType,
        'mobileCountryCode': mobileCountryCode,
        'mobileNetworkCode': mobileNetworkCode,
        'locationAreaCode': locationAreaCode,
        'cellId': cellId,
        'signalStrength': signalStrength,
        'primaryScramblingCode': primaryScramblingCode,
        'physicalCellId': physicalCellId,
        'absoluteRadioFrequencyChannelNumber':
            absoluteRadioFrequencyChannelNumber,
      });

  Map<String, dynamic> toFidelitySensorJson() => _withoutNulls({
        'radio': radioType,
        'mcc': mobileCountryCode,
        'mnc': mobileNetworkCode,
        'lac': locationAreaCode,
        'cid': cellId,
        'ss': signalStrength,
        'psc': primaryScramblingCode,
        'pci': physicalCellId,
        'arfcn': absoluteRadioFrequencyChannelNumber,
      });
}

class FidelityBluetoothBeacon {
  final String macAddress;
  final int? signalStrength;
  final int? age;

  FidelityBluetoothBeacon({
    required this.macAddress,
    this.signalStrength,
    this.age,
  });

  factory FidelityBluetoothBeacon.fromJson(Map<dynamic, dynamic> json) {
    return FidelityBluetoothBeacon(
      macAddress: (json['macAddress'] ?? json['mac']).toString(),
      signalStrength: _toInt(json['signalStrength'] ?? json['ss']),
      age: _toInt(json['age']),
    );
  }

  Map<String, dynamic> toGeolocateJson() => _withoutNulls({
        'macAddress': macAddress,
        'signalStrength': signalStrength,
        'age': age,
      });

  Map<String, dynamic> toFidelitySensorJson() => _withoutNulls({
        'mac': macAddress,
        'ss': signalStrength,
        'age': age,
      });
}

class FidelityObservation {
  final DateTime time;
  final String source;
  final Position gps;
  final List<FidelityWifiAccessPoint> wifiAccessPoints;
  final List<FidelityCellTower> cellTowers;
  final List<FidelityBluetoothBeacon> bluetoothBeacons;

  FidelityObservation({
    required this.time,
    required this.source,
    required this.gps,
    required this.wifiAccessPoints,
    this.cellTowers = const [],
    this.bluetoothBeacons = const [],
  });

  factory FidelityObservation.fromJson(Map<dynamic, dynamic> json) {
    final dynamic wifiRows = json['wifi'] ?? json['wifiAccessPoints'];
    final dynamic cellRows = json['cell'] ?? json['cellTowers'];
    final dynamic bluetoothRows = json['bluetooth'] ?? json['bluetoothBeacons'];
    return FidelityObservation(
      time: _dateTimeFromJson(json['time']) ?? DateTime.now(),
      source: json['source']?.toString() ?? 'unknown',
      gps: _positionFromJson(json['gps']),
      wifiAccessPoints: wifiRows is List
          ? wifiRows
              .whereType<Map<dynamic, dynamic>>()
              .map(FidelityWifiAccessPoint.fromJson)
              .toList()
          : <FidelityWifiAccessPoint>[],
      cellTowers: cellRows is List
          ? cellRows
              .whereType<Map<dynamic, dynamic>>()
              .map(FidelityCellTower.fromJson)
              .toList()
          : <FidelityCellTower>[],
      bluetoothBeacons: bluetoothRows is List
          ? bluetoothRows
              .whereType<Map<dynamic, dynamic>>()
              .map(FidelityBluetoothBeacon.fromJson)
              .toList()
          : <FidelityBluetoothBeacon>[],
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time.millisecondsSinceEpoch,
        'source': source,
        'gps': _gpsJson(gps),
        'wifi':
            wifiAccessPoints.map((ap) => ap.toFidelitySensorJson()).toList(),
        'cell':
            cellTowers.map((tower) => tower.toFidelitySensorJson()).toList(),
        'bluetooth': bluetoothBeacons
            .map((beacon) => beacon.toFidelitySensorJson())
            .toList(),
      };

  Map<String, dynamic> toGeolocateJson() => {
        'wifiAccessPoints':
            wifiAccessPoints.map((ap) => ap.toGeolocateJson()).toList(),
        'cellTowers':
            cellTowers.map((tower) => tower.toGeolocateJson()).toList(),
        'bluetoothBeacons':
            bluetoothBeacons.map((beacon) => beacon.toGeolocateJson()).toList(),
        'considerIp': false,
        'fallbacks': {'ipf': false},
      };
}

Map<String, dynamic> _gpsJson(Position position) => _withoutNulls({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'heading': position.heading,
      'speed': position.speed,
      'time': position.timestamp?.millisecondsSinceEpoch,
    });

Map<String, dynamic> _withoutNulls(Map<String, dynamic> json) {
  json.removeWhere((_, value) => value == null);
  return json;
}

int? _toInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

DateTime? _dateTimeFromJson(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  return DateTime.tryParse(value.toString());
}

Position _positionFromJson(dynamic value) {
  final Map<dynamic, dynamic> gps = Map<dynamic, dynamic>.from(value as Map);
  gps['timestamp'] ??= gps['time'];
  return Position.fromMap(gps);
}
