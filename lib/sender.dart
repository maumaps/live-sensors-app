import 'package:live_sensors/logger/logger.dart';

import 'api/api_client.dart';
import 'api/errors.dart';
import 'entities/user.dart';
import 'http_client/errors.dart';
import 'queue/queue.dart';
import 'snapshot/snapnshot_error.dart';
import 'snapshot/snapshot.dart';
import 'snapshot/snapshot_to_geojson.dart';
import 'storage/storage.dart';

class Sender {
  final Logger logger = Logger();
  late SnapshotsQueue queue;
  late ApiClient api;
  late Storage storage;
  late User user;
  int counter = 0;
  bool isStopped = false;
  bool isRunning = false;
  Duration storeFailureDelay = const Duration(seconds: 5);
  Duration storageReadFailureDelay = const Duration(seconds: 5);

  Sender();

  void setup({
    required ApiClient api,
    required SnapshotsQueue queue,
    required Storage storage,
    required User user,
  }) {
    this.api = api;
    this.queue = queue;
    this.storage = storage;
    this.user = user;
  }

  void run() {
    if (isRunning) {
      logger.warn('Sender is already running');
      return;
    }
    isRunning = true;
    isStopped = false;
    sendSnapshotsFromQueue();
    sendSnapshotsFromStorage();
  }

  void stop() {
    isStopped = true;
    isRunning = false;
  }

  Future<void> sendSnapshotsFromQueue() async {
    logger.info('Start sending from snapshot queue');
    while (!isStopped) {
      try {
        Snapshot nextSnap = queue.next();
        await nextSnap.readyToSend;
        if (isStopped) {
          break;
        }
        if (!queue.state.contains(nextSnap)) {
          continue;
        }
        try {
          final json = snapshotToGeoJson(nextSnap).toJson();
          await api.sendSnapshot(json);
          counter++;
          queue.remove(nextSnap);
        } on BadRequestException {
          // TODO: remove this after storage implemented
          logger.error(
            'Fail to send snapshot ${nextSnap.id}.\n Reason: Bad request',
          );
          queue.remove(nextSnap);
        } on AuthException catch (e) {
          logger.error(
            'Fail to send snapshot ${nextSnap.id}.\n Reason: $e',
          );
          if (await _storeForReplay(nextSnap)) {
            queue.remove(nextSnap);
          }
        } on SnapshotError catch (e) {
          logger.error(
            'Fail to send snapshot ${nextSnap.id}.\n Reason: ${e.message}',
          );
          nextSnap.error = e;
          if (await _storeForReplay(nextSnap)) {
            queue.remove(nextSnap);
          }
        } catch (e) {
          logger.error(
            'Fail to send snapshot ${nextSnap.id}.\n Reason: $e',
          );
          if (await _storeForReplay(nextSnap)) {
            queue.remove(nextSnap);
          }
        }
      } on StateError {
        // No more snapshots in queue
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<bool> _storeForReplay(Snapshot snapshot) async {
    try {
      await storage.save(snapshot);
      return true;
    } catch (e) {
      logger.error(
        'Fail to store snapshot ${snapshot.id} for replay.\n Reason: $e',
      );
      await Future<void>.delayed(storeFailureDelay);
      return false;
    }
  }

  Future<void> sendSnapshotsFromStorage() async {
    logger.info('Start sending from snapshot storage');
    while (!isStopped) {
      try {
        final nextSnap = await storage.next();
        if (nextSnap.user.id != user.id) {
          logger.error(
            'Drop stored snapshot ${nextSnap.id}.\n'
            ' Reason: belongs to another user',
          );
          await storage.delete(nextSnap);
          continue;
        }

        try {
          final json = snapshotToGeoJson(nextSnap).toJson();
          await api.sendSnapshot(json);
          await storage.delete(nextSnap);
          counter++;
        } on BadRequestException {
          logger.error(
            'Drop stored snapshot ${nextSnap.id}.\n Reason: Bad request',
          );
          await storage.delete(nextSnap);
        } catch (e) {
          logger.error(
            'Fail to send stored snapshot ${nextSnap.id}.\n Reason: $e',
          );
          await Future<void>.delayed(const Duration(seconds: 5));
        }
      } on StateError {
        await Future<void>.delayed(const Duration(seconds: 5));
      } catch (e) {
        logger.error(
          'Fail to read snapshot storage.\n Reason: $e',
        );
        await Future<void>.delayed(storageReadFailureDelay);
      }
    }
  }
}
