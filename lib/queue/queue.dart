import 'package:live_sensors/logger/logger.dart';
import 'package:live_sensors/snapshot/snapshot.dart';
import 'package:live_sensors/utils/state.dart';

class SnapshotsQueue extends SimpleState<List<Snapshot>> {
  final Logger logger = Logger();

  @override
  List<Snapshot> initState() {
    return <Snapshot>[];
  }

  void add(Snapshot snapshot) {
    setState(() {
      state.add(snapshot);
    });
  }

  void remove(Snapshot snapshot) {
    setState(() {
      state.remove(snapshot);
    });
  }

  Snapshot next() {
    return state.first;
  }

  void clear() {
    state.clear();
  }
}
