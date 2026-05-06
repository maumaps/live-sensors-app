import 'package:turf/turf.dart' as turf;
import 'package:live_sensors/geolocator/position.dart' as locator;
import 'package:nanoid/nanoid.dart';
import './snapshot.dart';

String customNanoId() {
  return customAlphabet(
    '0123456789_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
    22,
  );
}

class ConversionError extends Error {
  final String message;
  ConversionError(this.message);
}

turf.Position toGeoJsonPosition(locator.Position pos) {
  return turf.Position(pos.longitude, pos.latitude, pos.altitude);
}

String precise(double val) {
  return val.toStringAsPrecision(precision);
}

List<String> preciseAll(List<double> list) {
  return list.map((v) => v.toStringAsPrecision(precision)).toList();
}

const precision = 3;
turf.FeatureCollection snapshotToGeoJson(Snapshot snapshot) {
  locator.Position? position = snapshot.position;
  if (position == null) {
    throw ConversionError('Missing coordinates in snapshot');
  }
  turf.Feature<turf.Point> point = turf.Feature<turf.Point>(
    id: customNanoId(),
    geometry: turf.Point(coordinates: toGeoJsonPosition(position)),
    properties: {
      'lng': precise(position.longitude),
      'lat': precise(position.latitude),
      'alt': precise(position.altitude),
      'accuracy': precise(position.accuracy),
      'speed': precise(position.speed),
      'speedAccuracy': precise(position.speedAccuracy),
      'heading': precise(position.heading),
      'coordTimestamp': position.timestamp?.millisecondsSinceEpoch,
      'coordSystTimestamp': position.timestamp?.millisecondsSinceEpoch,
      'userAgent': snapshot.userAgent,
      'orientX': preciseAll(snapshot.magnetometer.x),
      'orientY': preciseAll(snapshot.magnetometer.y),
      'orientZ': preciseAll(snapshot.magnetometer.z),
      'orientTime': snapshot.magnetometer.timestamp
          .map((t) => t.millisecondsSinceEpoch)
          .toList(),
      'accelX': preciseAll(snapshot.accelerometer.x),
      'accelY': preciseAll(snapshot.accelerometer.y),
      'accelZ': preciseAll(snapshot.accelerometer.z),
      'accelTime': snapshot.accelerometer.timestamp
          .map((t) => t.millisecondsSinceEpoch)
          .toList(),
      'gyroX': preciseAll(snapshot.gyroscope.x),
      'gyroY': preciseAll(snapshot.gyroscope.y),
      'gyroZ': preciseAll(snapshot.gyroscope.z),
      'gyroTime': snapshot.gyroscope.timestamp
          .map((t) => t.millisecondsSinceEpoch)
          .toList(),
      'fidelity': snapshot.fidelityObservation?.toJson(),
      'fidelityGeolocate': snapshot.fidelityObservation?.toGeolocateJson(),
    },
  );

  return turf.FeatureCollection(features: [point]);
}
