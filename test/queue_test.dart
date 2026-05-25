import 'package:flutter_test/flutter_test.dart';
import 'package:live_sensors/entities/user.dart';
import 'package:live_sensors/queue/queue.dart';
import 'package:live_sensors/snapshot/snapshot.dart';

void main() {
  test('SnapshotsQueue returns snapshots in insertion order', () {
    final queue = SnapshotsQueue();
    final first = Snapshot.init(User(id: 'user'), 'agent');
    final second = Snapshot.init(User(id: 'user'), 'agent');

    queue.add(first);
    queue.add(second);

    expect(queue.next(), same(first));
    queue.remove(first);
    expect(queue.next(), same(second));
  });
}
