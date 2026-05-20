import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_sensors/entities/user.dart';
import 'package:live_sensors/fidelity/fidelity_collector.dart';
import 'package:live_sensors/fidelity/fidelity_observation.dart';
import 'package:live_sensors/geolocator/position.dart';
import 'package:live_sensors/queue/queue.dart';
import 'package:live_sensors/sensors/sensors.dart';
import 'package:live_sensors/tracker.dart';

void main() {
  test('Tracker accepts a start while previous stop is still finishing',
      () async {
    final queue = SnapshotsQueue();
    final sensors = StreamController<SensorsData>.broadcast();
    final positions = StreamController<Position>.broadcast();
    final tracker = Tracker()
      ..setup(
        user: User(id: 'user'),
        userAgent: 'agent',
        queue: queue,
        sensors: sensors.stream,
        position: positions.stream,
      );

    tracker.track();

    final dispose = tracker.dispose();
    tracker.track();
    positions.add(_position());

    await Future<void>.delayed(Duration.zero);

    expect(queue.state, hasLength(1));

    await dispose;
    await tracker.dispose();
    await sensors.close();
    await positions.close();
  });

  test('Tracker drops in-flight snapshots after shutdown', () async {
    final queue = SnapshotsQueue();
    final sensors = StreamController<SensorsData>();
    final positions = StreamController<Position>();
    final fidelity = _DelayedFidelityCollector();
    final tracker = Tracker()
      ..setup(
        user: User(id: 'user'),
        userAgent: 'agent',
        queue: queue,
        sensors: sensors.stream,
        position: positions.stream,
        fidelityCollector: fidelity,
      );

    tracker.track();
    positions.add(_position());
    await fidelity.started.future;

    final dispose = tracker.dispose();
    fidelity.complete();
    await dispose;

    expect(queue.state, isEmpty);

    await sensors.close();
    await positions.close();
  });

  test('Tracker queues snapshots before delayed fidelity collection completes',
      () async {
    final queue = SnapshotsQueue();
    final sensors = StreamController<SensorsData>();
    final positions = StreamController<Position>();
    final fidelity = _DelayedFidelityCollector();
    final tracker = Tracker()
      ..setup(
        user: User(id: 'user'),
        userAgent: 'agent',
        queue: queue,
        sensors: sensors.stream,
        position: positions.stream,
        fidelityCollector: fidelity,
      );

    tracker.track();
    positions.add(_position());
    positions.add(_position());
    await fidelity.started.future;
    await Future<void>.delayed(Duration.zero);

    expect(queue.state, hasLength(2));

    fidelity.complete();
    await tracker.positionProcessing;
    await tracker.dispose();
    await sensors.close();
    await positions.close();
  });
}

Position _position() => Position(
      longitude: 1,
      latitude: 2,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      accuracy: 3,
      altitude: 4,
      heading: 5,
      speed: 6,
      speedAccuracy: 7,
    );

class _DelayedFidelityCollector extends FidelityCollector {
  final started = Completer<void>();
  final _complete = Completer<void>();

  void complete() {
    _complete.complete();
  }

  @override
  Future<FidelityObservation> collect(Position position) async {
    if (!started.isCompleted) {
      started.complete();
    }
    await _complete.future;
    return FidelityObservation(
      time: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      source: 'test',
      gps: position,
      wifiAccessPoints: const [],
    );
  }
}
