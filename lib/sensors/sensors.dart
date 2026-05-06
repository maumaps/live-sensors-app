import 'dart:async';
import 'package:async/async.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:live_sensors/logger/logger.dart';

typedef SensorsData = (
  SensorEvent<UserAccelerometerEvent>,
  SensorEvent<GyroscopeEvent>,
  SensorEvent<MagnetometerEvent>,
);

class SensorEvent<T> {
  late DateTime timestamp = DateTime.now();
  final T data;
  SensorEvent(this.data, this.timestamp);
}

class Sensors {
  final Logger logger = Logger();
  final List<Stream<Object>> _sensors = <Stream<Object>>[
    userAccelerometerEvents.map(
      (event) => SensorEvent<UserAccelerometerEvent>(event, DateTime.now()),
    ),
    gyroscopeEvents.map(
      (event) => SensorEvent<GyroscopeEvent>(event, DateTime.now()),
    ),
    magnetometerEvents.map(
      (event) => SensorEvent<MagnetometerEvent>(event, DateTime.now()),
    ),
  ];
  late Stream<SensorsData> stream;

  Sensors() {
    stream = StreamZip<Object>(_sensors).map(
      (List<Object> event) => (
        event[0] as SensorEvent<UserAccelerometerEvent>,
        event[1] as SensorEvent<GyroscopeEvent>,
        event[2] as SensorEvent<MagnetometerEvent>,
      ),
    );
  }
}
