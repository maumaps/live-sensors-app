import 'dart:async';

import 'package:live_sensors/logger/logger.dart';
import 'package:live_sensors/utils/stats.dart';

import 'entities/user.dart';
import 'fidelity/fidelity_collector.dart';
import 'geolocator/position.dart';
import 'queue/queue.dart';
import 'sensors/sensors.dart';
import 'snapshot/snapshot.dart';

class Tracker {
  final Logger logger = Logger();
  late SnapshotsQueue queue;
  late User user;
  late String userAgent;
  FidelityCollector? fidelityCollector;
  late Stream<SensorsData> sensors;
  late Stream<Position> position;
  CallPerSecMeasure sensorsFreq = CallPerSecMeasure();
  CallPerSecMeasure positionFreq = CallPerSecMeasure();
  bool isPaused = false;
  bool isStopped = true;
  StreamSubscription<SensorsData>? sensorsSubscription;
  StreamSubscription<Position>? positionSubscription;
  Future<void> positionProcessing = Future<void>.value();
  int _runGeneration = 0;
  final Set<Snapshot> _pendingFidelitySnapshots = <Snapshot>{};

  Tracker();

  void setup({
    required User user,
    required String userAgent,
    required SnapshotsQueue queue,
    required Stream<SensorsData> sensors,
    required Stream<Position> position,
    FidelityCollector? fidelityCollector,
  }) {
    this.user = user;
    this.userAgent = userAgent;
    this.queue = queue;
    this.sensors = sensors;
    this.position = position;
    this.fidelityCollector = fidelityCollector;
  }

  void track() {
    if (sensorsSubscription != null || positionSubscription != null) {
      logger.warn('Tracker is already running');
      return;
    }

    final int runGeneration = ++_runGeneration;
    isStopped = false;
    isPaused = false;
    Snapshot snap = Snapshot.init(user, userAgent);

    // Fill current snapshot with sensors data
    sensorsSubscription = sensors.listen((events) {
      sensorsFreq.tick();
      if (isPaused) return;
      snap.add(events);
    });

    // Finalize current snapshot, and create next one
    bool skip = false; // After pause we still need finalize current chunk
    positionSubscription = position.listen((event) {
      positionFreq.tick();
      if (isPaused && skip) {
        // Tracking paused and last snapshot finalized
        return;
      }
      final Snapshot sealedSnapshot = snap;
      sealedSnapshot.seal(event);
      snap = Snapshot.init(user, userAgent);
      skip = isPaused;

      _pendingFidelitySnapshots.add(sealedSnapshot);
      final Future<void> readyToSend =
          _attachFidelityObservation(sealedSnapshot, event, runGeneration);
      sealedSnapshot.readyToSend = readyToSend;
      queue.add(sealedSnapshot);
      positionProcessing = Future.wait<void>(
        _pendingFidelitySnapshots.map((snapshot) => snapshot.readyToSend),
      );
    });

    if (isPaused) {
      pause();
    }
  }

  void pause() {
    isPaused = true;
    // sensorsSubscription?.pause();
    // positionSubscription?.pause();
  }

  void resume() {
    isPaused = false;
    // sensorsSubscription?.resume();
    // positionSubscription?.resume();
  }

  Future<void> dispose() async {
    isStopped = true;
    pause();
    _runGeneration++;

    final StreamSubscription<SensorsData>? sensorsToCancel =
        sensorsSubscription;
    final StreamSubscription<Position>? positionToCancel = positionSubscription;
    final Future<void> processingToAwait = positionProcessing;

    sensorsSubscription = null;
    positionSubscription = null;
    positionProcessing = Future<void>.value();
    for (final snapshot in _pendingFidelitySnapshots.toList()) {
      queue.remove(snapshot);
    }

    await sensorsToCancel?.cancel();
    await positionToCancel?.cancel();
    await processingToAwait;
  }

  Future<void> _attachFidelityObservation(
    Snapshot snapshot,
    Position position,
    int runGeneration,
  ) async {
    try {
      snapshot.fidelityObservation = await fidelityCollector?.collect(position);
    } catch (e) {
      logger.warn('Failed to collect fidelity observation: $e');
    } finally {
      _pendingFidelitySnapshots.remove(snapshot);
      if (isStopped || runGeneration != _runGeneration) {
        queue.remove(snapshot);
      }
    }
  }
}
