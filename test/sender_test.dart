import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:live_sensors/api/api_client.dart';
import 'package:live_sensors/entities/user.dart';
import 'package:live_sensors/geolocator/position.dart';
import 'package:live_sensors/queue/queue.dart';
import 'package:live_sensors/sender.dart';
import 'package:live_sensors/snapshot/snapshot.dart';
import 'package:live_sensors/storage/storage.dart';

void main() {
  test('Sender keeps queue loop alive when replay storage save fails',
      () async {
    final queue = SnapshotsQueue();
    final snapshot = Snapshot.init(User(id: 'user'), 'agent')
      ..seal(_position());
    final api = _ThrowingApiClient();
    final storage = _ThrowingStorage();
    final sender = Sender()
      ..setup(api: api, queue: queue, storage: storage, user: User(id: 'user'))
      ..storeFailureDelay = Duration.zero;

    queue.add(snapshot);

    final sending = sender.sendSnapshotsFromQueue();
    await storage.saveCalled.future;
    await Future<void>.delayed(Duration.zero);

    expect(queue.state, contains(same(snapshot)));
    expect(api.calls, greaterThanOrEqualTo(1));
    expect(storage.saveCalls, greaterThanOrEqualTo(1));

    sender.stop();
    await sending;
  });

  test('Sender keeps storage loop alive when stored payload read fails',
      () async {
    final snapshot = Snapshot.init(User(id: 'user'), 'agent')
      ..seal(_position());
    final api = _SuccessfulApiClient();
    final storage = _FlakyReadStorage(snapshot);
    final sender = Sender()
      ..setup(
        api: api,
        queue: SnapshotsQueue(),
        storage: storage,
        user: User(id: 'user'),
      )
      ..storageReadFailureDelay = Duration.zero;

    final sending = sender.sendSnapshotsFromStorage();
    await storage.failedReadObserved.future;
    await storage.deleted.future;

    expect(api.calls, 1);
    expect(storage.nextCalls, 2);
    expect(storage.deletedSnapshot, same(snapshot));

    sender.stop();
    await sending;
  });

  test('Sender drops stored snapshots that belong to another user', () async {
    final snapshot = Snapshot.init(User(id: 'previous-user'), 'agent')
      ..seal(_position());
    final api = _SuccessfulApiClient();
    final storage = _OneShotStorage(snapshot);
    final sender = Sender()
      ..setup(
        api: api,
        queue: SnapshotsQueue(),
        storage: storage,
        user: User(id: 'current-user'),
      );

    final sending = sender.sendSnapshotsFromStorage();
    await storage.deleted.future;

    expect(api.calls, 0);
    expect(storage.deletedSnapshot, same(snapshot));

    sender.stop();
    await sending;
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

class _ThrowingApiClient extends ApiClient {
  int calls = 0;

  _ThrowingApiClient()
      : super(
          http.Client(),
          liveSensorEndpoint: Uri.parse('https://example.test/live-sensor'),
        );

  @override
  Future<void> sendSnapshot(Map<String, dynamic> payload) async {
    calls++;
    throw Exception('network down');
  }
}

class _SuccessfulApiClient extends ApiClient {
  int calls = 0;

  _SuccessfulApiClient()
      : super(
          http.Client(),
          liveSensorEndpoint: Uri.parse('https://example.test/live-sensor'),
        );

  @override
  Future<void> sendSnapshot(Map<String, dynamic> payload) async {
    calls++;
  }
}

class _ThrowingStorage extends Storage {
  final saveCalled = Completer<void>();
  int saveCalls = 0;

  @override
  Future<void> save(Snapshot snapshot) async {
    saveCalls++;
    if (!saveCalled.isCompleted) {
      saveCalled.complete();
    }
    throw Exception('sqlite unavailable');
  }
}

class _FlakyReadStorage extends Storage {
  final Snapshot snapshot;
  final failedReadObserved = Completer<void>();
  final deleted = Completer<void>();
  int nextCalls = 0;
  Snapshot? deletedSnapshot;

  _FlakyReadStorage(this.snapshot);

  @override
  Future<Snapshot> next() async {
    nextCalls++;
    if (nextCalls == 1) {
      failedReadObserved.complete();
      throw const FormatException('bad json');
    }
    return snapshot;
  }

  @override
  Future<void> delete(Snapshot snapshot) async {
    deletedSnapshot = snapshot;
    if (!deleted.isCompleted) {
      deleted.complete();
    }
  }
}

class _OneShotStorage extends Storage {
  final Snapshot snapshot;
  final deleted = Completer<void>();
  bool emitted = false;
  Snapshot? deletedSnapshot;

  _OneShotStorage(this.snapshot);

  @override
  Future<Snapshot> next() async {
    if (emitted) {
      throw StateError('No stored snapshots');
    }
    emitted = true;
    return snapshot;
  }

  @override
  Future<void> delete(Snapshot snapshot) async {
    deletedSnapshot = snapshot;
    if (!deleted.isCompleted) {
      deleted.complete();
    }
  }
}
